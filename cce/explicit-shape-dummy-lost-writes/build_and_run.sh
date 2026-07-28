#!/bin/bash
# Build the explicit-shape-dummy reproducer under both offload models, then print
# the run commands.  Needs a GPU to run; the build is guarded because a host-only
# build makes both shapes PASS and the defect vanish.
#
#   module reset
#   module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
#   module swap cce cce/21.0.2          # or 19.0.0 with cpe/25.03 rocm/6.3.1
#   ./build_and_run.sh
#
# Both CCE 19.0.0 and 21.0.2 are affected, so either is a valid target here --
# there is no "good" version to use as a control.
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

WANT=${1:-21.0.2}
echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"
guard_accel

echo
echo "== building (separate dirs: both files define module m_gp)"
out=build-$WANT
mkdir -p "$out/omp" "$out/acc"
( cd "$out/omp" && ftn -homp -J. -o dummyshape ../../dummyshape.f90 ) >"$out/omp.log" 2>&1 \
    || { echo "OpenMP build failed:"; cat "$out/omp.log"; exit 1; }
( cd "$out/acc" && ftn -hacc -J. -o dummyshape_acc_fixed ../../dummyshape_acc_fixed.f90 ) >"$out/acc.log" 2>&1 \
    || { echo "OpenACC build failed:"; cat "$out/acc.log"; exit 1; }
for l in "$out/omp.log" "$out/acc.log"; do
    grep -q 'ftn-1350' "$l" && guard_fatal \
        "ftn ignored the offload flag ($l) -- this would be a host build."
done
echo "  built $out/omp/dummyshape and $out/acc/dummyshape_acc_fixed"

echo
echo "== verifying each binary really contains GPU code"
guard_device_image "$out/omp/dummyshape"
guard_device_image "$out/acc/dummyshape_acc_fixed"

echo
cat <<EOF
== now run them on a GPU node

    export LD_LIBRARY_PATH="\${ROCM_PATH}/lib:\${CRAY_LD_LIBRARY_PATH}:\${LD_LIBRARY_PATH}"
    for m in explicit assumed; do srun -n1 --gpus-per-task 1 ./$out/omp/dummyshape     \$m; done
    for m in explicit assumed; do srun -n1 --gpus-per-task 1 ./$out/acc/dummyshape_acc_fixed \$m; done

Expected on CCE 21.0.2 -- the defect is OpenMP-only:

    omp  dummy=explicit  wrong=64 of 64   FAIL   <-- the defect: device writes
                                                     through the explicit-shape
                                                     dummy are lost
    omp  dummy=assumed   wrong=0  of 64   PASS   <-- control: assumed-shape ok
    acc  dummy=explicit  wrong=0  of 64   PASS   <-- control: OpenACC ok
    acc  dummy=assumed   wrong=0  of 64   PASS

The OpenMP failure also reproduces on CCE 19.0.0 (./build_and_run.sh 19.0.0).

NOTE the polarity: the omp 'explicit' row printing FAIL is the bug REPRODUCING.
The other three rows are controls and must PASS -- if an OpenACC row fails, the
comparison proves nothing, which is exactly how this reproducer was got wrong
twice (see README).

To capture the mapping evidence in README.md:
    CRAY_ACC_DEBUG=2 srun -n1 --gpus-per-task 1 ./$out/omp/dummyshape explicit
EOF
