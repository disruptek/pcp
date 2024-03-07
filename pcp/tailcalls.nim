import std/macros
import pcp/ast

proc install(stmts: NimNode; call: NimNode): NimNode =
  ## store the calling symbol in a variable to ensure we can
  ## make a tail call signature without breaking c syntax
  result = genSym(nskVar, "tailcall_fp")
  stmts.add:
    newVarStmt(result, call[0])
  result = newCall(result)
  for arg in 1 ..< call.len:
    result.add call[arg]

proc tco(call: NimNode): NimNode =
  ## wrap a call in a statement list which emits a return
  ## statement with the musttail compiler attribute
  result = newStmtList()

  # inject a `var tailcall_fp = call[0]` assignment so that the user can
  # supply something which merely evaluates to a function pointer
  let call = install(result, call)

  when not pcpHasTailCalls:
    {.warning: "tail calls require clang/gcc".}
    result.add call  # maybe it won't matter...
  elif defined(clang):
    result.add newEmit "__attribute__((musttail)) return"
    result.add call
    result.add newEmit ";"
  elif defined(gcc):
    result.add newEmit "__attribute__((clang::musttail)) return"
    result.add call
    result.add newEmit ";"
  else:
    {.error: "tailcalls on your platform are unsupported".}

macro mustTail*(tipe: typedesc; call: typed): untyped =
  ## perform a tail call with a return type; suitable for typed calls
  result = tco call
  # `return call(...)` becomes a compiler hint if we can tailcall
  result.add nnkReturnStmt.newTree call

macro mustTail*(call: typed): untyped =
  ## perform a tail call without a return type; suitable for void calls
  result = tco call
  # `call(...); return` becomes a compiler hint if we can tailcall
  result.add call
  result.add nnkReturnStmt.newTree newEmptyNode()
