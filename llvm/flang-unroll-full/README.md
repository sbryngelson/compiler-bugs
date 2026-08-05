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

## Review notes (tblah)

* Constant-bounds verifier at the MLIR level: **could not be done as asked.** flang emits the trip
  count as a computed value even for `do i = 1, 100`
  (`%14 = arith.select %13, %c0_i32, %12`), so `matchPattern(tripCount, m_Constant())` rejects
  flang's own output. Verifiers run before folding and `getConstantIntValue` only matches literal
  constants. The verifier checks only that the applyee has a generator; the question is back with
  the reviewer.
* A lowering test combining `unroll full` with `tile`: **not possible**, the composition is broken
  for all three unroll forms, including the two that predate this PR. A `TODO` was added so the
  nested construct is diagnosed rather than silently dropped. See
  `../../drafts/04-flang-unroll-drops-nested-tile.md`.
* Replying to a top-level comment does **not** answer inline review threads. All three of tblah's
  threads sat unanswered until replied to inline. This is the same mistake recorded in
  `../../amd/openmp-outlined-not-inlined/README.md`, repeated two days later.
