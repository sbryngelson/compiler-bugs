# ROCm 7.2.0: hipfort advertises a `hipfft` component but does not ship its targets file

**Packaging defect.** `hipfort-config.cmake` lists `hipfft` among its supported components and
then unconditionally `include()`s `hipfort-hipfft-targets.cmake`, which is not installed. Any
`find_package(hipfort ... hipfft ...)` therefore fails hard at configure time.

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

`hipfft` is the **only** advertised component whose targets file is absent:

| component | `hipfort-<comp>-targets.cmake` |
| --- | --- |
| rocblas, rocfft, rocrand, rocsolver, rocsparse | present |
| hipblas, hiprand, hipsolver, hipsparse | present |
| **hipfft** | **MISSING** |

## 4. Reproduce

```bash
ls /opt/rocm-7.2.0/lib/cmake/hipfort/hipfort-hipfft-targets.cmake   # No such file
cat > t.cmake <<'X'
find_package(hipfort REQUIRED COMPONENTS hipfft)
X
cmake -P t.cmake   # include could not find requested file
```

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
