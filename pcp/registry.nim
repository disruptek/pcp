import std/genasts
import std/macros

import pcp/ast

const pcpDynamic {.booldefine.} = false

type
    Fun*[T, R] {.union.} = object
      fn: Fn[T, R]
      n: int
      p: pointer

    Fn*[T, R] = proc(x: ptr T; r: ptr R) {.tco.}

proc `=copy`[T, R](target: var Fun[T, R]; source: Fun[T, R]) =
  target.n = source.n

var functions: seq[pointer]
functions.add(nil)

proc ser(fun: NimNode; tipe: NimNode): NimNode =
  genAstOpt({}, tipe, functions=bindSym"functions", p=fun):
    var i: pointer = nil
    block found:
      for index, item in functions.pairs:
        if item == cast[pointer](p):
          i = cast[pointer](index)
          break found
      i = cast[pointer](p)
    cast[tipe](i)

proc deser(index: NimNode; tipe: NimNode): NimNode =
  genAstOpt({}, index, tipe, functions=bindSym"functions"):
    let n = index
    if n <= functions.high:
      cast[tipe](functions[n])
    else:
      when pcpDynamic:
        cast[tipe](n)
      else:
        raise Defect.newException "no dynamic continuations"

proc register(function: NimNode): NimNode =
  genAstOpt({}, function, functions=bindSym"functions"):
    let p = cast[pointer](function)
    if p notin functions:
      functions.add p

macro register*[T, R](function: Fn[T, R]): untyped =
  register function
  #genAstOpt({}, function, functions=bindSym"functions"):
  #  functions.incl(cast[pointer](function))

macro serialize*[T, R](fun: Fn[T, R]): untyped =
  result = newStmtList()
  result.add: register fun
  let t = getTypeInst fun
  let a = t[0][1][1].last # ptr -> bracket
  let b = t[0][2][1].last # ptr -> bracket
  result.add: ser(fun, nnkBracketExpr.newTree(bindSym"Fun", a, b))

macro deserialize*(index: int; tipe: typedesc): untyped =
  deser(index, tipe)

proc fp(fun: NimNode): NimNode =
  let t = getTypeInst fun
  result = deser(newDotExpr(fun, ident"n"),
                 nnkBracketExpr.newTree(bindSym"Fn", t[1], t[2]))

macro fp*[T, R](fun: Fun[T, R]): untyped =
  ## recover a function pointer from `fun`
  result = fp(fun)

{.push experimental: "callOperator".}
macro `()`*[T, R](fun: Fun[T, R]; args: varargs[typed]): untyped =
  ## call `fun` with `args`
  result = newCall(fun.fp)
  for arg in args.items:
    result.add arg
{.pop.}
