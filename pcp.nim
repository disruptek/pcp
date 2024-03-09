import std/macros

import pcp/registry
import pcp/tailcalls
import pcp/ast

export mustTail, tco, `fp=`
export Fun, Fn, serialize, `()`
export pcpHasTailCalls

proc looksLikePtr(n: NimNode): bool =
  n.kind == nnkBracketExpr and n[0].kind == nnkPtrTy

macro recurse*(this: typed; r: typed): untyped =
  ## recurse using `this` as the continuation and `r` as the result.
  result = this
  if this.looksLikePtr:
    result = nnkDerefExpr.newTree(this)
  result = newDotExpr(result, ident"fn")
  result = newCall(result, this, newCast(pointer, newNilLit()), r)
  result = newCall(bindSym"mustTail", result)
