import std/atomics
import std/hashes

import pkg/criterion

import pcp

const N =
  when pcpHasTailCalls:
    100_000
  else:
    10_000

var n: Atomic[int]

template work(x: int): untyped =
  fetchSub(n, 1)

# critically, provide some prototypes
proc flop(x: int) {.tco.}
proc flap(x: int) {.tco.}

proc flap(x: int) {.tco.} =
  var x = work(x)
  if x <= 0:
    return
  mustTail flop(x)

proc flop(x: int) {.tco.} =
  var x = work(x)
  if x <= 0:
    return
  mustTail flap(x)

proc flick(x: int) {.tco.} =
  var x = work(x)
  if x <= 0:
    return
  flick(x)

proc flip(x: int) {.tco.} =
  discard work(x)

proc main =
  var cfg = newDefaultConfig()
  cfg.warmupBudget = 0.1
  cfg.budget = 0.1

  benchmark cfg:
    proc looping() {.measure.} =
      n.store(N)
      var x = N
      while x > 0:
        flip(x)
        dec x

    when not pcpHasTailCalls:
      proc recursion() {.measure.} =
        n.store(N)
        flick(0)

    proc tailcall() {.measure.} =
      n.store(N)
      flap(0)

main()
