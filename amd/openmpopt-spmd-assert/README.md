# OpenMPOpt: `changeToSPMDMode` asserts on a reachable target region containing a parallel region

**Status: OPEN.** Reported: [llvm/llvm-project#211423](https://github.com/llvm/llvm-project/issues/211423).

```
OpenMPOpt.cpp:4273: bool AAKernelInfoFunction::changeToSPMDMode(Attributor &, ChangeStatus &):
  Assertion `omp::isOpenMPKernel(*Kernel) && "Expected kernel function!"' failed.
```

## Scope — read this before acting on it

**Assertions builds only.** Release builds compile the same source without complaint, including
amdflang from AFAR 23.2.1 and ROCm 7.2.0. This is **not** a production miscompile and does not
affect MFC. The cost is that it aborts assertions builds, which blocks adding flang device tests at
`-O1` — that is how it was found.

## Relationship to the earlier report

[#179930](https://github.com/llvm/llvm-project/issues/179930) is the same assertion, reported by
@abidh and closed as fixed by [#178937](https://github.com/llvm/llvm-project/pull/178937). That case
was a target region in an **unreachable** function. This one is reachable and contains a **parallel**
region, and `deedc7bfe315` (the fix) is an ancestor of both trees tested — so it is a different
trigger, not a regression of that fix.

Possibly related: [#50991](https://github.com/llvm/llvm-project/issues/50991), same assertion via
`--cuda-noopt-device-debug`.

## Evidence

Cleanest: premerge CI at `02c51adb8ff2` on an unrelated PR
([#211395 job log](https://github.com/llvm/llvm-project/actions/runs/29960239643/job/89073326397)) —
an assertions build of tip running a real `flang -fc1 ... -O1` device compile. No version mixing.

Locally, feeding `-O0` device IR to an assertions-enabled `opt`:

| pipeline | result |
|---|---|
| `-passes=openmp-opt` | asserts |
| `-passes='default<O1>'` | asserts |
| `-passes='default<O2>'` | asserts |
| `target teams distribute` with no `parallel` | ok |

Fires with and without `-debug-info-kind=standalone`, and whether or not the subroutine has a caller.

## Reproducer

`repro.f90` — build per the comment at the top.
