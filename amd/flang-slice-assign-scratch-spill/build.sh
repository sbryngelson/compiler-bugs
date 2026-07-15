#!/bin/bash
# Build the WENO-shaped slice-assignment reproducer and show the scratch spill.
# Same flags MFC uses on Frontier (MI250X, gfx90a). `amdflang` must be on PATH.
#
# Variants (-D):
#   (none)      full model; central path reconstructs directly (no array-slice copy)
#   SLICE       central path uses a whole-array slice copy  omega(0:ns) = d_cbL(:)   <-- the bug
#   ONE_SCHEME  drops the wenoz/mapped weight branches (lighter kernel)
#   CONST_NS    ns is a compile-time PARAMETER (what --case-optimization bakes in)
set -e
cd "$(dirname "$0")"

module load PrgEnv-amd amd rocm 2>/dev/null || true
FC=${FC:-$(which amdflang 2>/dev/null || which flang)}
echo "compiler: $FC"; "$FC" --version 2>&1 | head -1; echo

CFLAGS="-cpp -fopenmp --offload-arch=gfx90a -O3"

for spec in NONE: SLICE:-DSLICE ONE_SCHEME:-DONE_SCHEME CONST_NS:-DCONST_NS ; do
    tag="${spec%%:*}"; def="${spec#*:}"
    if "$FC" $CFLAGS $def weno_slice.f90 -o "r_$tag" 2>build_err.log; then
        sz=$(llvm-objcopy --dump-section=.llvm.offloading=/dev/stdout "r_$tag" 2>/dev/null | wc -c)
        printf "  built r_%-11s (%s)   embedded GPU code object: %8s bytes\n" "$tag" "${def:-baseline}" "$sz"
    else
        printf "  r_%-11s FAILED: %s\n" "$tag" "$(grep -m1 -iE 'error|undefined' build_err.log | cut -c1-60)"
    fi
done

echo
echo "Run each with the kernel trace to see per-kernel scratch/occupancy:"
echo "  N=4000 OMP_TARGET_OFFLOAD=MANDATORY LIBOMPTARGET_KERNEL_TRACE=1 ./r_SLICE"
echo "  -> the 'sweep' kernel (__QQmain_l*): SLICE spills ~20 KB scratch on AFAR 23.1.0,"
echo "     0 B on 23.2.0+. NONE never spills. (fixed in the 23.2.0 drop.)"
