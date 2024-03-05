import std/genasts
import std/macrocache
import std/macros

var fn: seq[pointer]
fn.add(nil)

macro register*(fun: typed): untyped =
  genAstOpt({}, fun, fn=bindSym"fn", name=fun):
    fn.add(cast[pointer](fun))

proc ser(fun: NimNode): NimNode =
  genAstOpt({}, fn=bindSym"fn", p=fun):
    var i: pointer = nil
    block found:
      for index, item in fn.pairs:
        if item == p:
          i = cast[pointer](index)
          break found
      i = p
    cast[int](i)

proc deser(index: NimNode; tipe: NimNode): NimNode =
  genAstOpt({}, tipe, fn=bindSym"fn", i=index):
    if i <= fn.high:
      cast[tipe](fn[i])
    else:
      cast[tipe](i)

proc deser(index: NimNode): NimNode =
  deser(index, bindSym"pointer")

macro serialize*(fun: typed): untyped =
  ser fun

macro deserialize*(index: typed; tipe: typedesc): untyped =
  deser(index, tipe)

macro call*(index: typed; tipe: typedesc; args: varargs[typed]): untyped =
  result = deser(index, tipe)
  result = newCall result
  for arg in args.items:
    result.add arg
