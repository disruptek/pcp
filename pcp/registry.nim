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
    Fun* {.union.} = object
      fn: Fn
      n: int
      p: pointer

    Fn* = proc(x: pointer; m: pointer; r: pointer) {.tco.}

proc `=copy`(target: var Fun; source: Fun) =
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

macro serialize*(fun: Fn): untyped =
  result = bindSym"Fun"
  result = newStmtList(register(fun), ser(fun, result))

macro deserialize*(index: int; tipe: typedesc): untyped =
  deser(index, tipe)

proc fp(fun: NimNode): NimNode =
  result = deser(newDotExpr(fun, ident"n"), bindSym"Fn")

macro fp*(fun: Fun): untyped =
  ## recover a function pointer from `fun`
  bindSym"Fn".newCast: fp(fun)

macro `fp=`*(lhs: Fun; rhs: typed): untyped =
  ## api for serialized function symbol assignment...
  result = getTypeImpl lhs
  result = result[2][0][1] # fn type
  # XXX: do some type-checking here
  result = nnkCast.newTree(result, rhs)
  result = newAssignment(lhs, newCall(bindSym"serialize", result))

{.push experimental: "callOperator".}
macro `()`*(fun: Fun; args: varargs[typed]): untyped =
  ## call `fun` with `args`
  result = newCall(fun.fp)
  for arg in args.items:
    result.add arg
{.pop.}
