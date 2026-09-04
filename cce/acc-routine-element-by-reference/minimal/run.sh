#!/bin/bash
# Minimal form of acc-routine-element-by-reference.
#
# An `!$acc loop` inside an `!$acc routine seq` corrupts the argument passing for any
# ARRAY ELEMENT actual argument of that routine. An intent(out) element's store is
# dropped; an intent(in) element reads garbage. Both ingredients are required, and
# neither alone reproduces:
#
#   loop directive in the routine   x   array element as actual arg   ->  WRONG
#   loop directive in the routine   x   scalar as actual arg          ->  right
#   no loop directive               x   array element as actual arg   ->  right
#
# Single file, one call level, eight-line callee. Not about inlining: the no-loop
# case stays correct when the callee is put in its own translation unit and when
# interprocedural optimization is disabled (-hipa0).
#
#   module reset
#   module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
#   module swap cce cce/21.0.2
#   ./run.sh 21.0.2
set -u
cd "$(dirname "$0")" || exit 1
. ../../lib/guard.sh

WANT=${1:-21.0.2}
echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"
guard_accel

F="-hacc -O2"
bad() {   # bad <source> -> number of wrong elements out of 300
    local src=$1 bin=_${1%.f90}
    rm -f ./*.mod
    ftn $F "$src" -o "$bin" >/dev/null 2>&1 || { echo BUILD_FAIL; return; }
    guard_device_image "$bin" >/dev/null 2>&1 || { echo HOST_BUILD; return; }
    ./"$bin" 2>/dev/null | sed -n 's/^BAD=//p'
}

echo
echo "== the defect ($F)"
eo=$(bad element_out.f90);      printf '  %-38s %s\n' 'element out, loop in routine'   "$(./_element_out    2>/dev/null | head -1)"
ei=$(bad element_in.f90);       printf '  %-38s %s\n' 'element in,  loop in routine'   "$(./_element_in     2>/dev/null | head -1)"
dt=$(bad derived_type_in.f90);  printf '  %-38s %s\n' 'derived-type field in'          "$(./_derived_type_in 2>/dev/null | head -1)"
echo
echo "== controls (each removes exactly one ingredient)"
nl=$(bad control_no_loop.f90);  printf '  %-38s %s\n' 'same, loop directive deleted'   "$(./_control_no_loop    2>/dev/null | head -1)"
sa=$(bad control_scalar_arg.f90); printf '  %-38s %s\n' 'same, scalar actual arg'      "$(./_control_scalar_arg 2>/dev/null | head -1)"

echo
guard_verdict 300 "$eo" "intent(out) array element: store dropped"
guard_verdict 300 "$ei" "intent(in) array element: reads garbage (NaN)"
guard_verdict 300 "$dt" "attached derived-type field: same as a plain array"
guard_verdict 0   "$nl" "control: no loop directive -> correct"
guard_verdict 0   "$sa" "control: scalar actual arg -> correct (the workaround)"

echo
echo "== optimization level (element_out.f90)"
for O in -O0 -O1 -O2 -O3; do
    F="-hacc $O"; printf '  %-6s bad %s of 300\n' "$O" "$(bad element_out.f90)"
done
F="-hacc -O2"

rm -f _* ./*.mod
echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT (as documented). The two ingredients are an \`!\$acc loop\`"
    echo "        inside an \`!\$acc routine seq\` and an array element passed as an actual"
    echo "        argument to it. Removing either one is sufficient; the application fix is"
    echo "        to remove the second (pass scalars) because it is local to the call site."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        If a control moved, suspect the environment before the compiler."
fi
exit "$GUARD_RC"
