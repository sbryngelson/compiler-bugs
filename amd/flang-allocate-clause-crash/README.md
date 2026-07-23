# flang/OpenMP: non-deterministic segfault lowering `allocate()` on a target construct in a module

**Status: OPEN.** Reported: [llvm/llvm-project#211430](https://github.com/llvm/llvm-project/issues/211430).

```
flang -fc1 -emit-hlfir -fopenmp -fopenmp-is-target-device \
      -triple amdgcn-amd-amdhsa -o /dev/null repro.f90
  -> Segmentation fault (most of the time)
```

**Not deterministic**, which is the notable part. Same input, same command, at `02c51adb8ff2`:

| file | crashes |
|---|---|
| `repro.f90` — subroutine in a module | 14/20, and 8/10 on a repeat |
| `nocrash_bare_subroutine.f90` — identical body, no module | 0/20 |
| `control_no_allocate.f90` — same module, no `allocate` clause | 0/20 |

The control rules out the environment (machine idle, 470 GB free). A varying rate on a fixed input
points at a use-after-free or uninitialized read rather than a null dereference; an ASAN build should
pin it down. One captured stack:

```
 #4 llvm::omp::getDirectiveAssociation(llvm::omp::Directive)
 #5 genOMPDispatch(Fortran::lower::AbstractConverter&, ...)
```

Legal clause: `OMP.td` lists `OMPC_Allocate` in `allowedClauses` for
`OMP_TargetTeamsDistributeParallelDo`.

Not reproduced on AFAR 23.2.1 or ROCm 7.2.0 (0/10 each).
