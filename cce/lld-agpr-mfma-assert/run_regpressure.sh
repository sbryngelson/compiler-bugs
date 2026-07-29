#!/bin/bash
# Cost of the -mattr=-mai-insts workaround on gfx90a, in one file.
#
# gfx90a has a unified VGPR/AGPR register file: disabling MFMA/AGPR removes half the
# allocator's budget, so register-hungry kernels spill to scratch. regpressure.f90 holds
# eight live 32-element double arrays in an !$acc routine seq.
#
# This measures the workaround's COST -- it is not the assert reproducer. For the defect
# itself see repro/run.sh.
#
#   source <MFC>/mfc.sh load -c f -m g     # then run this; the script manages the flag
#   ./run_regpressure.sh
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

WANT=${1:-21.0.2}
echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"
guard_accel

BIN=$(dirname "$(command -v ftn)")/../../cce-clang/x86_64/bin
[ -x "$BIN/llvm-readelf" ] || BIN=/opt/cray/pe/cce/$WANT/cce-clang/x86_64/bin
EXTRACT=${EXTRACT:-../lib/extract-device-image.py}
[ -f "$EXTRACT" ] || guard_fatal "cannot find extract-device-image.py at $EXTRACT"

echo
printf "%-10s %-10s %-10s %-12s\n" arm max_vgpr max_agpr max_scratch
declare -A VGPR AGPR SCRATCH
for m in baseline noagpr; do
    # The ambient CRAY_CCE_LLD_ARGS must not leak into the baseline arm: MFC's module
    # file exports -mai-insts, which is exactly what this arm is the control for.
    if [ "$m" = noagpr ]; then export CRAY_CCE_LLD_ARGS="-plugin-opt=-mattr=-mai-insts"
    else unset CRAY_CCE_LLD_ARGS; fi

    if ! ftn -hacc -o "rp_$m" regpressure.f90 > "build_$m.log" 2>&1; then
        echo "$m: BUILD FAILED (see build_$m.log)"; GUARD_RC=2; continue
    fi
    python3 "$EXTRACT" "rp_$m" "rp_$m.elf" >/dev/null 2>&1 \
        || guard_fatal "could not extract the device image from rp_$m"

    g() { "$BIN"/llvm-readelf --notes "rp_$m.elf" 2>/dev/null \
            | grep -oE "$1:[[:space:]]+[0-9]+" | grep -oE "[0-9]+" | sort -rn | head -1; }
    VGPR[$m]=$(g vgpr_count); AGPR[$m]=$(g agpr_count); SCRATCH[$m]=$(g private_segment_fixed_size)
    printf "%-10s %-10s %-10s %-12s\n" "$m" "${VGPR[$m]:-?}" "${AGPR[$m]:-none}" "${SCRATCH[$m]:-?}"
done
unset CRAY_CCE_LLD_ARGS

# ---------------------------------------------------------------------------
# Score the signature, not the exact integers. Register counts move with CCE and
# ROCm versions, so pinning 512/256/36 vs 256/none/1060 would report a fix every
# time the allocator is retuned. What must hold is the mechanism:
#   baseline  uses AGPRs as extra storage and spills almost nothing
#   noagpr    has no AGPRs, VGPRs cap at 256, and scratch grows by >10x
# The measured numbers are printed above for comparison with README's table.
# ---------------------------------------------------------------------------
echo
echo "== documented (CCE 21.0.2): baseline 512 / 256 / 36 B   noagpr 256 / none / 1060 B"
echo
n() { [ -n "${1:-}" ] && [ "${1:-0}" -gt 0 ] 2>/dev/null && echo "$1" || echo 0; }
b_agpr=$(n "${AGPR[baseline]:-}"); n_agpr=$(n "${AGPR[noagpr]:-}")
b_scr=$(n "${SCRATCH[baseline]:-}"); n_scr=$(n "${SCRATCH[noagpr]:-}")
n_vgpr=$(n "${VGPR[noagpr]:-}")

guard_verdict yes "$([ "$b_agpr" -gt 0 ] && echo yes || echo no)" \
    "baseline uses AGPRs as extra register storage   [agpr=${b_agpr}]"
guard_verdict yes "$([ "$n_agpr" -eq 0 ] && echo yes || echo no)" \
    "-mai-insts leaves no AGPRs available           [agpr=${n_agpr}]"
guard_verdict yes "$([ "$n_vgpr" -le 256 ] && [ "$n_vgpr" -gt 0 ] && echo yes || echo no)" \
    "-mai-insts caps VGPRs at 256                   [vgpr=${n_vgpr}]"
if [ "$b_scr" -gt 0 ]; then
    ratio=$(( n_scr / b_scr ))
    guard_verdict yes "$([ "$ratio" -ge 10 ] && echo yes || echo no)" \
        "scratch grows by an order of magnitude         [${ratio}x: ${b_scr}B -> ${n_scr}B]"
else
    guard_verdict yes no "scratch ratio measurable                       [baseline=${b_scr}]"
fi

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: WORKAROUND COST CONFIRMED (as documented) -- disabling MFMA/AGPR removes"
    echo "        half the unified register file, so this kernel spills to scratch instead."
    echo "        This is the mechanism behind MFC's igr regression; it is the price of the"
    echo "        -mai-insts workaround for the lld assert, not a separate defect."
elif [ "$GUARD_RC" = 2 ]; then
    echo "RESULT: INCONCLUSIVE -- an arm failed to build. Not a statement about codegen."
else
    echo "RESULT: *** the cost signature changed ***"
    echo "        Exact counts drift with compiler versions and that alone is fine, but a"
    echo "        change in the SIGNATURE (AGPRs still available, or scratch no longer"
    echo "        growing) would mean the workaround stopped costing what it used to."
    echo "        Re-measure before updating README's table."
fi
exit "$GUARD_RC"
