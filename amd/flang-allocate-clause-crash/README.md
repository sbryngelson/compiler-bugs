# flang/OpenMP: segfault lowering the `allocate` clause on a worksharing loop

**Status: OPEN. Not an offload bug** — it reproduces on ordinary host compilation with no
`target` construct anywhere; the offload framing in the first version of the report was wrong.

**Status: OPEN.** Reported: [llvm/llvm-project#211430](https://github.com/llvm/llvm-project/issues/211430).

```
flang -fc1 -emit-hlfir -fopenmp -fopenmp-is-target-device \
      -triple amdgcn-amd-amdhsa -o /dev/null repro.f90
  -> Segmentation fault (most of the time)
```

**Not deterministic**, which is the notable part. Same input, same command, at `02c51adb8ff2`:

Identical body throughout, only the clause changed:

| clause | file | crashes |
|---|---|---|
| `private(t) allocate(t)` | `repro.f90` | 16/20 |
| `private(t)` | `control_private_only.f90` | **0/20** |
| `allocate(t)` alone | — | 20/20 (deterministic; that form is likely invalid OpenMP) |
| `private(t) allocate(t)`, bare subroutine | `nocrash_bare_subroutine.f90` | 0/20 |

The first control published was measured against a module with a *different* loop body, so it
isolated more than the clause; the table above is the corrected version. Machine idle, 470 GB free,
so not environmental. A varying rate on a fixed input
points at a use-after-free or uninitialized read rather than a null dereference; an ASAN build should
pin it down. One captured stack:

```
 #4 llvm::omp::getDirectiveAssociation(llvm::omp::Directive)
 #5 genOMPDispatch(Fortran::lower::AbstractConverter&, ...)
```

Legal clause: `OMP.td` lists `OMPC_Allocate` in `allowedClauses` for
`OMP_TargetTeamsDistributeParallelDo`.

Not reproduced on AFAR 23.2.1 or ROCm 7.2.0 (0/10 each).


## Corrected scope (2026-07-22)

Filed originally as a target/module/non-deterministic crash. That framing was wrong. The simplest
reproducer has no `target` at all and is **deterministic**:

| directive (identical body, host compilation) | crashes |
|---|---|
| `parallel do private(t) allocate(t)` (`repro_host_no_target.f90`) | **10/10** |
| `parallel do private(t)` (`control_private_only.f90`) | 0/10 |
| `target teams distribute parallel do private(t) allocate(t)` (`repro.f90`) | 7/10 host, 14/20 device |
| `target teams distribute parallel do private(t)` | 0/20 |

The trigger is `allocate` alongside a privatizing clause; the target construct is incidental and
only adds the non-determinism. Reproduced on a pristine build of `02c51adb8ff2` with no local
patches.
