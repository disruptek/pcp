import std/macros

template newEmit*(s: string): untyped =
  nnkPragma.newTree(nnkExprColonExpr.newTree(ident"emit", s.newLit))

proc pushPopBracketOff*(form: NimNode; name: NimNode; body: NimNode): NimNode =
  let bracket = nnkBracketExpr.newTree(form, name)
  let colon = nnkExprColonExpr.newTree(bracket, bindSym"off")
  result = newStmtList()
  result.add nnkPragma.newTree(ident"push", colon)
  result.add body
  result.add nnkPragma.newTree(ident"pop")
