import pkg/criterion

import pcp

proc demo(n: uint): uint {.discardable.} =
  type
    Foo[T] {.byref.} = object
      fn: Fun
      a: T
      b: T

  proc fib[T](foo: ptr Foo[T]; mom: pointer; r: ptr T) {.tco.} =
    case r[]
    of 0:
      r[] = foo[].a
    of 1:
      r[] = foo[].b
    else:
      dec r[]
      var n = foo[].a + foo[].b
      foo[].a = foo[].b
      foo[].b = n
      foo.recurse(r)

  proc calc[T](t: T): T =
    result = t
    var foo: Foo[T]
    foo.a = 0
    foo.b = 1
    foo.fn.fp = cast[Fn](fib[T])
    foo.fn(addr foo, cast[pointer](nil), addr result)

  result = calc n
  case n
  of 35: doAssert result == 9227465'u
  of 93: doAssert result == 12200160415121876738'u
  else: echo n, "=", result

proc main =
  var cfg = newDefaultConfig()
  cfg.warmupBudget = 3.0
  cfg.budget = 1.0
  cfg.verbose = true

  benchmark cfg:
    proc tailcall() {.measure.} =
      demo(93)

main()
