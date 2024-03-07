import std/macros

const pcpHasTailCalls* = defined(clang) or defined(gcc)
const pcpTypedPass {.booldefine.} = true

template newEmit*(s: string): untyped =
  nnkPragma.newTree(nnkExprColonExpr.newTree(ident"emit", s.newLit))

proc pushPopOff*(name: NimNode; body: NimNode): NimNode =
  ## wrap the body in a {.push name:off.} {.pop.} pair
  let colon = nnkExprColonExpr.newTree(name, bindSym"off")
  result = newStmtList()
  result.add nnkPragma.newTree(ident"push", colon)
  result.add body
  result.add nnkPragma.newTree(ident"pop")

proc pushPopBracketOff*(form: NimNode; name: NimNode; body: NimNode): NimNode =
  ## wrap the body in a {.push form[name]: off.} {.pop.} pair
  let bracket = nnkBracketExpr.newTree(form, name)
  result = pushPopOff(bracket, body)

const pcpHasInlinedTCO* = defined(danger) and not compileOption"debuginfo"
when not pcpHasInlinedTCO and not defined(danger):
  {.hint: "removing .inline. from TCO functions".}

type NodeFilter* = proc(n: NimNode): NimNode

proc filter*(n: NimNode; f: NodeFilter): NimNode =
  ## rewrites a node and its children by passing each node to the filter;
  ## if the filter yields nil, the node is simply copied.  otherwise, the
  ## node is replaced.
  result = f(n)
  if result.isNil:
    result = copyNimNode n
    for kid in items(n):
      result.add filter(kid, f)

proc rewriteArgList(n: NimNode): NimNode =
  ## nnkArgList -> nnkBracket
  if n.kind == nnkArgList:
    result = nnkBracket.newTree()
    for item in n.items:
      result.add:
        filter(item, rewriteArgList)

macro pass0(procsym: typed; function: typed): untyped =
  result = function
  result = filter(result, rewriteArgList)

macro tco*(function: untyped): untyped =
  ## annotate a function type/decl for tail-call optimization
  result = function
  result.addPragma ident"nimcall"
  when pcpHasInlinedTCO:
    result.addPragma ident"inline"
  if function.kind == nnkProcDef:
    when pcpHasTailCalls:
      result.addPragma ident"noreturn"
    # give the compiler a chance to ignore our first pass
    when pcpTypedPass:
      if result[6].kind != nnkEmpty:  # don't touch prototype bodies
        result[6] = newCall(bindSym"pass0", function[0], result[6])
  when compileOption"stackTrace" or compileOption"lineTrace":
    if function.kind == nnkProcDef:
      result = pushPopOff(ident"stackTrace", result)
      result = pushPopOff(ident"lineTrace", result)
