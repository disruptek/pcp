import std/macros

const pcpHasTailCalls* = defined(clang) or defined(gcc)

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
  if result.isNil: # == nil:
    # typechecked nodes may not be modified
    result = copyNimNode n
    for kid in n.items:
      result.add filter(kid, f)

proc rewriteArgList*(n: NimNode): NimNode =
  ## nnkArgList -> nnkBracket
  if n.kind == nnkArgList:
    result = nnkBracket.newTree()
    for item in n.items:
      result.add:
        filter(item, rewriteArgList)

proc dressWithPragmas*(function: NimNode): NimNode =
  result = function
  result.addPragma ident"nimcall"
  when pcpHasInlinedTCO:
    result.addPragma ident"inline"
  when false:
    if function.kind == nnkProcDef:
      when pcpHasTailCalls:
        result.addPragma ident"noreturn"

proc newGeneric*(sym: NimNode; args: varargs[NimNode]): NimNode =
  ## convenience for creating nnkBracketExpr
  result = nnkBracketExpr.newTree(sym)
  for item in args.items:
    result.add item

proc newCast*(tipe: typedesc | NimNode; arg: NimNode): NimNode =
  result = nnkCast.newTree(tipe, arg)
