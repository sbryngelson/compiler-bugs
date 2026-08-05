# flang/OpenMP: `ordered` is not honoured in device offload -- wrong results

| | |
|---|---|
| Issue | [llvm#214257](https://github.com/llvm/llvm-project/issues/214257) |
| Fix PR | [llvm#214263](https://github.com/llvm/llvm-project/pull/214263) -- `[OpenMPIRBuilder] Emit a dispatch loop for ordered worksharing loops on the device` |

A conforming program using `ordered` inside a target region gets wrong results. The same source is
correct on the host, and the C equivalent is correct on the same GPU under clang.

| build | result |
|---|---|
| flang, gfx90a | `FAIL: 64 iterations out of order` |
| amdflang AFAR 23.2.1, gfx90a | identical |
| flang, host, `OMP_NUM_THREADS=8` | PASS |
| clang, `control.c`, gfx90a | PASS |

`repro.f90` fails 20/20 before the fix and passes 20/20 after.

## Cause

`ordered` needs a dispatch schedule so the runtime can order through `__kmpc_dispatch_fini`. The
device `__kmpc_ordered` in the DeviceRTL is an **empty stub** (`Synchronization.cpp`), so it
contributes no ordering by itself.

`OpenMPIRBuilder::applyWorkshareLoop` hands the loop to a `__kmpc_*_static_loop_*` entry on device
and discards its schedule arguments, `HasOrderedClause` among them
(`llvm/lib/Frontend/OpenMP/OMPIRBuilder.cpp`):

```cpp
if (Config.isTargetDevice())
  return applyWorkshareLoopTarget(DL, CLI, AllocaIP, LoopType, NoLoop);
```

clang switches to dispatch when `ordered` is present, which is why the C control passes.

## Fix (`fix.patch`)

1. Do not take the device shortcut when `ordered` is present, so the generic path emits a dispatch
   loop.
2. `applyDynamicWorkshareLoop` casts the four bound allocas before `__kmpc_dispatch_next`. They are
   in the alloca address space, non-zero on AMDGPU, while the runtime entry takes generic pointers.
   Without this the device module fails verification with "Call parameter type does not match
   function signature". The casts fold away where the alloca address space is zero, so the host is
   unchanged; loads and stores keep the original allocas.

Device IR for the ordered case goes from `__kmpc_for_static_loop_4u` to `__kmpc_dispatch_init_4u` /
`_next_4u` / `_fini_4u`. A loop without `ordered` still lowers to
`__kmpc_distribute_for_static_loop_4u`.

## A reproducer mistake worth keeping

The issue was first filed with `flaky_port.f90`, a Fortran port of
`offload/test/offloading/schedule.c`. That test compares `omp_get_wtime()` values, so threads can
come out in order by luck: **16 pass / 4 fail over 20 runs**. Three failing runs had been measured
and it was presented as failing consistently. A maintainer would have run it, seen it pass, and
closed the report. Corrected on the issue the same day.

`repro.f90` records the order in which iterations enter the region, which does not depend on timing,
and fails 20/20. **Prefer a reproducer that cannot pass by luck over one that looks more
authoritative.**

## Related

The same discarded-arguments line also drops `SchedKind`, `ChunkSize`, `HasDistSchedule` and
`DistScheduleChunkSize`, so the `schedule` clause is ignored on device. Still unfiled, see
`../../drafts/01-flang-device-schedule-ignored.md`.
