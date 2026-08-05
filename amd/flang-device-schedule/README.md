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

A side effect: `NormalizedLoopNestChunked` in the DeviceRTL is unreachable from flang, since the
chunk arguments are always zero. 252 chunked probes passed while never entering that code.

## What is not claimed

`schedule(dynamic)` collapsing to static is clear in the IR, but no runtime difference was
demonstrated: on a deliberately load-imbalanced loop, clang's `dynamic` was no faster than its
`static` on this GPU. The chunk being ignored is the part that is observable.
