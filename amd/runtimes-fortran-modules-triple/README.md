# runtimes/cmake: Fortran intrinsic-module probe ignores the target triple → wrongly enables RUNTIMES_FORTRAN_MODULES for GPU targets

Build-system (CMake configure-time) bug in `runtimes/cmake/config-Fortran.cmake`. Surfaces on any
runtimes build configured for a GPU triple without flang-rt in its runtime list.

**Status (2026-07-23): FIX POSTED, in review.** Reported:
[llvm/llvm-project#211134](https://github.com/llvm/llvm-project/issues/211134).
Fix: [llvm/llvm-project#211137](https://github.com/llvm/llvm-project/pull/211137).

@ldionne asked whether `runtimes/cmake/config-Fortran.cmake` can be moved out of `runtimes/cmake`,
which is meant for CMake shared across runtimes. That is about the file's location, not this fix —
the file was placed there by @Meinersbur in
[#171610](https://github.com/llvm/llvm-project/pull/171610). Offered to do the move as a separate PR.

## Tracking

| Where | Link / ID |
|-------|-----------|
| llvm/llvm-project | [#211134](https://github.com/llvm/llvm-project/issues/211134) — open |
| Fix PR | [#211137](https://github.com/llvm/llvm-project/pull/211137) — probe the target triple; route CMake < 3.28 to `execute_process` |
| Related | [openmp/module GPU-triple regex #211135](https://github.com/llvm/llvm-project/issues/211135) (`../openmp-module-gpu-triple/`) |
| Source | [MFC](https://github.com/MFlowCode/MFC) |

## Bug

`check_fortran_builtins_available()` decides whether the toolchain provides Fortran intrinsic
modules, but neither of its two probes passes the target triple:

- the `-print-file-name=iso_c_binding.mod` query runs the driver with **no** `--target`, and
- the `check_fortran_source_compiles()` fallback uses `try_compile()`, which only passes
  `CMAKE_Fortran_COMPILER_TARGET` from CMake **3.28** on.

Flang's intrinsic modules are per-target, built by flang-rt for each target. When a runtime is
configured for a GPU target that does not have flang-rt in its runtime list, both probes test the
host, succeed, and `RUNTIMES_ENABLE_FORTRAN` / `RUNTIMES_FORTRAN_MODULES` are enabled for a target
that cannot support them. `LIBOMP_FORTRAN_MODULES` inherits that at `openmp/CMakeLists.txt:117`, and
the failure surfaces ~180 diagnostics later compiling `omp_lib.F90` for the GPU triple:

```
FAILED: openmp/module/CMakeFiles/libomp-mod.dir/omp_lib.F90.o
omp_lib.F90-pp.f90:2:8: error: Cannot parse module file for module 'iso_c_binding':
                               Source file 'iso_c_binding.mod' was not found
omp_lib.F90-pp.f90:4:50: error: Must be a constant value
omp_lib.F90-pp.f90:797:42: error: A BIND(C) VALUE dummy argument must have an interoperable type
[~183 more]
```

All of which stem from the first error, since `omp_lib.F90` derives its kinds from `iso_c_binding`.
Directly:

```
$ flang -print-file-name=iso_c_binding.mod
.../finclude/flang/x86_64-unknown-linux-gnu/iso_c_binding.mod     # host, exists
$ flang --target=amdgcn-amd-amdhsa -print-file-name=iso_c_binding.mod
iso_c_binding.mod                                                 # not found
```

A graceful-degradation path already exists (`"Fortran support disabled: Not passing smoke check"`,
`config-Fortran.cmake:187`); it is simply never reached.

## Scope

Building `omp_lib.mod` for a GPU triple is intentional (`openmp/module/CMakeLists.txt:29-33` adds
`-nogpulib -flto` for those triples), and the configuration that hits this is not the blessed one:
`openmp/docs/Building.md:198` directs Fortran-offload users to
`offload/cmake/caches/FlangOffload.cmake`, which includes flang-rt per GPU target and works. So this
is a plausible misconfiguration failing *confusingly* instead of degrading cleanly — not "flang plus
OpenMP offload is unbuildable".

## Reproducer

`probe.sh` shows the divergence without a full LLVM build:

```
./probe.sh    # host query resolves a real .mod; --target=amdgcn query returns the bare name
```

## Fix

[llvm/llvm-project#211137](https://github.com/llvm/llvm-project/pull/211137) passes the triple to
the `-print-file-name` probe using `CMAKE_Fortran_COMPILE_OPTIONS_TARGET` rather than a hard-coded
`--target=`, since that variable is `--target=` for Flang and **empty** for GNU. Hard-coding
`--target=` regresses gfortran, which rejects the option outright and would silently lose Fortran
modules for users who have them today. With the fix the existing graceful-degradation path is
reached and modules are correctly disabled for the GPU triple.

### v2: the `try_compile` side cannot be fixed from here (2026-07-23)

The first revision also appended the flag to `CMAKE_REQUIRED_FLAGS` so it reached `try_compile()`.
That worked, but @Meinersbur rejected the approach and gave the reason the manual
`set(CMAKE_Fortran_COMPILE_OPTIONS_TARGET "--target=")` does not reach `try_compile()` on its own:

> `CMAKE_Fortran_COMPILE_OPTIONS_TARGET` is set at a different scope when CMake does it in
> `CMakeFortranCompiler.cmake` vs. us doing it manually in directory scope. `try_compile` seems to
> only consider the former global scope.

So the variable cannot be overridden the way CMake sets it, and patching around that at the
`CMAKE_REQUIRED_FLAGS` layer would also mean `--target=` is passed twice on CMake 3.28+, where CMake
already passes it. v2 instead routes **CMake < 3.28 through the `execute_process` probe**, extending
the pre-3.24 workaround, and drops the `try_compile` hunk entirely:

```cmake
if (CMAKE_Fortran_COMPILER_ID STREQUAL "LLVMFlang" AND
    (CMAKE_Fortran_COMPILER_FORCED OR CMAKE_VERSION VERSION_LESS "3.28"))
```

Below 3.24 the branch is reached via `CMAKE_Fortran_COMPILER_FORCED` (set by
`CMAKE_FORCE_Fortran_COMPILER`); 3.24–3.27 via the version test; 3.28+ falls through to
`try_compile`, where CMake supplies the triple itself. gfortran is unaffected at any version: it is
not `LLVMFlang`, so it always takes `try_compile`, where `CMAKE_Fortran_COMPILE_OPTIONS_TARGET` is
empty anyway — which was @Meinersbur's original point.

Measured on a real `runtimes` configure (`CMAKE_Fortran_COMPILER_TARGET=amdgcn-amd-amdhsa`,
`LLVM_ENABLE_RUNTIMES=openmp`; correct answer is "unavailable"):

| CMake | main | PR v2 | branch taken |
|---|---|---|---|
| 3.25.2 | `1` wrong | `FALSE` correct | execute_process |
| 3.26.4 | — | `FALSE` correct | execute_process |
| 3.27.9 | `1` wrong | `FALSE` correct | execute_process |
| 3.28.4 / 3.29.6 / 3.30.5 / 3.31.6 | empty correct | empty correct | try_compile |

Host target still reports available on 3.25.2, 3.27.9 and 3.31.6. On 3.31.6 `--target=` appears
exactly once per `try_compile` command line, confirmed from `CMakeConfigureLog.yaml`.

The `execute_process` hunk is what fixes the **forced** path, which no CMake version test reaches:
with `-DCMAKE_Fortran_COMPILER_FORCED=ON` on 3.31.6, main reports the module available (host) and
the patch reports it unavailable. That is a simulation of the `CMAKE_FORCE_Fortran_COMPILER` case —
no 3.20–3.23 binary was available here to test it directly.

`-print-file-name` is a sound probe per target: it returns an existing absolute path for the host and
the bare name `iso_c_binding.mod` for `amdgcn-amd-amdhsa` and `nvptx64-nvidia-cuda`, so the
`if (EXISTS ...)` test gives the right answer without compiling anything.

Verified across four configs: gfortran/flang host builds unchanged (modules ON); flang for
`amdgcn-amd-amdhsa` and `amdgpu-amd-amdhsa` correctly OFF; amdgcn with unpatched `openmp` fails as
described, patched builds clean and produces `libompdevice.a` with no workaround; and the
`openmp;flang-rt` (`FlangOffload.cmake`) recipe still builds `omp_lib.mod` for the GPU triple, so
intentional GPU module support is preserved. No test — `runtimes/`/`openmp/` have no
CMake-configuration test infrastructure and this is configure-time logic with no lit surface.

## Found in

[MFC](https://github.com/MFlowCode/MFC) offload toolchain builds on AMD GPU systems.

## Review state (2026-07-23)

Reworked to v2 per @Meinersbur (see "v2" above) and pushed; awaiting his response. @ldionne
separately asked whether `config-Fortran.cmake` could move out of `runtimes/cmake` altogether, since
libc++ is notified on all traffic there. That is orthogonal to this fix and @Meinersbur's call.

## Applicability: CMake < 3.28 only (2026-07-22 re-audit)

| CMake | unpatched | patched |
|---|---|---|
| 3.25.2 | `Fortran support enabled using compiler's own modules` — the bug | `disabled: Not passing smoke check` |
| 3.31.6 | `disabled: Not passing smoke check` — already correct | same |

CMake 3.28+ passes `--target=` to Flang itself, so the `try_compile()` probe already tests the right
target. The bug is confined to the 3.24–3.27 range (below 3.24 the force-compiler path is used).
`runtimes` requires CMake 3.20, so that range is real, but the original report did not state the
limit and all the original testing was on 3.25.2.

The full seven-version sweep is in the "v2" section above and supersedes this two-row table.

A `CMakeTestFortranCompiler` failure seen on CMake 3.31 was **an artifact of configuring
`runtimes/` standalone** with `CMAKE_Fortran_COMPILER_TARGET` set by hand. The recommended
`offload/cmake/caches/FlangOffload.cmake` configures cleanly from the top level on both 3.25.2 and
3.31.6, so it is not a real defect. Recorded here so it is not re-derived.

