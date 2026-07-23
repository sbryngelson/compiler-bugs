# flang/OpenMP: non-deterministic segfault lowering `allocate()` on a target construct in a module

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
