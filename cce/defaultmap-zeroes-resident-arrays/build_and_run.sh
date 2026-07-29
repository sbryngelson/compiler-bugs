#!/bin/bash
# Build the resident-array reproducer, the per-clause bisect, and the two negative
# controls, then print the run commands.  Needs a GPU to run.
#
#   module reset
#   module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
#   module swap cce cce/21.0.2
#   ./build_and_run.sh
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

WANT=${1:-21.0.2}
echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"
guard_accel

PROGS="resident_bare resident_defaultmap resident_agg_only resident_alloc_only resident_ptr_only
       control_negative_bounds control_named_exit"

echo
echo "== building (separate dirs: the programs share module names)"
out=build-$WANT
for f in $PROGS; do
    mkdir -p "$out/$f"
    ( cd "$out/$f" && ftn -homp -J. -o "$f" "../../$f.f90" ) >"$out/$f.log" 2>&1 \
        || { echo "build failed for $f:"; cat "$out/$f.log"; exit 1; }
    grep -q 'ftn-1350' "$out/$f.log" && guard_fatal \
        "ftn ignored -homp for $f (ftn-1350) -- this would be a host build."
done
echo "  built $(echo $PROGS | wc -w) programs"

echo
echo "== verifying each binary really contains GPU code"
for f in $PROGS; do guard_device_image "$out/$f/$f"; done

echo
# ---------------------------------------------------------------------------
# Run and score. Login node has a GPU; NO_RUN=1 stops after the build.
#
# Scored on the device value, not PASS/FAIL: every failing row must read
# device=0 specifically. A nonzero-but-wrong device value would be a different
# defect than "the resident array reads as all zeros inside the target region".
# ---------------------------------------------------------------------------
export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

if [ "${NO_RUN:-0}" = 1 ]; then
    echo "== NO_RUN set; run these yourself (on a GPU node: srun -n1 --gpus-per-task 1 ./b)"
    for b in "$out"/*; do [ -x "$b" ] && echo "    ./$b"; done
    exit 0
fi

# binary : expected-host : expected-device : role
EXPECT="resident_bare:982:982:baseline-no-clause
resident_defaultmap:982:0:THE-DEFECT
resident_agg_only:982:0:defect-clause-alone-suffices
resident_alloc_only:982:0:defect-clause-alone-suffices
resident_ptr_only:982:0:defect-clause-alone-suffices
control_negative_bounds:170:170:control-not-the-trigger
control_named_exit:3684:3684:control-not-the-trigger"

echo
echo "== running (login node has a GPU; no srun needed)"
# Each binary prints three rows (pointer-component, allocatable-component, bare
# module array). All three must show the same host/device pair, so the whole set
# is scored -- checking only the first row would miss a clause-specific change.
for e in $EXPECT; do
    b=${e%%:*}; r=${e#*:}; wh=${r%%:*}; r=${r#*:}; wd=${r%%:*}; role=${r#*:}
    bin="$out/$b/$b"
    [ -x "$bin" ] || { guard_verdict "$wh/$wd" "not-built" "$b"; continue; }
    got=$(./"$bin" 2>&1 | sed -n 's/.*host=\([0-9-]\+\)[[:space:]]*device=\([0-9-]\+\).*/\1\/\2/p' \
          | sort -u | paste -sd, -)
    guard_verdict "$wh/$wd" "${got:-no-output}" "$(printf '%-26s %s' "$b" "$role")"
done

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT (as documented) -- a device-resident array reads as all"
    echo "        zeros inside the target region. Each of the three clauses triggers it"
    echo "        on its own, while the bare baseline and both controls are correct."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        NOTE the polarity: device=0 on the defect rows is the bug REPRODUCING."
    echo "        If resident_bare or a control moved, suspect the toolchain before"
    echo "        believing anything about the failing rows."
fi
exit "$GUARD_RC"

