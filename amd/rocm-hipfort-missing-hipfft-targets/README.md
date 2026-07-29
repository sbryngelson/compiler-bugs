# ROCm 7.2.0: hipfort ships hipfft Fortran bindings but omits its CMake targets export

**Packaging inconsistency.** hipfort installs `hipfort_hipfft.mod` and lists `hipfft` among its
supported components, but does not install `hipfort-hipfft-targets.cmake` — which
`hipfort-config.cmake` then `include()`s unconditionally. Any
`find_package(hipfort ... hipfft ...)` fails hard at configure time.

**This is not a relocation.** hipfft itself is fully present in ROCm 7.2.0 — its own CMake
package at `lib/cmake/hipfft/`, `lib/libhipfft.so`, `include/hipfft/hipfft.h`, and the hipfort
Fortran module `include/hipfort/amdgcn/hipfort_hipfft.mod`. Only hipfort's own target export for
that component is absent, and hipfft is the **only** component for which the two disagree.

* **Reported by:** OLCF Frontier, project CFD154
* **Component:** ROCm 7.2.0, `hipfort` CMake package
* **Severity:** configure-time failure, loud — but the diagnostic points at the *consumer's*
  `find_package` line, not at the incomplete install, so it reads as a user error
* **Version tested:** `/opt/rocm-7.2.0` (`.info/version` = 7.2.0)

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | none filed |

## 1. Symptom

```
CMake Error at /opt/rocm-7.2.0/lib/cmake/hipfort/hipfort-config.cmake:49 (include):
  include could not find requested file:
    /opt/rocm-7.2.0/lib/cmake/hipfort/hipfort-hipfft-targets.cmake
Call Stack (most recent call first):
  cmake/MFCTargets.cmake:148 (find_package)
  CMakeLists.txt:158 (MFC_SETUP_TARGET)
```

## 2. The defect

`hipfort-config.cmake` declares the supported set:

```cmake
  rocblas rocfft rocrand rocsolver rocsparse
  hipblas hipfft hiprand hipsolver hipsparse)

include("${CMAKE_CURRENT_LIST_DIR}/hipfort-amdgcn-targets.cmake")
foreach(_comp ${hipfort_FIND_COMPONENTS})
  if (NOT _comp IN_LIST _hipfort_supported_components)
    ...
  endif()
  include("${CMAKE_CURRENT_LIST_DIR}/hipfort-${_comp}-targets.cmake")
  find_dependency(${_comp})
endforeach()
```

The `include()` is unconditional — a component that passes the supported-list check but has no
targets file is a hard error rather than a graceful "component not found".

## 3. What is actually installed

Every component ships **both** a Fortran module and a targets export — except `hipfft`, which
ships the module only:

| component | `hipfort_<c>.mod` | `hipfort-<c>-targets.cmake` |
| --- | --- | --- |
| hipblas, hiprand, hipsolver, hipsparse, rocblas, rocfft | yes | yes |
| **hipfft** | **yes** | **no** |

So the Fortran bindings are installed and presumably usable; only the CMake plumbing to consume
them via hipfort's component mechanism is missing.

## 4. Reproduce

```console
$ bash run.sh
=== 3. FAIL arm: find_package(hipfort COMPONENTS hipfft) ===
  include could not find requested file:
    /opt/rocm-7.2.0/lib/cmake/hipfort/hipfort-hipfft-targets.cmake
  rc=1  (non-zero = reproduced)
=== 4. CONTROL arm: same call with an installed component ===
  rc=0  (0 = control passes, so the package and this CMakeLists are fine)
```

`CMakeLists.txt` takes `-DCOMP=<component>`; the control arm differs only in that value, so a
passing control rules out the reproducer itself being at fault.

## 5. Expected

Either ship `hipfort-hipfft-targets.cmake`, or drop `hipfft` from
`_hipfort_supported_components`, or make the `include()` conditional
(`if (EXISTS ...)`) so an absent component reports `hipfort_FOUND False` with a
`hipfort_NOT_FOUND_MESSAGE` instead of aborting.

## 6. How it was found

MFC builds its own hipfort, so this is normally masked. It surfaces on any tree where MFC's
hipfort has not been built and CMake falls back to the system package — the fallback is not
usable on this ROCm. Relevant because MFC recently switched to deriving the hipfort tag from
`ROCM_PATH` (MFlowCode/MFC#1694) specifically to keep hipfort in step with the loaded ROCm
module.
