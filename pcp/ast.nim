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

proc newCast*(tipe: NimNode; arg: NimNode): NimNode =
  nnkCast.newTree(tipe, arg)

proc newCast*(tipe: typedesc; arg: NimNode): NimNode =
  nnkCast.newTree(tipe.getTypeInst, arg)

template dot*(a, b: NimNode): NimNode =
  ## for constructing foo.bar
  {.line: instantiationInfo().}:
    newDotExpr(a, b)

template dot*(a: NimNode; b: string): NimNode =
  ## for constructing `.`(foo, "bar")
  {.line: instantiationInfo().}:
    dot(a, ident(b))

template eq*(a, b: NimNode): NimNode =
  ## for constructing foo=bar in a call
  {.line: instantiationInfo().}:
    nnkExprEqExpr.newNimNode(a).add(a).add(b)

template eq*(a: string; b: NimNode): NimNode =
  ## for constructing foo=bar in a call
  {.line: instantiationInfo().}:
    eq(ident(a), b)

template colon*(a, b: NimNode): NimNode =
  ## for constructing foo: bar in a ctor
  {.line: instantiationInfo().}:
    nnkExprColonExpr.newNimNode(a).add(a).add(b)

template colon*(a: string; b: NimNode): NimNode =
  ## for constructing foo: bar in a ctor
  {.line: instantiationInfo().}:
    colon(ident(a), b)

template colon*(a: string | NimNode; b: string | int): NimNode =
  ## for constructing foo: bar in a ctor
  {.line: instantiationInfo().}:
    colon(a, newLit(b))
