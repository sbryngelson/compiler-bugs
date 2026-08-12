# flang/OpenMP: the FULL clause on UNROLL was unimplemented

| | |
|---|---|
| Issue | [llvm#214114](https://github.com/llvm/llvm-project/issues/214114) |
| PR | [llvm#214115](https://github.com/llvm/llvm-project/pull/214115) |

`!$omp unroll full` was parsed and then aborted in lowering with
`not yet implemented: Unhandled clause FULL in UNROLL construct`. `partial` had landed in
llvm#206642 and bare `unroll` in llvm#144785, so `full` was the remaining clause.

The work is an MLIR op (`omp.unroll_full`), its translation, and the flang lowering.
`OpenMPIRBuilder::unrollLoopFull` already existed, so no LLVM-level change was needed.

Two clause rules that clang enforces and flang did not are included:

* `full` and `partial` are now mutually exclusive. `OMP_Unroll` listed both in
  `allowedOnceClauses`; moving them to `allowedExclusiveClauses` matches `OMP_TaskLoop`'s
  `grainsize`/`num_tasks` and keeps the at-most-once check, because the checker uses
  `allowedOnce | allowedExclusive`. Only flang reads that field, so clang is unaffected.
* A fully unrolled loop must have a compile-time constant trip count.

## Why the performance motivation was dropped

This started from a performance question, and the honest measurement does not support one upstream.
On an MFC-style WENO+HLLC kernel on gfx90a, upstream flang's existing heuristics already unroll
these loops and the directive changes nothing measurable: **0.274 ms baseline vs 0.292 ms**,
interleaved best-of-5. On AMD's downstream compiler the same source is **1.28x** faster with
unrolling forced, because its default threshold differs.

An earlier sequential (non-interleaved) measurement appeared to show the directive winning upstream.
Interleaving the configurations removed the effect. **Interleave configurations before believing a
small delta.**

The argument for the feature is therefore standards conformance and explicit per-loop control, with
the AFAR-vs-upstream divergence as evidence that leaving it to heuristics is fragile.

## Review notes

### tblah, resolved

* Constant-bounds verifier at the MLIR level. flang emitted the trip count as a computed value even
  for `do i = 1, 100` (`%14 = arith.select %13, %c0_i32, %12`), so
  `matchPattern(tripCount, m_Constant())` rejected flang's own output, and a fold-aware verifier is
  not possible because MLIR folding mutates IR, which a verifier may not do. tblah decided against
  a cleverer verifier and folded the trip count in flang instead, in
  [llvm#215238](https://github.com/llvm/llvm-project/pull/215238), **merged 2026-08-10**
  (`e4293ab25404`). The verifier was then added on top in `e7c6eec5b7e7`, with negative tests in
  `mlir/test/Dialect/OpenMP/invalid-unroll.mlir`.
* A lowering test combining `unroll full` with `tile`: **not possible**, the composition is broken
  for all three unroll forms, including the two that predate this PR. A `TODO` was added so the
  nested construct is diagnosed rather than silently dropped. See
  `../../drafts/04-flang-unroll-drops-nested-tile.md`.
* Replying to a top-level comment does **not** answer inline review threads. All three of tblah's
  threads sat unanswered until replied to inline. This is the same mistake recorded in
  `../../amd/openmp-outlined-not-inlined/README.md`, repeated two days later.

### Saieiei, 2026-08-10, both concerns withdrawn 2026-08-11

**Check the folded trip count instead of each bound.** The OpenMP restriction is on the iteration
count, so `do i = m, m` has a trip count of one whatever `m` is, and the per-bound check rejects it.
Rewriting the check to build `evaluate::CountTrips` and fold it is the right shape, **but it does
not change which programs are accepted**, and this was measured rather than assumed:

* flang does not fold `m - m`. `size(a(m:m))` unparses to `max((m - m + 1)/1, 0)` while
  `size(a(2:4))` folds to `3`. That is the same `CountTrips` expression on the same folder, so the
  probe is direct. Cause is `fold-implementation.h`: `Subtract` folds only under
  `OperandsAreConstants`, and there is no `x - x` identity.
* clang rejects the equivalent C: `for (int i = m; i <= m; ++i)` under `#pragma omp unroll full`
  gives `error: loop to be fully unrolled must have a constant trip count`. So accepting it in
  flang would **diverge** from clang, not align with it.
* The folded form would need a guard the per-bound form does not: a constant zero step makes the
  folder divide by zero. `size(a(1:10:0))` emits `warning: INTEGER(8) division by zero
  [-Wfolding-exception]` on top of the existing `-Wzero-do-step` warning.

The check was left as-is and the reasoning posted inline; Saieiei withdrew the concern.

**Strengthen the nested-loop metadata test.** `openmp-unroll-full02.mlir` only proved that *some*
loop carried `llvm.loop.unroll.full`. Fixed in `c9d94db`: the checks key off the two trip counts
and the store to tell the loops apart, require the metadata on the inner backedge, and anchor the
outer backedge's `br` at end of line so stray metadata there fails. **Verified by moving
`omp.unroll_full` to the outer loop: the old test still passed, the new one fails.** Changing a
test to be stricter is worth nothing until you have seen it fail on the thing it now catches.
