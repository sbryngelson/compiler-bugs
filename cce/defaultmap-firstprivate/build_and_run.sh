#!/bin/bash
# Cray CCE-19 OpenMP-offload defaultmap(firstprivate:scalar) bug. Frontier MI250X (gfx90a).
# Builds the same kernel three ways and runs them; the login node has a GPU, so this can run
# as-is, or under srun on a compute node.
set -e
cd "$(dirname "$0")"
module load PrgEnv-cray craype-accel-amd-gfx90a >/dev/null 2>&1 || true
module load cce/19.0.0 >/dev/null 2>&1 || true   # any CCE 19 drop
ftn --version | head -1
export OMP_TARGET_OFFLOAD=MANDATORY

# CCE native OpenMP offload: -homp (the clang-style -fopenmp --offload-arch is not accepted
# by this ftn); -eZ runs the C preprocessor for the -D knobs.
echo "correct checksum = 8.040644772571076E+07"
ftn -homp -O3 -eZ                cray_defaultmap.f90 -o cdm_private      && ./cdm_private
ftn -homp -O3 -eZ -DOMIT_SCALARS cray_defaultmap.f90 -o cdm_defaultmap   && ./cdm_defaultmap
ftn -homp -O3 -eZ -DEXPLICIT_FP  cray_defaultmap.f90 -o cdm_firstprivate && ./cdm_firstprivate

echo "--- robustness: defaultmap is wrong regardless of opt level / simd ---"
ftn -homp -O2 -eZ -DOMIT_SCALARS           cray_defaultmap.f90 -o cdm_d_O2     && ./cdm_d_O2
ftn -homp -O1 -eZ -DOMIT_SCALARS           cray_defaultmap.f90 -o cdm_d_O1     && ./cdm_d_O1
ftn -homp -O3 -eZ -DOMIT_SCALARS -DNO_SIMD cray_defaultmap.f90 -o cdm_d_nosimd && ./cdm_d_nosimd
ftn -homp -O3 -eZ -DOMIT_SCALARS -DWITH_FP cray_defaultmap.f90 -o cdm_d_fp     && ./cdm_d_fp
