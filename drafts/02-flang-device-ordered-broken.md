# DRAFT ISSUE — flang: ordered is not honoured in device offload (wrong results)

**Status:** ready to file. Deterministic, reproduces on upstream and on AFAR 23.2.1, and the same
source is correct on the host. This is a correctness bug, not a performance one.
Not yet searched exhaustively for an existing upstream issue.

**Title:** `[flang][OpenMP] ordered is ignored in target offload, giving wrong results`

---

A conforming program using `ordered` inside a target region produces wrong results with flang. The
same source compiled by flang for the host is correct, and the C equivalent compiled by clang for
the same GPU is correct.

```fortran
program p
  use omp_lib
  implicit none
  integer, parameter :: n = 64
  integer :: seq(n), pos, i, bad
  pos = 0
  seq = -1
  !$omp target parallel do ordered map(tofrom:seq,pos)
  do i = 1, n
     !$omp ordered
     pos = pos + 1
     seq(pos) = i
     !$omp end ordered
  end do
  bad = 0
  do i = 1, n
     if (seq(i) /= i) bad = bad + 1
  end do
  if (bad == 0) then
     print *, "PASS ordered preserved"
  else
     write(*,'(A,I4,A)') "  FAIL: ", bad, " iterations out of order"
     write(*,'(A,16I4)') "  first 16: ", seq(1:16)
  end if
end program
```

| build | result |
|---|---|
| flang, `--offload-arch=gfx90a` | `FAIL: 64 iterations out of order`, `seq(1:16) = 61 -1 -1 ...` |
| amdflang AFAR 23.2.1, gfx90a | identical failure |
| flang, host, `OMP_NUM_THREADS=8` | `PASS ordered preserved` |
| clang, C equivalent, gfx90a | `PASS ordered preserved` |

Deterministic: 3/3 runs each.

Every thread reads the same `pos`, so the ordered region is providing no mutual exclusion or
ordering at all.

## Cause

`ordered` requires a dispatch (dynamic) loop schedule so the runtime can enforce ordering through
`__kmpc_dispatch_fini`. clang switches to dispatch when `ordered` is present; its device IR has
`__kmpc_dispatch_init_4`, `__kmpc_dispatch_next_4`, `__kmpc_dispatch_fini_4` alongside
`__kmpc_ordered`.

flang keeps the static-loop path — its device IR has `__kmpc_for_static_loop_4u` with
`__kmpc_ordered` — so `__kmpc_ordered` has no dispatch machinery to order against.

The reason is that `OpenMPIRBuilder::applyWorkshareLoop` discards its schedule-related arguments on
the device path (`llvm/lib/Frontend/OpenMP/OMPIRBuilder.cpp:6497`):

```cpp
if (Config.isTargetDevice())
  return applyWorkshareLoopTarget(DL, CLI, AllocaIP, LoopType, NoLoop);
```

`HasOrderedClause` is among the dropped arguments, along with `SchedKind`, `ChunkSize`,
`HasDistSchedule` and `DistScheduleChunkSize`. Same root cause as draft 01, more severe symptom.

## Possible fixes

Either route `ordered` through the dispatch path on device as clang does, or reject the
combination with a diagnostic until that works. Silently producing wrong results is the worst of
the three.
