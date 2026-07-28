#!/bin/bash
# Build the three arms and print the run commands.
#
#   module reset
#   module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
#   module swap cce cce/21.0.2
#   ./build_and_run.sh
#
# A GPU is required. A host-only build makes all three pass and the defect vanishes.
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh
echo "== environment (want CCE 21.0.2)"
guard_ftn 21.0.2
guard_accel
BINS="priv_bare priv_defaultmap_present priv_defaultmap_tofrom"
for b in $BINS; do ftn -homp -o "$b" "$b.f90" || { echo "FAILED to build $b"; exit 1; }; done
echo "built: $BINS"
echo
echo "== run on a compute node"
echo 'export LD_LIBRARY_PATH="$CRAY_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"'
for b in $BINS; do echo "srun -n1 --gpus-per-task 1 ./$b"; done
echo
echo "Expected: priv_bare and priv_defaultmap_tofrom PASS; priv_defaultmap_present"
echo "          aborts with find_in_present_table failed for 'length(:)' -- an array"
echo "          that is explicitly listed in the private() clause."
