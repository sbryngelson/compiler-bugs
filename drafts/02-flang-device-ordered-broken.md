# FILED as llvm/llvm-project#214257 (2026-08-05)

Text as filed:

---

The Fortran equivalent of an upstream offload runtime test fails on the same GPU where the C
version passes. `ordered` inside a target region does not order anything in flang.

`offload/test/offloading/schedule.c` is shipped upstream and verifies that an ordered region on a
target construct executes in iteration order. It passes on gfx90a:

```console
$ clang -fopenmp --offload-arch=gfx90a -O2 offload/test/offloading/schedule.c -o schedc && ./schedc
test no order OK
test ordered OK
```

A line-for-line Fortran port of the `ordered_example` part of that test fails:

```fortran
program p
  use omp_lib
  implicit none
  integer, parameter :: lb = 0, ub = 100, stride = 1, nteams = 8
  integer, parameter :: sz = (ub - lb) / stride
  real(8) :: output(sz)
  integer :: i, j, jj, bad
  output = 0.0d0
  !$omp target teams map(from:output) num_teams(nteams) thread_limit(128)
  !$omp parallel do ordered schedule(dynamic)
  do i = lb, ub - 1, stride
     !$omp ordered
     output((i - lb)/stride + 1) = omp_get_wtime()
     !$omp end ordered
  end do
  !$omp end target teams
  bad = 0
  do j = 1, sz
     do jj = j + 1, sz
        if (output(j) > output(jj)) bad = bad + 1
     end do
  end do
  if (bad == 0) then
     print *, "test ordered OK"
  else
     print '(A,I6,A)', "  Fail to schedule in order: ", bad, " inversions"
  end if
end program
```

| build | result |
|---|---|
| `clang`, the C test, gfx90a | `test ordered OK` |
| `flang`, the port, gfx90a | `Fail to schedule in order: 2048 / 1024 / 1280 inversions` |
| `flang`, the port, host, `OMP_NUM_THREADS=8` | `test ordered OK` |
| `amdflang` AFAR 23.2.1, gfx90a | fails likewise |

The inversion count varies between runs, as expected for a race. A smaller deterministic variant,
recording the order in which iterations enter the region, shows every iteration reading the same
counter, so the region provides no ordering or mutual exclusion at all.

## Cause

`ordered` needs a dispatch schedule so the runtime can enforce ordering through
`__kmpc_dispatch_fini`. clang's device IR for the C test has `__kmpc_dispatch_init_4`,
`__kmpc_dispatch_next_4` and `__kmpc_dispatch_fini_4` alongside `__kmpc_ordered`. flang's has
`__kmpc_for_static_loop_4u` with `__kmpc_ordered`, so there is nothing for `__kmpc_ordered` to
order against.

`OpenMPIRBuilder::applyWorkshareLoop` discards its schedule-related arguments on the device path
(`llvm/lib/Frontend/OpenMP/OMPIRBuilder.cpp:6497`):

```cpp
if (Config.isTargetDevice())
  return applyWorkshareLoopTarget(DL, CLI, AllocaIP, LoopType, NoLoop);
```

`HasOrderedClause` is dropped there, along with `SchedKind`, `ChunkSize`, `HasDistSchedule` and
`DistScheduleChunkSize`. The `schedule(dynamic)` in this same test is therefore also ignored; I will
file that separately since the severity is different.

Either route `ordered` through the dispatch path on device as clang does, or reject the combination
with a diagnostic until that works.

## Notes

I have not bisected, so I cannot say whether this is a regression or has always been the case.
