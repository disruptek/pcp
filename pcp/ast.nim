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

macro tco*(function: untyped): untyped =
  ## annotate a function type/decl for tail-call optimization
  result = function
  result.addPragma ident"nimcall"
  when pcpHasInlinedTCO:
    result.addPragma ident"inline"
  when pcpHasTailCalls:
    if function.kind == nnkProcDef:
      result.addPragma ident"noreturn"
  when compileOption"stackTrace":
    if function.kind == nnkProcDef:
      result = pushPopOff(ident"stackTrace", result)
