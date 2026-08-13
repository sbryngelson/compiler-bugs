# flang/OpenMP: the `schedule` clause is ignored for target offload

| | |
|---|---|
| Issue | [llvm#214303](https://github.com/llvm/llvm-project/issues/214303) |
| Fix | none yet |

Every schedule kind and chunk size produces identical device code, and the iteration-to-thread
mapping is always that of `schedule(static,1)`. Deterministic: one unique output over 20 runs.

| clause | clang (`map.c`) | flang (`map.f90`) |
|---|---|---|
| `static,1` | `0 1 2 3 4 5 6 7 ...` | `0 1 2 3 4 5 6 7 ...` |
| `static,4` | `0 0 0 0 1 1 1 1 ...` | `0 1 2 3 4 5 6 7 ...` |
| `static,8` | `0 0 0 0 0 0 0 0 ...` | `0 1 2 3 4 5 6 7 ...` |
| none | `0 1 2 3 4 5 6 7 ...` | `0 1 2 3 4 5 6 7 ...` |

`static,8`, `dynamic`, `dynamic,4`, `guided`, `runtime`, `monotonic:static,4`,
`nonmonotonic:dynamic`, `simd:static,4`, `dist_schedule(static,4)` and no clause all emit a
byte-identical call with `block_chunk = 0, thread_chunk = 0`.

## Cause

Same line as [llvm#214257](https://github.com/llvm/llvm-project/issues/214257):
`applyWorkshareLoop` drops its schedule arguments on the device path. `SchedKind`, `ChunkSize`,
`HasDistSchedule`, `DistScheduleChunkSize` and the modifiers all go, alongside `HasOrderedClause`.

[llvm#214263](https://github.com/llvm/llvm-project/pull/214263) fixes the `ordered` half by falling
through to the generic path when `ordered` is present. The same approach may extend to `schedule`,
but that is a performance decision rather than a correctness one, so it was filed separately rather
than widening that patch.

## Root cause, and why the obvious fix is wrong

`createTargetLoopWorkshareCall` hardcodes `0` for both chunk arguments at all three call sites, and
`StaticLoopChunker` reads a zero chunk as "unspecified" and defaults `ThreadChunk` to 1. That is
exactly the reported symptom: every schedule collapses to the `static,1` mapping.

The obvious fix is to forward the chunk from `applyWorkshareLoop`. **That fix is wrong on its own**,
because the chunked path it would activate is broken. Two defects in
`openmp/device/src/Workshare.cpp`:

* `NormalizedLoopNestChunked` starts a thread at `BId * BlockChunk + TId`, with no `* ThreadChunk`.
  Threads start one index apart and then each run `ThreadChunk` consecutive iterations, so they
  overlap at the front and never visit the rest.
* `DistributeFor` defaults `BlockChunk` to `NumThreads`, which cannot hold one chunk of
  `ThreadChunk` iterations for each of `NumThreads` threads, so threads past the block chunk get
  nothing.

Measured on gfx90a by calling `__kmpc_distribute_for_static_loop_4u` directly, 32 iterations,
8 threads, `ThreadChunk=4`:

| block_chunk | thread_chunk | result |
|---|---|---|
| 0 | 0 | `0 1 2 3 4 5 6 7 ...`, nothing missing -- today's behaviour |
| 0 | 4 | **17 of 32 iterations never run** |
| 32 | 4 | **21 of 32 never run** |

With both lines fixed, `block_chunk=0 thread_chunk=4` gives exactly `0 0 0 0 1 1 1 1 ... 7 7 7 7`,
nothing missing, and the no-chunk default is bit-for-bit unchanged. Fix:
[llvm#216117](https://github.com/llvm/llvm-project/pull/216117). The frontend plumbing has to land
**after** it, otherwise it turns a wrong mapping into dropped iterations.

Two further hazards in the same helper, not fixed there:

* `__kmpc_for_static_loop` passes `BlockChunk = 0` unconditionally, so `KernelIteration` is zero,
  the induction variable never advances, and a non-1 thread chunk **never terminates**.
* The chunked path returns after a single iteration when `OneIterationPerThread` is set, which
  flang sets from no-loop mode. A chunk and no-loop together silently truncate.

## How this was found, and two near misses

The frontend patch was written and about to be filed as "contained plumbing" before any of the
above was checked. What caught it was transcribing `NormalizedLoopNestChunked` into a standalone
C++ program and running it: the simulation predicted `missing=17` and `missing=21`, and hardware
later reproduced **exactly** those numbers. Simulating a runtime you cannot easily rebuild is cheap
and was decisive; it still had to be confirmed on device before filing.

`ninja libompdevice` rebuilds the bitcode, **not** `libompdevice.a`, which is what the device link
actually consumes. The first patched run reported no change at all with a fresh-looking build. The
tell was that the fix should have produced a *differently* wrong mapping and instead produced an
identical one -- a prediction disagreeing with an observation is what exposed the stale artifact,
not a timestamp check. Rebuild `libompdevice.a` by name.

A side effect: `NormalizedLoopNestChunked` in the DeviceRTL is unreachable from flang, since the
chunk arguments are always zero. 252 chunked probes passed while never entering that code.

## What is not claimed

`schedule(dynamic)` collapsing to static is clear in the IR, but no runtime difference was
demonstrated: on a deliberately load-imbalanced loop, clang's `dynamic` was no faster than its
`static` on this GPU. The chunk being ignored is the part that is observable.
