#!/bin/bash
# Cray CCE-19 OpenMP-offload defaultmap(firstprivate:scalar) bug. Frontier MI250X (gfx90a).
#
# Load a working CCE-19 GPU-offload environment FIRST, then run this script. On Frontier the bare
# `module load`s are not enough (ftn fails with "libopenacc not found"); use MFC's module loader,
# which sets the cpe / pkg-config / library paths:
#
#     source /path/to/MFlowCode-MFC/mfc.sh load -c f -m g     # gives CCE 19 + craype-accel-amd-gfx90a
#     ./build_and_run.sh
#
# The login node has a GPU, so this runs as-is (or wrap the ./cdm_* in `srun` on a compute node).
cd "$(dirname "$0")"
if ! ftn --version >/dev/null 2>&1; then
    echo "ftn not functional. Load the env first:  source <MFC>/mfc.sh load -c f -m g" >&2
    exit 1
fi
ftn --version | head -1
export OMP_TARGET_OFFLOAD=MANDATORY

# crayftn takes the gfx90a target from the craype-accel-amd-gfx90a module (loaded by `-m g`),
# NOT from --offload-arch; -eZ runs the C preprocessor for the -D knobs.
set -e
echo "correct checksum = 8.040644772571076E+07"
ftn -fopenmp -O3 -eZ                cray_defaultmap.f90 -o cdm_private      && ./cdm_private
ftn -fopenmp -O3 -eZ -DOMIT_SCALARS cray_defaultmap.f90 -o cdm_defaultmap   && ./cdm_defaultmap
ftn -fopenmp -O3 -eZ -DEXPLICIT_FP  cray_defaultmap.f90 -o cdm_firstprivate && ./cdm_firstprivate

echo "--- robustness: defaultmap is wrong regardless of opt level / simd ---"
ftn -fopenmp -O2 -eZ -DOMIT_SCALARS           cray_defaultmap.f90 -o cdm_d_O2     && ./cdm_d_O2
ftn -fopenmp -O1 -eZ -DOMIT_SCALARS           cray_defaultmap.f90 -o cdm_d_O1     && ./cdm_d_O1
ftn -fopenmp -O3 -eZ -DOMIT_SCALARS -DNO_SIMD cray_defaultmap.f90 -o cdm_d_nosimd && ./cdm_d_nosimd
ftn -fopenmp -O3 -eZ -DOMIT_SCALARS -DWITH_FP cray_defaultmap.f90 -o cdm_d_fp     && ./cdm_d_fp
