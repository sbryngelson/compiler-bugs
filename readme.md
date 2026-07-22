## Compiler Bug Reproducers

Minimal reproducers for Fortran compiler bugs encountered in HPC workloads on OLCF Frontier.

---

### `cce/` — Cray CCE 15.0.1 Fortran + OpenACC

Module-scope variables and nested allocatable derived types under `!$acc declare` (link/create).
12 reproducers + archived cases. Bug reports: **OLCFDEV-1416, CAST-31898**. See `cce/README.md`.

---

### `cce/defaultmap-firstprivate/` — CCE-19: `defaultmap(firstprivate:scalar)` doesn't firstprivate

On a register-heavy `target teams distribute parallel do simd` offload kernel, per-cell scalars left
off `private()` that rely on `defaultmap(firstprivate:scalar)` come out as `NaN` — yet listing the
same scalars in an explicit `private()` **or** `firstprivate()` clause is correct. Since defaultmap
is *defined* to make them firstprivate, the divergence from an explicit firstprivate of the identical
set is a compiler bug, not a semantic. Independent of `simd` and optimization level; needs enough
omitted scalars to spill (which is how it hid in MFC until an added `firstprivate` raised register
pressure). CCE 19.0.0. See `cce/defaultmap-firstprivate/README.md`.

---

### `amd/no-loop-array-ops/` — amdflang: wrong results with `-fopenmp-target-fast` + array expressions — **FIXED**

