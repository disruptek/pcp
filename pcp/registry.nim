## this is just a shim which we expect will be largely moved into the
## compiler or otherwise mitigated in the future
import std/genasts
import std/macros

import pcp/ast

const pcpDynamic {.booldefine.} = false

macro tco(function: untyped): untyped =
  ## make it all make sense...
  dressWithPragmas function

type
    Fun*[T, R] {.union.} = object
      fn: Fn[T, R]
      n: int
      p: pointer

    Fn*[T, R] = proc(x: ptr T; m: pointer; r: ptr R) {.tco.}

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
    block:  # for nlvm
      let n = index
      if n <= functions.high:
        cast[tipe](functions[n])
      else:
        when pcpDynamic:
          cast[tipe](n)
        else:
          raise Defect.newException "no dynamic continuations"

proc register*(function: NimNode): NimNode =
  genAstOpt({}, function, functions=bindSym"functions"):
    once:
      functions.add: cast[pointer](function)

macro serialize*[T, R](fun: Fn[T, R]): untyped =
  result = newGeneric(bindSym"Fun", T.getTypeInst, R.getTypeInst)
  result = newStmtList(register(fun), ser(fun, result))

macro deserialize*(index: int; tipe: typedesc): untyped =
  deser(index, tipe)

proc fp(fun: NimNode): NimNode =
  let t = getTypeInst fun
  result = deser(newDotExpr(fun, ident"n"),
                 newGeneric(bindSym"Fn", t[1], t[2]))

macro fp*[T, R](fun: Fun[T, R]): untyped =
  ## recover a function pointer from `fun`
  result = fp(fun)

{.push experimental: "callOperator".}
macro `()`*[T, R](fun: Fun[T, R]; args: varargs[typed]): untyped =
  ## call `fun` with `args`
  let t = newGeneric(bindSym"Fn", T, R)
  result = newCall(fun.fp)
  for arg in args.items:
    result.add arg
{.pop.}
