import pcp

proc main =
  type
    Foo[T] {.byref.} = object
      fn: Fun[Foo[T], T]
      a: T
      b: T

    Bar[T, R] {.byref.} = object
      fn: Fun[Bar[T, R], R]
      t: T

  proc fib[T, R](bar: ptr Bar[T, R]; r: ptr R) {.tco.} =
    if bar[].t < 2:
      r[] += R bar[].t
    else:
      var x = bar[]
      x.t = bar[].t-1
      x.fn(addr x, r)
      bar[].t = bar[].t-2
      mustTail bar[].fn(bar, r)

  proc fib[T](foo: ptr Foo[T]; r: ptr T) {.tco.} =
    if foo[].a < 2:
      foo[].b += foo[].a
      r[] += foo[].b
    else:
      var x: Bar[T, T]
      x.t = foo[].a-1
      x.fn = serialize fib[T, T]
      x.fn(addr x, r)
      foo[].a = foo[].a-2
      mustTail foo[].fn(foo, r)

  proc calc[T](a, b: T): T =
    var foo: Foo[T]
    foo.a = a
    foo.b = b
    foo.fn = serialize fib[T]
    foo.fn(addr foo, addr result)

  proc calc[T, R](t: T): R =
    var bar: Bar[T, R]
    bar.t = t
    bar.fn = serialize fib[T, R]
    bar.fn(addr bar, addr result)

  doAssert 102334155 == calc(40'i32, 0)
  doAssert 102334155 == calc[int64, uint](40)

main()
