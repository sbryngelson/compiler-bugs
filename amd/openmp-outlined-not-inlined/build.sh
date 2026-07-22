#!/bin/bash
# Build the Fortran reproducer and the C control, printing per-kernel resource
# usage for each so the occupancy gap is visible without a compute node.
#
# The defect is a compile-time inliner decision, so `-Rpass-analysis` on a login
# node is enough to see it -- no GPU run required. Have `amdflang`/`amdclang`
# (or upstream `flang`/`clang`) on PATH.
set -e
cd "$(dirname "$0")"

module load PrgEnv-amd amd rocm 2>/dev/null || true
FC=${FC:-$(which amdflang 2>/dev/null || which flang)}
CC=${CC:-$(which amdclang 2>/dev/null || which clang)}
ARCH=${ARCH:-gfx90a}
echo "flang: $FC"; "$FC" --version 2>&1 | head -1
echo "clang: $CC"; "$CC" --version 2>&1 | head -1
echo

FLAGS="-fopenmp --offload-arch=$ARCH -O3 -Rpass-analysis=kernel-resource-usage"

echo "=== flang (outlined_region.f90) -- expect ~212 VGPR / 48 B scratch / occ 2 ==="
"$FC" $FLAGS outlined_region.f90 -o /dev/null

echo
echo "=== clang control (outlined_region.c) -- expect ~80 VGPR / 0 scratch / occ 6 ==="
"$CC" $FLAGS outlined_region.c -o /dev/null

echo
echo "The inliner miss itself (why the body is register-allocated separately):"
"$FC" -fopenmp --offload-arch=$ARCH -O3 outlined_region.f90 -o /dev/null \
    -Xoffload-linker -mllvm=-pass-remarks-missed=inline 2>&1 | grep -i "not inlined" || true
