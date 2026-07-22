# amdflang: per-component default mapper for a flat derived type → offload runtime hang

Target: gfx90a (MI250X, MI210). Compiler: amdflang 23.0.0git (therock-afar 23.2.0, ROCm 7.13).

**Status: FIXED, MERGED UPSTREAM.** Reported: [ROCm/llvm-project#3385](https://github.com/ROCm/llvm-project/issues/3385).
Upstream fix: [llvm/llvm-project#209645](https://github.com/llvm/llvm-project/pull/209645), merged
2026-07-22 as `255d0013789d`. Not yet in any AFAR/ROCm drop — the `defaultmap(present:allocatable)`
workaround below is still needed until a drop carries it.

## Bug

flang 23 emits a per-component `.omp_mapper.<type>_omp_default_mapper` for a **flat** derived type
(fixed-size scalar/array components only — no `allocatable`/`pointer` members, i.e. trivially
bit-copyable). A `target` kernel that maps an array of that type invokes the mapper per element at
runtime (`N × #components` component pushes: `targetDataBegin → targetDataMapper → targetDataBegin`,
cycling through present-table lookups / `SourceInfo` parsing / `free`). Over a large array × many
kernel launches this is a multi-minute host busy-loop (99% host CPU, GPU idle) — effectively a hang.

Regression: amdflang 22 (rocm-7.2.0) does **not** emit the mapper and runs fine. Introduced upstream
by [llvm/llvm-project#184382](https://github.com/llvm/llvm-project/pull/184382) ("Avoid implicit
default mapper on pointer captures"), which gated mapper synthesis on the captured variable being
allocatable rather than on the type needing one.

## Root cause (codegen, not runtime)

`flang/lib/Lower/OpenMP/OpenMP.cpp`, in `genTargetOp`, keyed the implicit-default-mapper decision on
whether the captured *variable* was allocatable:

```cpp
if (!isPointer && (hasDefaultMapper || isAllocatable)) {   // synthesizes a per-component mapper
```

`Fortran::lower::omp::requiresImplicitDefaultDeclareMapper(typeSpec)` already answers whether the
*type* needs a mapper (allocatable/pointer/nested-record components, or ISO-C interop), but this path
never consulted it — so a flat type got a mapper it doesn't need. The fix adds the predicate to the
gate; the flat allocatable then maps as descriptor + base-address + attach entries with no `mapper()`,
identical to the pointer path.

This is a codegen fix, not a libomptarget one. Profiling the hang (`perf` on the spinning process)
shows the runtime work is **linear** in `M = N × #components × #kernel_launches` — every op is O(1)
or O(log M) per component entry, there is no super-linear algorithm to fix in the runtime. Suppressing
the mapper collapses `M` to a single bulk map entry, which is where the cost has to be removed.

## Reproducer

`repro.f90` — flat 11-component derived type, 20000-element arrays, 500 kernel launches.

```
make        # builds hang + fix (needs -cpp for the -DFIX toggle)
make run
```

`hang` busy-loops (times out); `fix` (adds `defaultmap(present:allocatable)`) returns instantly.

## Signature

```
nm hang | grep -c omp_mapper   # 1  (per-component mapper emitted)
nm fix  | grep -c omp_mapper   # 0  (defaultmap → no map entry → no mapper)
```

`rocgdb -p <pid> -batch -ex 'bt'` on the spinning process (it cycles):

```
#0 malloc  (SourceInfo::initStr)
#1 targetDataBegin
#2 targetDataMapper
#3 targetDataBegin
#4 (anonymous namespace)::processDataBefore
#5 target → __tgt_target_kernel
```

`perf` self-time over the spinning process (all per-component-entry work, confirming the linear-cost
diagnosis):

```
38% llvm::DenseMap::lookupOrInsertIntoBucket   # mapping-state tables, per entry
34% targetDataEnd                              # mirror per-component walk on region EXIT too
 3% __memchr / SourceInfo::initStr             # per-entry ident-string parse + malloc
 2% MappingInfoTy::lookupMapping               # std::set, O(log M) per entry
```

## Scope

- **Target-arch-independent** (host codegen): `--offload-arch=gfx90a|gfx942|gfx950` all emit
  `mapper=1`. Only gfx90a runtime-tested (gfx90a-only AFAR drop).
- **Not node-specific**: reproduced on MI250X (`k004-001`) and MI210 (`k005-003`).
- **Optimization-independent**: mapper emitted at every level (no `-O`, `-O0`, `-O1`, `-O2`, `-O3`);
  `-O0` hangs identically — the defect is in the OpenMP lowering, not an optimization pass.

## Workaround

`defaultmap(present:allocatable)` on the kernel — the arrays are treated present with **no map
entry**, so flang emits/invokes no mapper. flang accepts only **one** `defaultmap` clause per
directive, so the multi-clause CCE form
(`defaultmap(tofrom:aggregate) defaultmap(present:allocatable) defaultmap(present:pointer)`) is
rejected.

## Fix

[llvm/llvm-project#209645](https://github.com/llvm/llvm-project/pull/209645) — gate the mapper on
`requiresImplicitDefaultDeclareMapper()` (3-line change in `OpenMP.cpp`, +tests). Pointer captures
and user/pre-existing declare mappers are unaffected. Built and tested on gfx90a: flat allocatable →
`nm | grep -c omp_mapper` = 0, no hang.

The `defaultmap(present:allocatable)` workaround above is already applied in MFC, so MFC does not
depend on the compiler fix landing.

## Found in

[MFC](https://github.com/mflowcode/mfc), block-structured AMR + immersed-boundary path — an
`allocatable` array of a flat ghost-point type swapped/restored on device each RK stage.