Array constructor and whole-array slice ops inside `!$omp target` kernels produce wrong results
when `-fopenmp-target-fast` and both oversubscription flags are present.
Root cause: `no_loop` exec mode hoists `omp_get_num_threads()` before the parallel region is set up,
yielding stride=1 instead of 32 — threads K+31..N-1 are never assigned.
Fixed upstream: [ROCm/llvm-project#3058](https://github.com/ROCm/llvm-project/pull/3058) (merged into
`amd-staging` 2026-06-25, re-landing [#2602](https://github.com/ROCm/llvm-project/pull/2602)).
Reported in [ROCm/llvm-project#2601](https://github.com/ROCm/llvm-project/issues/2601) and
[llvm/llvm-project#198621](https://github.com/llvm/llvm-project/issues/198621) (upstream, still open).

---

### `amd/declare-target-static-tu/` — amdflang: static `declare target` variable stale across translation units — **NOT A BUG**

A static (non-allocatable) `!$omp declare target` module variable appeared not to be unified
across TUs on the device. Diagnosed by AMD as expected OpenMP semantics: a `declare target` SAVE
variable has an infinite device reference count, so `map(to:)` / `target enter data map(to:)`
no-ops on the presence check — it never re-copies. `target update to` (or `map(always,to:)`) is
the correct way to push a new value. Confirmed and closed as working-as-intended; CCE/nvfortran
happened to copy on `map(to:)` here too, which is what made the AMD behavior look like a bug.
Reports (closed, not planned): [ROCm/llvm-project#2890](https://github.com/ROCm/llvm-project/issues/2890),
[llvm/llvm-project#203711](https://github.com/llvm/llvm-project/issues/203711).

---

### `amd/declare-target-roulette/` — amdflang: identical `declare target` arrays disagree in one kernel — **NOT A BUG**

A sharper form of the same case above: two *identical* static `!$omp declare target` arrays,
both host-set to 2, read by the *same* kernel, return *different* values (`0` vs `2`) — because
one was pushed with `enter data map(to:)` (no-op due to infinite refcount) and the other with
`update to` (always copies). Same root cause and same resolution as
`declare-target-static-tu/` — use `target update to` / `map(always,to:)` for `declare target`
SAVE variables. Same reports
([ROCm/llvm-project#2890](https://github.com/ROCm/llvm-project/issues/2890),
[llvm/llvm-project#203711](https://github.com/llvm/llvm-project/issues/203711)).

---

### `amd/flang-firstprivate-array-occupancy/` — amdflang: `firstprivate` of a small array spills to scratch — **OPEN**

A `firstprivate` clause on a small fixed-size integer array (8 bytes) on a register-heavy
`target teams distribute parallel do` kernel spills ~20-35 KB/work-item to scratch, pins AGPRs at
the hardware maximum, and drops occupancy to one wave per SIMD — a 30-50x slowdown. The same two
integers passed as scalars, or as a plain `private` array seeded from those scalars, cost nothing.
Isolation (constant-indexed firstprivate array still spills; dynamically-indexed *private* array
does not) shows the trigger is `firstprivate` of an array, not the indexing. The copy-in is lowered
through the Fortran array-assignment runtime (`_FortranAAssign`) rather than a value copy:
undefined device symbol on ROCm 7.2.0, a scratch-spilling blob on afar 23.1.0/23.2.0 and the
2026-06-12 ROCm nightly. AMD's first attempted fix
([llvm/llvm-project#204466](https://github.com/llvm/llvm-project/pull/204466)) only gates
*implicit* firstprivate promotion and was verified **not** to fix this *explicit*
`firstprivate(array)` case; AMD is now routing it to their internal team.
Bug reports (open): [ROCm/llvm-project#2909](https://github.com/ROCm/llvm-project/issues/2909),
[llvm/llvm-project#203890](https://github.com/llvm/llvm-project/issues/203890).

---

### `amd/flang-slice-assign-scratch-spill/` — amdflang: whole-array slice assignment into a private array spills to scratch — **FIXED in AFAR 23.2.0**

Sibling of the firstprivate case above, same `_FortranAAssign` device-lowering class but the
*slice-assignment* path. A runtime-bounded whole-array slice assignment `omega(0:ns) = d_cbL(:)`
inside a register-heavy WENO `target teams distribute parallel do` kernel spills ~20 KB/work-item to
scratch and craters occupancy — **only on the AFAR 23.1.0 drop**. flang 22 (ROCm 7.2.0) won't even
link it (`undefined symbol: _FortranAAssign`); 23.1.0 inlines it as a scratch-spilling blob; the
23.2.0 drop (04/18/26) lowers it cleanly (0 B). So the slice path was fixed in 23.2.0, while the
firstprivate path (#2909) was not. Bites MFC only because Frontier's CI is pinned to 23.1.0, the
interim implemented-but-spilling drop. Workaround (and the MFC fix, [MFlowCode/MFC#1628](https://github.com/MFlowCode/MFC/pull/1628)):
reconstruct directly from the source array or copy element-by-element with an explicit indexed loop —
byte-identical, off the `_FortranAAssign` path. `--case-optimization` (compile-time stencil count)
independently removes the register pressure.

---

### `amd/derived-type-mapper-hang/` — amdflang: per-component default mapper for a flat derived type hangs the offload runtime — **FIX POSTED** ([llvm#209645](https://github.com/llvm/llvm-project/pull/209645))

flang 23 emits a per-component `._omp_default_mapper` for a *flat* derived type (fixed-size
components only, no allocatable/pointer members — trivially bit-copyable). A `target` kernel mapping
an array of that type invokes the mapper per element at runtime — `N × #components` component pushes
through `targetDataBegin`/`targetDataMapper` — a multi-minute host busy-loop (99% CPU, GPU idle).
amdflang 22 (rocm-7.2.0) does not emit the mapper. Codegen is target-arch-independent (mapper
emitted for gfx90a/gfx942/gfx950); runtime-reproduced on MI250X and MI210. Root cause: `OpenMP.cpp`
gated mapper synthesis on the captured variable being allocatable instead of consulting
`requiresImplicitDefaultDeclareMapper()`; `perf` confirms the runtime cost is linear in
`N × #components × #launches` (no runtime bug — the fix belongs in codegen). Fix: llvm#209645.
Workaround: `defaultmap(present:allocatable)` on the kernel (no map entry → no mapper). Found in MFC's
block-structured AMR + immersed-boundary path.
Bug report (open): [ROCm/llvm-project#3385](https://github.com/ROCm/llvm-project/issues/3385).

---

### `amd/flang-array-coor-nuw-poison/` — amdflang: false `nuw` flags on box-based array addressing → wrong answers — **FIXED UPSTREAM, AWAITING AFAR DROP**

flang stamps unsigned-no-wrap flags (`nusw nuw` on `array_coor` GEPs, `nuw` on the index add/mul)
unconditionally, including for descriptor arrays whose offsets are legitimately negative — negative
lower bounds (`-buff_size`) and negative-stride sections (`s_cb(i+4:i-3:-1)`). The claims are false,
so the IR carries poison and any correct optimizer may miscompile; in MFC the WENO7 coefficient
tables come out subtly wrong and the golden tests fail by **abs 2.1e-4** at shock fronts (a wrong
answer, not a crash). Host codegen, so it hits GPU builds only because they compile the host with
amdflang. Introduced by [llvm/llvm-project#184573](https://github.com/llvm/llvm-project/pull/184573)
(2026-03-13) — one day after the 23.1.0 drop was cut, which is why 23.1.0 is clean and 23.2.0/23.2.1
are not. Proven by a flag census (0 vs 491+715+1136 wrap flags on the same TU) plus a causality
matrix: 23.1.0's IR through 23.2.0's `opt` is correct, 23.2.0's IR through *either* version's `opt`
is wrong, and stripping the `nuw` flags alone fixes it. A naive `-opt-bisect-limit` bisect blames
`loop-unroll-full`, which is innocent — it is just the first pass to exploit the poison. No flag
disables the emission (`-fwrapv` kills only `nsw`). Fixed upstream in
[llvm/llvm-project#198014](https://github.com/llvm/llvm-project/pull/198014) (2026-05-20, fixes
[llvm#197393](https://github.com/llvm/llvm-project/issues/197393)), which every 23.2.x drop predates —
so the ask is a drop based on ≥ 05/20 or a cherry-pick. Workaround (and the MFC fix,
[MFlowCode/MFC#1660](https://github.com/MFlowCode/MFC/pull/1660)): write the reversed slices
element-wise — value-identical, and the offsets are then non-negative. Per-pattern only: the false
flags are in every TU of a 23.2.x build, so keep Frontier pinned to 23.1.0.
Bug report (open): [ROCm/llvm-project#3471](https://github.com/ROCm/llvm-project/issues/3471).

---

### `amd/openmp-outlined-not-inlined/` — flang/OpenMPIRBuilder: device-outlined target regions left un-inlined — **FIX POSTED** ([llvm#211136](https://github.com/llvm/llvm-project/pull/211136))

flang lowers an OpenMP `target teams distribute parallel do` body into a separate AMDGPU device
function, and the inliner declines it (`cost=1280 > threshold=495`), so it is register-allocated
without the enclosing kernel's occupancy target: 212 VGPR / 48 B scratch / occ 2, vs clang's inlined
80 / 0 / 6 on the identical algorithm. Root cause is the by-pointer `private()` struct that
`OpenMPIRBuilder::applyWorkshareLoopTarget` (taken unconditionally on device) passes to
`__kmpc_distribute_for_static_loop_4u`, which inflates the body past the fixed threshold. Fix marks
outlined regions `alwaysinline` on device → 94 / 0 / 5 and up to 1.32x on a WENO5+HLLC kernel.
Reported [llvm#211132](https://github.com/llvm/llvm-project/issues/211132), fix
[llvm#211136](https://github.com/llvm/llvm-project/pull/211136). Fortran + C control reproducers.

---

### `amd/flang-ompx-attribute/` — flang/OpenMP: no `ompx_attribute` clause in Fortran offload — **RFC** ([llvm#211133](https://github.com/llvm/llvm-project/issues/211133))

clang accepts `ompx_attribute` and lowers it to LLVM function attributes; flang rejects it at parse
time, so Fortran OpenMP offload cannot set per-kernel launch bounds / occupancy hints
(`amdgpu-waves-per-eu`) at all. Two gaps at `119b31fd3`: `OMPC_OMPX_Attribute` has a `clangClass`
but no `flangClass` (→ `EMPTY_CLASS`, no parser rule), and the clause is absent from every
Fortran-spelled directive's allow-list. Filed as an RFC (not a PR) because the Fortran spelling is
undecided — clang's `__attribute__`/`[[...]]` grammar has no Fortran analogue. A working 881-line
proof-of-concept exists for the bare-name form. No workaround.
[llvm#211133](https://github.com/llvm/llvm-project/issues/211133). Reproducer: `ompx_attribute.f90`.

---

### `amd/runtimes-fortran-modules-triple/` — runtimes/cmake: Fortran intrinsic-module probe ignores the target triple — **FIX POSTED** ([llvm#211137](https://github.com/llvm/llvm-project/pull/211137))

`check_fortran_builtins_available()` probes for intrinsic modules without passing the triple (the
`-print-file-name` query has no `--target`; the `try_compile()` fallback doesn't inherit
`CMAKE_Fortran_COMPILER_TARGET`). Flang's modules are per-target, so a runtime configured for a GPU
triple without flang-rt tests the *host*, succeeds, enables `RUNTIMES_FORTRAN_MODULES`, and fails
~180 diagnostics later compiling `omp_lib.F90` for the GPU triple — instead of hitting the existing
graceful-degradation path. Fix passes the triple via `CMAKE_Fortran_COMPILE_OPTIONS_TARGET`
(`--target=` for Flang, empty for GNU, so gfortran is not regressed). Plausible misconfiguration
failing confusingly, not "offload is unbuildable". Reported
[llvm#211134](https://github.com/llvm/llvm-project/issues/211134), fix
[llvm#211137](https://github.com/llvm/llvm-project/pull/211137). `probe.sh` shows the divergence.

---

### `amd/openmp-module-gpu-triple/` — openmp/module cmake: GPU-triple regex misses `amdgpu-amd-amdhsa` — **FIX POSTED** ([llvm#211138](https://github.com/llvm/llvm-project/pull/211138))

`openmp/module/CMakeLists.txt:29` gates `-nogpulib -flto` on `"^amdgcn|^nvptx"`, but all four
offload cache files use the triple `amdgpu-amd-amdhsa`, which `^amdgcn` doesn't match — so the flags
are silently dropped from `libomp-mod` in the configs upstream recommends. (`^amdgcn` isn't dead
code: `Triple::normalize` preserves that spelling too.) Fix computes the test once as
`LIBOMP_TARGET_IS_GPU` and reuses it at both sites (the conditions differ, and Fortran means
`CMAKE_Fortran_COMPILER_TARGET` also matters), rather than duplicating a widened regex. ~5 other
`amdgcn`-only sites noted for follow-up. Reported
[llvm#211135](https://github.com/llvm/llvm-project/issues/211135), fix
[llvm#211138](https://github.com/llvm/llvm-project/pull/211138).

---

### `intel/` — ifx: Intel GPU (PVC) OpenMP target offload bugs

Four reproducers for `ifx` on Intel PVC (Aurora). See `intel/README.md` for details.
