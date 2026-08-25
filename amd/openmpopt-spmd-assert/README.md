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

## Still live on 2026-08-13

Reproduces unchanged on main `254e1671845f`, assertions build, at both `-O1` and `-O2`.

**The driver path does not reach it.** `flang -fopenmp --offload-arch=gfx90a -c repro.f90` compiles
cleanly at every optimisation level, so a clean exit through the driver is **not** evidence the bug
is gone. Only the `-fc1` invocation in the reproducer header triggers it:

```
flang -fc1 -emit-llvm -fopenmp -fopenmp-is-target-device \
      -triple amdgcn-amd-amdhsa -O1 -o - repro.f90
```

I concluded this was fixed off a clean driver run and was wrong; the recheck with the documented
invocation aborted immediately. Noted upstream in
[the issue](https://github.com/llvm/llvm-project/issues/211423#issuecomment-5283914570).

**General lesson: when re-testing a crash, reproduce it with the invocation the report specifies,
not a convenient equivalent.** A different driver path can skip the pass entirely. This is the same
shape as the vacuous-test problem in `../../llvm/mir-bb-name-quoting/README.md`: a test or a check
that passes for the wrong reason tells you nothing.

## Not a bug: closed 2026-08-25

skatrak: the `-fc1` invocation in the report is incomplete. Device compilation needs
`-fopenmp-host-ir-file-path` pointing at host bitcode; that is where the offload entries are
identified, and without it the kernel function never gets the `"kernel"` attribute that
`omp::isOpenMPKernel` checks (it is just `Fn.hasFnAttribute("kernel")`).

```
flang -fc1 -emit-llvm-bc -fopenmp --offload-targets=amdgcn-amd-amdhsa -O1 -o host.bc repro.f90
flang -fc1 -emit-llvm -fopenmp -fopenmp-is-target-device -fopenmp-host-ir-file-path host.bc \
      -triple amdgcn-amd-amdhsa -O1 -o - repro.f90
```

| invocation | -O1 | -O2 |
|---|---|---|
| with `-fopenmp-host-ir-file-path` | clean | clean |
| without | assert | assert |

**The earlier note in this entry was wrong and is retracted.** It said the driver path compiling
cleanly was a trap, and that only `-fc1` reproduced the real bug. Backwards: the driver builds the
host bitcode first and passes it, so the driver is the *correct* invocation and the report's `-fc1`
line was the broken one. Generalising "reproduce it the way the report says" was the wrong lesson;
the right one is **check that the reported invocation is complete before trusting it**, especially
for a `-fc1` command line, where the driver normally supplies flags by hand.

Root-causing the mechanism first was still what made this quick to confirm: knowing the assert
reduces to a missing function attribute meant skatrak's diagnosis could be checked in two commands.
Also noted along the way: the assert at `OpenMPOpt.cpp:4332` sits eight lines above the
already-SPMD early-out, and flang kernels arrive with exec mode 2 (SPMD), so on this path it would
have returned immediately anyway.

