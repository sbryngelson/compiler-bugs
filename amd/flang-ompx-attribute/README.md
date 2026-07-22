# flang/OpenMP: no `ompx_attribute` clause → no way to set per-kernel launch bounds / occupancy in Fortran offload

Target: gfx90a (MI250X). Compiler: AMD flang 22.0.0git (ROCm 7.2.0); gaps re-verified against
upstream `llvm/llvm-project @ 119b31fd3`.

**Status: RFC — feature request, no PR yet** (the Fortran spelling needs a decision).
Reported: [llvm/llvm-project#211133](https://github.com/llvm/llvm-project/issues/211133).

## Tracking

| Where | Link / ID |
|-------|-----------|
| llvm/llvm-project | [#211133](https://github.com/llvm/llvm-project/issues/211133) — open, RFC |
| clang prior art | [#99927](https://github.com/llvm/llvm-project/pull/99927), [#195665](https://github.com/llvm/llvm-project/pull/195665), [#195203](https://github.com/llvm/llvm-project/pull/195203), user reports [#64815](https://github.com/llvm/llvm-project/issues/64815) / [#64816](https://github.com/llvm/llvm-project/issues/64816) |
| flang prior art | [#100370](https://github.com/llvm/llvm-project/pull/100370) — `applyClause(OmpxAttributeT...)` already added to `ConstructDecompositionT.h` |
| Source | [MFC](https://github.com/MFlowCode/MFC) |

## Bug

clang accepts `ompx_attribute` on OpenMP target constructs and lowers it to LLVM function
attributes. flang rejects it at parse time, so Fortran OpenMP offload cannot set per-kernel launch
bounds or occupancy hints at all:

```
$ flang -fopenmp --offload-arch=gfx90a -O3 ompx_attribute.f90 -o /dev/null
error: Could not parse ompx_attribute.f90
ompx_attribute.f90:20:85: error: expected '=>'
ompx_attribute.f90:20:45: in the context: pointer assignment statement
```

clang lowers the equivalent for real: device IR gains `"amdgpu-waves-per-eu"="4,4"` with the clause
and lacks it without.

## Root cause

Verified at `119b31fd3`, there are two gaps rather than one:

1. `OMPC_OMPX_Attribute` (`OMP.td:421`) has a `clangClass` but no `flangClass`, so tablegen emits
   `EMPTY_CLASS(OmpxAttribute)`, `ClauseT.h:1032` declares `OmpxAttributeT` as `EmptyTrait`,
   `Clauses.cpp:286` is `MAKE_EMPTY_CLASS`, and there is no parser rule.
2. The clause is not in the allowed-clause list of any Fortran-spelled directive. Mapping all 34
   `VersionedClause<OMPC_OMPX_Attribute>` sites: every C-spelled `...ParallelFor...` form is
   present and no `...ParallelDo...` form is. `OMP_TargetTeamsDistributeParallelDo`
   (`OMP.td:2529`, `let languages = [L_Fortran]`) lacks it, so a parser rule alone would parse and
   then fail the semantic check. The language-neutral directives do allow it.

Note `ompx_dyn_cgroup_mem` has a `flangClass`, a `make()` and a semantic `Enter()` but no parser
rule either — a shape reference, not working prior art.

## Why RFC, not PR — the Fortran spelling is undecided

clang parses the clause body with `ParseAttributes(PAKM_GNU | PAKM_CXX11, ...)`, accepting
`ompx_attribute(__attribute__((amdgpu_waves_per_eu(4,4))))` and
`ompx_attribute([[clang::amdgpu_waves_per_eu(4,4)]])`, and explicitly rejecting a bare attribute
name. Fortran has neither spelling, so any Fortran syntax is a divergent extension. Candidates:

- **bare name + integer list** — `ompx_attribute(amdgpu_waves_per_eu(4,4))` (minimal, but the form
  clang rejects)
- **the clang forms verbatim** — for source portability
- **modifier style** closer to modern clause grammar — `ompx_attribute(amdgpu_waves_per_eu: 4, 4)`

A working proof-of-concept for the first option exists (881 lines, 18 files, applies clean to
`119b31fd3`): parser, semantics, `ClauseT.h`, an `omp.target` attribute, and lowering that mirrors
clang's split (`amdgpu_waves_per_eu` onto the outlined function; `launch_bounds` and
`amdgpu_flat_work_group_size` through `TargetKernelDefaultAttrs` so
`writeThreadBoundsForKernel` / `writeTeamsForKernel` apply them). Output matches clang on the C
equivalent for all three attributes and tracks the clause value (`(4,4)` → `"4,4"`, `(8,8)` →
`"8,8"`). Four tests, each confirmed to fail without the patch; flang lit and MLIR OpenMP/Target
suites clean before and after. The PR will be posted once the spelling is settled.

Two notes for whoever takes it: the attribute name must be a `std::string` rather than a
`parser::Name` or name resolution fails; and `OpenMP.cpp` carries a second allow-list (a
`TODO(... "clause is not implemented yet")` guard for block constructs) that must also be updated or
`!$omp target teams ompx_attribute(...)` aborts the compiler.

## Reproducer

`ompx_attribute.f90` — a `target teams distribute parallel do` with
`ompx_attribute(amdgpu_waves_per_eu(4,4))`.

```
flang -fopenmp --offload-arch=gfx90a -O3 ompx_attribute.f90 -o /dev/null   # parse error
```

## Workaround

None. `!DIR$ AMDGPU_WAVES_PER_EU n` gives `warning: Unrecognized compiler directive was ignored`,
`thread_limit(64..1024)` has no effect on register budget or occupancy, and no `-mllvm` or driver
option exists.

## Found in

[MFC](https://github.com/MFlowCode/MFC) — no way to pin waves-per-EU on register-heavy offload
kernels from Fortran, which is exactly where occupancy tuning matters on AMD GPUs.
