# flang/OpenMP: `ordered` is not honoured in device offload -- wrong results

| | |
|---|---|
| Issue | [llvm#214257](https://github.com/llvm/llvm-project/issues/214257) |
| Fix PR | [llvm#214263](https://github.com/llvm/llvm-project/pull/214263) -- `[OpenMPIRBuilder] Emit a dispatch loop for ordered worksharing loops on the device`. Green 2026-08-05, reviewers tagged (skatrak, tblah) |

**CI red once for a reason that was not ours (2026-08-05).** The first run died building
`SLPVectorizer.cpp` on `error: captured structured bindings are a C++20 extension` -- a file this PR
does not touch. Upstream broke it and fixed it two minutes later in `5d234827e`; the run just landed
in that window. A rebase cleared it. Before debugging a premerge failure, check whether the failing
file is even in the diff, and whether the base commit predates a known fix.

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

## Review, jdoerfert 2026-08-14

Questioned the design, not the testing: "You now drop into host workshare generation for ordered
because the device side isn't implemented properly. Shouldn't we implement the device side
instead?", plus "device dynamic schedules are inherently slow and untested and should likely be
converted to static schedules anyway."

**Implementing it device-side is blocked by a missing primitive.** The ordered region sits inside
the loop body, so `__kmpc_ordered` would have to block until a shared counter reaches the caller's
iteration. It takes `(loc, tid)` and no iteration, so either its signature changes, which also hits
clang since clang emits it on device, or the `*_static_loop_*` driver stashes the index in
per-thread state. Both need threads to wait on each other inside a wavefront, and on AMDGPU every
lock primitive is `__builtin_trap()`:

```cpp
// TODO: Don't have wavefront lane locks. Possibly can't have them.
```

That is the same constraint that makes `setCriticalLock` elect a single lane rather than block,
i.e. the reason llvm#215009 works the way it does.

**Answering "untested":** 48 configurations (31/256/1000 iterations x 2/8/64/128 threads x
default/dynamic/static,4/guided), 5 runs each on gfx90a, device execution asserted in the program.
240/240 fail without the patch, 0/240 with it. No measurable time difference, though these kernels
are small enough to be launch-bound, so that is not a general statement about dispatch cost.
Harness: `../../../dthunt/ord_stress.f90`.

**The stress harness took four audits before it was worth running.** In order: `t=1` and `n=1`
cells could not fail; one run per config for a race; per-config pass/fail was taken from the last
rep only, inverting the result for a flaky failure; `seq(pos)` wrote out of bounds if an iteration
ran twice; the summary printed the total run count under a "failing runs" label; a hang produced no
output; and, worst, there was no device-execution guard, so a silent host fallback would have made
every run a false pass **including the baseline**. Only the first of those was visible from the
test's own output.

An IR-level test was added at `mlir/test/Target/LLVMIR/omptarget-wsloop-ordered.mlir`, per the
convention in `129267e8fcfc`: OMPIRBuilder codegen changes get an MLIR lit test, DeviceRTL changes
get an `offload/test` execution test.

