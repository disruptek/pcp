import std/macros

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

macro tco*(function: untyped): untyped =
  ## annotate a function type/decl for tail-call optimization
  result = function
  result.addPragma ident"nimcall"
  when compileOption"stackTrace":
    if function.kind == nnkProcDef:
      result = pushPopOff(ident"stackTrace", result)
