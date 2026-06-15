#!/bin/bash
# Build the five variants of the firstprivate-array occupancy reproducer.
# Same flags the MFC build uses on Frontier (MI250X, gfx90a).
#
# On Frontier the compiler env loads on a login node; the binaries run on a
# compute node (see run.sbatch). Elsewhere, just have `amdflang` on PATH.
set -e
cd "$(dirname "$0")"

module load PrgEnv-amd amd rocm 2>/dev/null || true
FC=${FC:-$(which amdflang 2>/dev/null || which flang)}
echo "compiler: $FC"; "$FC" --version 2>&1 | head -1

CFLAGS="-fopenmp --offload-arch=gfx90a -O3 \
  -fopenmp-assume-threads-oversubscription -fopenmp-assume-teams-oversubscription"
LFLAGS="-fopenmp --offload-arch=gfx90a"

rm -f ./*.mod fp_A fp_B fp_C fp_D fp_E
for spec in \
    A:VARIANT_A_BASELINE \
    B:VARIANT_B_FP_ARRAY \
    C:VARIANT_C_FP_SCALARS \
    D:VARIANT_D_FP_ARRAY_CONST \
    E:VARIANT_E_PRIV_ARRAY_DYN ; do
    tag="${spec%%:*}"; macro="${spec##*:}"
    "$FC" -cpp $CFLAGS -D"$macro" firstprivate_array.f90 $LFLAGS -o "fp_$tag"
    echo "  built fp_$tag  ($macro)"
done

# The static fingerprint: the firstprivate-array variants (B, D) carry a ~37x
# larger embedded GPU code object than the scalar/private variants (A, C, E).
echo
echo "embedded GPU code-object size (.llvm.offloading):"
for tag in A B C D E; do
    sz=$(llvm-objcopy --dump-section=.llvm.offloading=/dev/stdout "fp_$tag" 2>/dev/null | wc -c)
    printf "  fp_%s  %8s bytes\n" "$tag" "$sz"
done
