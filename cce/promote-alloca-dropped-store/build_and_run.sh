#!/bin/bash
# Build the dropped-store reproducer and its two controls, then print the run
# commands.  Needs a GPU to run, so this script deliberately stops at the build
# and hands you the srun lines rather than guessing at scheduler policy.
#
# The build is the part that silently goes wrong: without the right CCE and the
# gfx90a target, ftn drops the OpenACC directives, produces a HOST binary, and
# the reproducer prints PASS.  guard_device_image below makes that impossible to
# miss -- it checks the binary actually contains an AMDGPU image.
#
#   module reset
#   module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
#   module swap cce cce/21.0.2         # or cce/19.0.0 with cpe/25.03 rocm/6.3.1
#   ./build_and_run.sh
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

WANT=${1:-21.0.2}          # pass 19.0.0 to build the negative control

echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"
guard_accel
# MFC's Frontier module file exports -disable-promote-alloca-to-vector, which is
# precisely the workaround for this defect; with it set, v_write prints PASS.
guard_lld_clean -disable-promote-alloca-to-vector

echo
echo "== building"
out="build-$WANT"; mkdir -p "$out"
for f in v_write v_read v_lb0; do
    if ! ftn -hacc -o "$out/$f" "$f.f90" >"$out/$f.buildlog" 2>&1; then
        echo "build failed for $f:"; cat "$out/$f.buildlog"; exit 1
    fi
    # ftn-1350 means -hacc was ignored; guard_accel should have caught it already.
    grep -q 'ftn-1350' "$out/$f.buildlog" && guard_fatal \
        "ftn ignored -hacc for $f (ftn-1350) -- this would be a host build."
done
echo "  built v_write v_read v_lb0"

echo
echo "== verifying each binary really contains GPU code"
for f in v_write v_read v_lb0; do guard_device_image "$out/$f"; done

echo
# ---------------------------------------------------------------------------
# Run and score. Login node has a GPU; NO_RUN=1 stops after the build.
#
# The expectation depends on which CCE was built: 19.0.0 is a genuine negative
# control (all three PASS), 21.0.2 regressed only v_write. Running both is the
# strongest check in this directory -- it shows the harness can produce both
# verdicts rather than being hardwired to report a defect.
# ---------------------------------------------------------------------------
export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

if [ "${NO_RUN:-0}" = 1 ]; then
    echo "== NO_RUN set; run these yourself (on a GPU node: srun -n1 --gpus-per-task 1 ./b)"
    for f in v_write v_read v_lb0; do echo "    ./$out/$f"; done
    exit 0
fi

case "$WANT" in
    19.0.0) want_write=PASS ;;    # negative control: predates the regression
    *)      want_write=FAIL ;;    # 21.0.x: the dynamically-indexed store is discarded
esac

run_arm() {                       # run_arm <binary> <expected> <role>
    local f=$1 want=$2 role=$3 line got
    line=$(./"$out/$f" 2>&1 | grep -m1 -E 'nbad=')
    case "$line" in *PASS*) got=PASS;; *FAIL*) got=FAIL;; *) got="?(${line:-no-output})";; esac
    guard_verdict "$want" "$got" "$(printf '%-8s %-28s %s' "$f" "$role" "$line")"
}

echo "== running (login node has a GPU; no srun needed)"
run_arm v_write "$want_write" "dynamic store <- THE DEFECT"
run_arm v_read  PASS          "control: dynamic load"
run_arm v_lb0   PASS          "control: same store, lb 0"

echo
if [ "$GUARD_RC" -eq 0 ]; then
    if [ "$want_write" = FAIL ]; then
        echo "RESULT: BUG PRESENT (as documented) -- CCE $WANT discarded the"
        echo "        dynamically-indexed store, while the dynamic load and the"
        echo "        lower-bound-0 form of the same store are both correct."
        echo "        Cross-check with: ./build_and_run.sh 19.0.0   (expects all PASS)"
    else
        echo "RESULT: NEGATIVE CONTROL OK -- CCE $WANT passes all three, as documented."
        echo "        This is the pre-regression baseline, not a fix."
    fi
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        NOTE the polarity: on 21.0.x, v_write printing FAIL is the bug"
    echo "        REPRODUCING. v_write printing PASS there means either a real fix or --"
    echo "        far more likely -- the toolchain is not what you think it is."
fi
exit "$GUARD_RC"
