## implementing tail-call support
import std/macros

import pcp/ast

const pcpTypedPass {.booldefine.} = false

proc install(stmts: NimNode; call: NimNode): NimNode =
  ## lift the call and its arguments to ensure we can later
  ## make a tail-call signature without breaking c syntax
  var syms = newSeq[NimNode](call.len)
  for index, item in call.pairs:
    syms[index] = genSym(nskVar, "tco")
    stmts.add:
      newVarStmt(syms[index], item)
  result = newCall(syms[0])
  for index in 1..syms.high:
    result.add syms[index]

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
  when not pcpHasTailCalls:
    # `return call(...)` is not necessary if we can tailcall
    result.add nnkReturnStmt.newTree call

macro mustTail*(call: typed): untyped =
  ## perform a tail call without a return type; suitable for void calls
  result = tco call
  # `call(...); return` is not necessary if we can tailcall
  when not pcpHasTailCalls:
    result.add call
    result.add nnkReturnStmt.newTree newEmptyNode()

macro pass0(procsym: typed; function: typed): untyped {.used.} =
  result = function
  result = filter(result, rewriteArgList)

macro tco*(function: untyped): untyped =
  ## annotate a function type/decl for tail-call optimization
  result = dressWithPragmas function
  if function.kind == nnkProcDef:
    # give the compiler a chance to ignore our first pass
    when pcpTypedPass:
      if result[6].kind != nnkEmpty:  # don't touch prototype bodies
        result[6] = newCall(bindSym"pass0", function[0], result[6])
  when compileOption"stackTrace" or compileOption"lineTrace":
    if function.kind == nnkProcDef:
      result = pushPopOff(ident"stackTrace", result)
      result = pushPopOff(ident"lineTrace", result)
