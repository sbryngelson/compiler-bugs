#!/bin/bash
# Minimal reproducer: defaultmap(firstprivate:scalar) gives scalars WORKGROUP extent.
#
# Scored on LDS bytes in the final device binary, not on a wrong answer. A scalar
# covered by defaultmap(firstprivate:...) must be per-thread and needs no LDS; the
# explicit private() spelling of the same scalars allocates none. Any nonzero LDS
# under defaultmap is already non-conforming, and it costs occupancy even when the
# arithmetic happens to come out right.
#
#   source <MFC>/mfc.sh load -c f -m g     # CCE 19.0.0 or 21.0.2
#   ./run.sh
set -u
cd "$(dirname "$0")" || exit 1
. ../../lib/guard.sh
WANT=${1:-19.0.0}
echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"; guard_accel
BIN=/opt/cray/pe/cce/$WANT/cce-clang/x86_64/bin
EXTRACT=../../lib/extract-device-image.py

lds() {   # lds <flags...> -> bytes of LDS in the final binary
    ftn -homp -O3 -eZ "$@" lds_scalar.f90 -o _b >/dev/null 2>&1 || { echo BUILD_FAIL; return; }
    python3 "$EXTRACT" _b _b.elf >/dev/null 2>&1 || { echo NO_DEVICE_IMAGE; return; }
    "$BIN/llvm-readelf" --notes _b.elf 2>/dev/null \
      | grep -oE 'group_segment_fixed_size:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | sort -rn | head -1
}
echo
echo "== LDS allocated for 96 loop-local scalars"
dm=$(lds); ex=$(lds -DEXPLICIT)
printf '  %-34s %s bytes\n' 'defaultmap(firstprivate:scalar)' "$dm"
printf '  %-34s %s bytes\n' 'explicit private(...)' "$ex"
rm -f _b _b.elf ./*.i

echo
guard_verdict 0 "${ex:-?}" "control: explicit private() allocates no LDS"
guard_verdict yes "$([ "${dm:-0}" -gt 0 ] 2>/dev/null && echo yes || echo no)" \
    "defaultmap allocates LDS for per-thread scalars (got ${dm} bytes)"
echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT (as documented) -- defaultmap(firstprivate:scalar) gave"
    echo "        per-thread scalars workgroup extent, consuming ${dm} bytes of LDS that"
    echo "        the explicit spelling of the same scalars does not need."
    echo
    echo "        NOTE: this program still prints PASS. With one write immediately"
    echo "        followed by its own read, the value stays in a register and the shared"
    echo "        copy is never read back, so the race is not observable here. The"
    echo "        wrong-answer demonstration is ../cray_defaultmap.f90, whose larger"
    echo "        kernel does force round-trips through the shared copy (NaN). Both"
    echo "        matter: this one shows the mechanism and the occupancy cost, that one"
    echo "        shows the numerical consequence."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        If the control moved, the environment is wrong, not the compiler."
fi
exit "$GUARD_RC"
