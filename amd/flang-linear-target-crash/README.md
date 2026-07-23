# flang/OpenMP: segfault in `OpenMPIRBuilder::createParallel` for `linear()` on a device target construct

**Status: OPEN.** Reported: [llvm/llvm-project#211429](https://github.com/llvm/llvm-project/issues/211429).

```
flang -fc1 -emit-llvm -fopenmp -fopenmp-is-target-device \
      -triple amdgcn-amd-amdhsa -O3 -o /dev/null repro.f90
  -> Segmentation fault
```

Deterministic, 20/20 at `02c51adb8ff2`. Isolated with an identical module and body:

| clause | body | crashes |
|---|---|---|
| `linear(j)` | `j = j + 1; ...` (`repro.f90`) | 10/10 |
| *(none)* | same | 0/10 |
| `linear(j)` | `j` never modified (`repro_readonly_j.f90`) | **10/10** |
| `private(j)` | `j = j + 1; ...` (`control_private_j.f90`) | 0/10 |

The read-only row matters: the crash does not depend on assigning to the `linear` variable, so it is
not an argument about whether that assignment is conforming. `-emit-hlfir` is clean 20/20, so it is in the outlining
path rather than the frontend:

```
 #4 llvm::CodeExtractorAnalysisCache::findSideEffectInfoForBlock(llvm::BasicBlock&)
 #5 llvm::CodeExtractorAnalysisCache::CodeExtractorAnalysisCache(llvm::Function&)
 #6 llvm::OpenMPIRBuilder::createParallel(...)
```

Legal clause: `OMP.td` lists `OMPC_Linear` in `allowedClauses` for
`OMP_TargetTeamsDistributeParallelDoSimd`.

Not reproduced on amdflang AFAR 23.2.1 (LLVM 23) or ROCm 7.2.0 (LLVM 22) — possibly a 24-cycle
regression, not bisected.


## Corrected scope (2026-07-22)

`simd` is not required, and it is device-only:

| directive | host | device |
|---|---|---|
| `parallel do linear(j)` | 0/10 | 0/10 |
| `parallel do simd linear(j)` | 0/10 | 0/10 |
| `target teams distribute parallel do linear(j)` (`repro_no_simd.f90`) | 0/10 | **10/10** |
| `target teams distribute parallel do simd linear(j)` (`repro.f90`) | 0/10 | **10/10** |

Also independent of the module wrapper — a bare subroutine crashes 10/10 — and reproduced on a
pristine build of `02c51adb8ff2`.
