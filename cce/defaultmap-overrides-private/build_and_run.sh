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

# ---------------------------------------------------------------------------
# Run and score. The login node has a GPU, so no srun is needed; set NO_RUN=1
# to stop after the build and just print the commands.
# ---------------------------------------------------------------------------
export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

if [ "${NO_RUN:-0}" = 1 ]; then
    echo "== NO_RUN set; run these yourself (on a GPU node, prefix with: srun -n1 --gpus-per-task 1)"
    for b in $BINS; do echo "    ./$b"; done
    exit 0
fi

run_arm() {                        # run_arm <binary> <expected: PASS|ABORT>
    local bin=$1 want=$2 out got
    out=$(./"$bin" 2>&1)
    case "$out" in
        *find_in_present_table*failed*) got=ABORT;;
        *PASS*)                         got=PASS;;
        *FAIL*)                         got=FAIL;;
        *)                              got=UNKNOWN;;
    esac
    guard_verdict "$want" "$got" "$(printf '%-24s %s' "$bin" \
        "$(printf '%s\n' "$out" | grep -m1 -E 'PASS|FAIL|find_in_present_table' | cut -c1-72)")"
}

echo "== running (login node has a GPU; no srun needed)"
run_arm priv_bare               PASS    # control: private() alone is fine
run_arm priv_defaultmap_tofrom  PASS    # control: defaultmap(tofrom) is fine
run_arm priv_defaultmap_present ABORT   # <-- the defect

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT (as documented) -- defaultmap(present:...) overrides an"
    echo "        explicit private() clause, so the runtime looks 'length(:)' up in the"
    echo "        present table and aborts on an array the program said was private."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        Both controls must PASS. If one moved, this is an environment problem"
    echo "        and the comparison proves nothing -- check them before the defect arm."
fi
exit "$GUARD_RC"
