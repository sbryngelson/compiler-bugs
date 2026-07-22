# runtimes/cmake: Fortran intrinsic-module probe ignores the target triple → wrongly enables RUNTIMES_FORTRAN_MODULES for GPU targets

Build-system (CMake configure-time) bug in `runtimes/cmake/config-Fortran.cmake`. Surfaces on any
runtimes build configured for a GPU triple without flang-rt in its runtime list.

**Status: FIX POSTED.** Reported: [llvm/llvm-project#211134](https://github.com/llvm/llvm-project/issues/211134).
Fix: [llvm/llvm-project#211137](https://github.com/llvm/llvm-project/pull/211137).

## Tracking

| Where | Link / ID |
|-------|-----------|
| llvm/llvm-project | [#211134](https://github.com/llvm/llvm-project/issues/211134) — open |
| Fix PR | [#211137](https://github.com/llvm/llvm-project/pull/211137) — probe the target triple in both branches |
| Related | [openmp/module GPU-triple regex #211135](https://github.com/llvm/llvm-project/issues/211135) (`../openmp-module-gpu-triple/`) |
| Source | [MFC](https://github.com/MFlowCode/MFC) |

## Bug

`check_fortran_builtins_available()` decides whether the toolchain provides Fortran intrinsic
modules, but neither of its two probes passes the target triple:

- the `-print-file-name=iso_c_binding.mod` query runs the driver with **no** `--target`, and
- the `check_fortran_source_compiles()` fallback uses `try_compile()`, which does **not** inherit
  `CMAKE_Fortran_COMPILER_TARGET`.

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
both probes using `CMAKE_Fortran_COMPILE_OPTIONS_TARGET` rather than a hard-coded `--target=`, since
that variable is `--target=` for Flang and **empty** for GNU. Hard-coding `--target=` regresses
gfortran, which rejects the option outright and would silently lose Fortran modules for users who
have them today. With the fix the existing graceful-degradation path is reached and modules are
correctly disabled for the GPU triple.

Verified across four configs: gfortran/flang host builds unchanged (modules ON); flang for
`amdgcn-amd-amdhsa` and `amdgpu-amd-amdhsa` correctly OFF; amdgcn with unpatched `openmp` fails as
described, patched builds clean and produces `libompdevice.a` with no workaround; and the
`openmp;flang-rt` (`FlangOffload.cmake`) recipe still builds `omp_lib.mod` for the GPU triple, so
intentional GPU module support is preserved. No test — `runtimes/`/`openmp/` have no
CMake-configuration test infrastructure and this is configure-time logic with no lit surface.

## Found in

[MFC](https://github.com/MFlowCode/MFC) offload toolchain builds on AMD GPU systems.
