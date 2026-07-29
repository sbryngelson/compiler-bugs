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
# ---------------------------------------------------------------------------
# Run and score. The login node has a GPU, so no srun is needed; set
# NO_RUN=1 to stop after the build and just print the commands.
# ---------------------------------------------------------------------------
export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

if [ "${NO_RUN:-0}" = 1 ]; then
    echo "== NO_RUN set; run these yourself (on a GPU node, prefix with: srun -n1 --gpus-per-task 1)"
    for m in explicit assumed; do echo "    ./$out/omp/dummyshape $m"; done
    for m in explicit assumed; do echo "    ./$out/acc/dummyshape_acc_fixed $m"; done
    exit 0
fi

# arm  binary                      dummy      expected
#                                             (FAIL = the defect reproducing)
run_arm() {                       # run_arm <model> <binary> <dummy> <expected>
    local model=$1 bin=$2 dummy=$3 want=$4 line got
    line=$(./"$bin" "$dummy" 2>&1 | tail -1)
    case "$line" in
        *PASS*) got=PASS;; *FAIL*) got=FAIL;; *) got="?($line)";;
    esac
    guard_verdict "$want" "$got" "$(printf '%-4s dummy=%-8s %s' "$model" "$dummy" "$line")"
}

echo "== running (login node has a GPU; no srun needed)"
run_arm omp "$out/omp/dummyshape"                explicit FAIL   # <-- the defect
run_arm omp "$out/omp/dummyshape"                assumed  PASS   # control
run_arm acc "$out/acc/dummyshape_acc_fixed"      explicit PASS   # control
run_arm acc "$out/acc/dummyshape_acc_fixed"      assumed  PASS   # control

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT (as documented) -- OpenMP device writes through an"
    echo "        explicit-shape dummy are lost, while the assumed-shape dummy and"
    echo "        both OpenACC arms are correct."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        NOTE the polarity: the omp/explicit row is SUPPOSED to say FAIL."
    echo "        If a CONTROL row moved, the comparison proves nothing and this is an"
    echo "        environment problem, not a fix -- that is how this reproducer was"
    echo "        got wrong twice (see README). Check the controls before the defect."
fi
echo
echo "To capture the mapping evidence in README.md:"
echo "    CRAY_ACC_DEBUG=2 ./$out/omp/dummyshape explicit"
exit "$GUARD_RC"
