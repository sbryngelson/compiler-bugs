#!/bin/bash
# ROCm 7.2.0: hipfort ships hipfft Fortran modules but not its CMake targets export.
set -u
ROCM=${ROCM_PATH:-/opt/rocm-7.2.0}

echo "=== 1. every component ships both .mod and targets -- except hipfft ==="
printf "  %-10s %-12s %s\n" component hipfort.mod hipfort-targets
for c in hipblas hipfft hiprand hipsolver hipsparse rocblas rocfft; do
  printf "  %-10s %-12s %s\n" "$c" \
    "$([ -f "$ROCM/include/hipfort/amdgcn/hipfort_$c.mod" ] && echo yes || echo no)" \
    "$([ -f "$ROCM/lib/cmake/hipfort/hipfort-$c-targets.cmake" ] && echo yes || echo no)"
done

echo
echo "=== 2. hipfft itself is fully present (this is NOT a relocation) ==="
ls -d "$ROCM/lib/cmake/hipfft" "$ROCM/lib/libhipfft.so" "$ROCM/include/hipfft/hipfft.h" 2>/dev/null

echo
echo "=== 3. FAIL arm: find_package(hipfort COMPONENTS hipfft) ==="
rm -rf _b; cmake -S . -B _b > _b.log 2>&1; rc=$?
grep -E "include could not find|hipfort-hipfft-targets" _b.log | head -3
echo "  rc=$rc  (non-zero = reproduced)"

echo
echo "=== 4. CONTROL arm: same call with an installed component ==="
rm -rf _c; cmake -S . -B _c -DCOMP=hipblas > _c.log 2>&1; rc=$?
echo "  rc=$rc  (0 = control passes, so the package and this CMakeLists are fine)"
