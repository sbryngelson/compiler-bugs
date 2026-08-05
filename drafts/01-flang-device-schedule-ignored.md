# DRAFT ISSUE — flang ignores the schedule clause in device offload

**Status:** ready to file. Confirmed deterministic and observable. Not yet searched exhaustively
for an existing upstream issue (`gh search` returned nothing but has failed silently before).

**Title:** `[flang][OpenMP] The schedule clause is ignored for target offload`

---

`schedule(static, C)` on a target construct is silently ignored by flang. The iteration-to-thread
mapping is the same for every chunk size, and matches `schedule(static, 1)`.

Recording `omp_get_thread_num()` per iteration, `num_teams(1) thread_limit(8)`, 32 iterations:

| clause | clang (C) | flang (Fortran) |
|---|---|---|
| `schedule(static,1)` | `0 1 2 3 4 5 6 7 0 1 ...` | `0 1 2 3 4 5 6 7 0 1 ...` |
| `schedule(static,4)` | `0 0 0 0 1 1 1 1 ...` | `0 1 2 3 4 5 6 7 ...` |
| `schedule(static,8)` | `0 0 0 0 0 0 0 0 ...` | `0 1 2 3 4 5 6 7 ...` |
| none | `0 1 2 3 4 5 6 7 ...` | `0 1 2 3 4 5 6 7 ...` |

clang honours the chunk as specified; flang produces `static,1` behaviour for all of them.

At the IR level every schedule kind produces a byte-identical call. `schedule(static,8)`,
`schedule(dynamic)`, `schedule(dynamic,4)`, `schedule(guided)`, `schedule(runtime)` and no clause
at all all emit:

```
call void @__kmpc_distribute_for_static_loop_4u(..., i32 128, i32 %2, i32 0, i32 0, i8 0)
                                                        num_iters  nthr  blockchunk=0 threadchunk=0
```

clang, by contrast, emits `__kmpc_dispatch_init_4` / `__kmpc_dispatch_next_4` for `dynamic` and
`guided`.

## Cause

`OpenMPIRBuilder::applyWorkshareLoop` takes the schedule information and the device path drops it
(`llvm/lib/Frontend/OpenMP/OMPIRBuilder.cpp:6497`):

```cpp
if (Config.isTargetDevice())
  return applyWorkshareLoopTarget(DL, CLI, AllocaIP, LoopType, NoLoop);
```

`SchedKind`, `ChunkSize`, `HasDistSchedule`, `DistScheduleChunkSize`, `HasOrderedClause` and the
simd/monotonic modifiers are all discarded. `applyWorkshareLoopTarget` then always passes
`block_chunk = 0` and `thread_chunk = 0` to the runtime.

A consequence worth noting: `StaticLoopChunker::NormalizedLoopNestChunked` in the DeviceRTL is
unreachable from flang, since the chunk arguments are always zero.

## Reproducer

`map.f90` / `map.c` as above.

## Scope note

The chunk being ignored is deterministic and observable, as shown. `schedule(dynamic)` also
collapsing to static is clear at the IR level, but I was **not** able to demonstrate a runtime
difference: on a deliberately load-imbalanced loop, clang's `dynamic` was no faster than its
`static`, so I am not claiming a performance impact for that part.
