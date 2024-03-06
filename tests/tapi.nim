import pcp/registry
import pcp/tailcalls

when compileOption"stacktrace":
  quit 1

proc main =
  type
    Foo[T] {.byref.} = object
      fn: Fun[Foo[T], T]
      a: T
      b: T

    Bar[T, R] {.byref.} = object
      fn: Fun[Bar[T, R], R]
      t: T

  proc fib[T, R](bar: ptr Bar[T, R]; r: ptr R) {.nimcall.} =
    if bar[].t < 2:
      r[] += R bar[].t
    else:
      var x = bar[]
      x.t = bar[].t-1
      x.fn(addr x, r)
      bar[].t = bar[].t-2
      var p = bar[].fn.fp
      mustTail p(bar, r)

  proc fib[T](foo: ptr Foo[T]; r: ptr T) {.nimcall.} =
    if foo[].a < 2:
      foo[].b += foo[].a
      r[] += foo[].b
    else:
      var x: Bar[T, T]
      x.t = foo[].a-1
      x.fn = serialize: Fn[Bar[T, T], T] fib[T, T]
      x.fn(addr x, r)
      foo[].a = foo[].a-2
      var p = foo[].fn.fp
      mustTail p(foo, r)

  proc calc[T](a, b: T): T =
    var foo: Foo[T]
    foo.a = a
    foo.b = b
    register(Fn[Foo[T], T] fib[T])
    foo.fn = serialize: Fn[Foo[T], T] fib[T]
    foo.fn(addr foo, addr result)

  proc calc[T, R](t: T): R =
    var bar: Bar[T, R]
    bar.t = t
    register(Fn[Bar[T, R], R] fib[T, R])
    bar.fn = serialize fib[T, R]
    bar.fn(addr bar, addr result)

  doAssert 102334155 == calc(40'i32, 0)
  doAssert 102334155 == calc[int64, uint](40)

main()
