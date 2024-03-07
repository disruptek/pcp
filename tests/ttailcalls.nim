import std/atomics
import std/hashes

import pcp

const N =
  when defined(danger):
    10_000
  else:
    100

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

proc flip(x: int): bool {.tco.} =
  return work(x) > 0

import pkg/criterion

proc main =
  var cfg = newDefaultConfig()
  cfg.warmupBudget = 0.1
  cfg.budget = 0.1

  echo "\nexpect that flicker < flapper < flipper\n"

  benchmark cfg:
    proc flicker_recurse() {.measure.} =
      n.store(N)
      flick(0)

    proc flapper_tail() {.measure.} =
      n.store(N)
      flap(0)

    proc flipper_loop() {.measure.} =
      n.store(N)
      var x = N
      while flip(x):
        dec x

main()
