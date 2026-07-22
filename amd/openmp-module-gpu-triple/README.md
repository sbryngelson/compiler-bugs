# openmp/module cmake: GPU-triple regex misses `amdgpu-amd-amdhsa` → silently drops `-nogpulib -flto`

Build-system (CMake configure-time) bug in `openmp/module/CMakeLists.txt`. Bites every recommended
AMDGPU offload configuration, which uses the `amdgpu-amd-amdhsa` triple.

**Status (2026-07-22): FIXED — merged upstream.** Reported: [llvm/llvm-project#211135](https://github.com/llvm/llvm-project/issues/211135) (closed).
Fix: [llvm/llvm-project#211138](https://github.com/llvm/llvm-project/pull/211138) — **merged 2026-07-22**
(reviewed and approved by jhuber6).

## Tracking

| Where | Link / ID |
|-------|-----------|
| llvm/llvm-project | [#211135](https://github.com/llvm/llvm-project/issues/211135) — open (1 comment) |
| Fix PR | [#211138](https://github.com/llvm/llvm-project/pull/211138) — compute the test once, use at both sites |
| Related | [runtimes Fortran-module probe #211134](https://github.com/llvm/llvm-project/issues/211134) (`../runtimes-fortran-modules-triple/`) |
| Source | [MFC](https://github.com/MFlowCode/MFC) |

## Bug

`openmp/module/CMakeLists.txt:29` gates the GPU-only Fortran compile options on

```cmake
if ("${LLVM_DEFAULT_TARGET_TRIPLE}" MATCHES "^amdgcn|^nvptx")
  target_compile_options(libomp-mod PRIVATE
    $<$<COMPILE_LANGUAGE:Fortran>:-nogpulib -flto>)
endif ()
```

while `openmp/CMakeLists.txt:176-177`, which selects host-vs-device layout for the *same* build,
tests `"^amdgpu|^amdgcn|^nvptx|^spirv64"` against both `LLVM_DEFAULT_TARGET_TRIPLE` and
`CMAKE_CXX_COMPILER_TARGET`.

All four offload cache files (`offload/cmake/caches/{Offload,FlangOffload,AMDGPUBot,AMDGPULibcBot}.cmake`)
use the triple `amdgpu-amd-amdhsa`, which `^amdgcn` does not match. So in the configurations upstream
itself recommends for AMDGPU offload, `-nogpulib -flto` are silently *not* applied to `libomp-mod`.

`amdgcn` is the legacy arch spelling but `Triple::normalize` preserves it
(`clang --target=amdgcn-amd-amdhsa -print-target-triple` returns `amdgcn-amd-amdhsa`), so both
spellings genuinely reach CMake and the existing `^amdgcn` clause is not dead code. Only
`amdgpu-amd-amdhsa` is missed.

## Fix

[llvm/llvm-project#211138](https://github.com/llvm/llvm-project/pull/211138) computes the test once
as `LIBOMP_TARGET_IS_GPU` in `openmp/CMakeLists.txt` and uses it at both sites, rather than
duplicating a widened regex. Two reasons: the conditions *differ*, not just the patterns — copying
the regex alone leaves a build that sets `CMAKE_CXX_COMPILER_TARGET` without
`LLVM_DEFAULT_TARGET_TRIPLE` still taking the device path in `openmp/` while `libomp-mod` misses the
flags; and `libomp-mod` compiles Fortran, so `CMAKE_Fortran_COMPILER_TARGET` is the variable that
actually matters and neither site consulted it before.

Evaluated with CMake's regex engine (1 = matched):

| triple | before | after |
|---|---|---|
| `amdgpu-amd-amdhsa`       | 0 | 1 |
| `amdgcn-amd-amdhsa`       | 1 | 1 |
| `nvptx64-nvidia-cuda`     | 1 | 1 |
| `spirv64-amd-amdhsa`      | 0 | 1 |
| `x86_64-unknown-linux-gnu`| 0 | 0 |

`^spirv64` only brings `module/` in line with `openmp/CMakeLists.txt:176`, which already routes
spirv64 to `device/`. Host builds unaffected. No test — configure-time logic, no test mechanism in
`openmp/`.

## Follow-up (out of scope for the PR)

Roughly five other sites carry the same `amdgcn`-only pattern and are left for a follow-up:

- `offload/CMakeLists.txt:30`
- `flang-rt/CMakeLists.txt:126`
- `flang-rt/lib/runtime/CMakeLists.txt:317`
- `flang-rt/cmake/modules/AddFlangRT.cmake:298`
- `cmake/Modules/GetToolchainDirs.cmake:118` — governs the `finclude/flang/<triple>/` module path

## Found in

[MFC](https://github.com/MFlowCode/MFC) offload toolchain builds on AMD GPU systems.
