import std/macros
import pcp/ast

proc tco(call: NimNode): NimNode =
  ## wrap a call in a statement list which emits a return
  ## statement with the musttail compiler attribute
  result = newStmtList()
  when defined(clang):
    result.add newEmit "__attribute__((musttail)) return"
    result.add call
    result.add newEmit ";"
  elif defined(gcc):
    result.add newEmit "__attribute__((clang::musttail)) return"
    result.add call
    result.add newEmit ";"
  else:
    {.warning: "tail calls require clang/gcc".}

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
