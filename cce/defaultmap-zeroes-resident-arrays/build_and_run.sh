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

PROGS="resident_bare resident_defaultmap dtptr_aggonly dtptr_allocOnly dtptr_ptronly
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
cat <<EOF
== now run them on a GPU node

    export LD_LIBRARY_PATH="\${ROCM_PATH}/lib:\${CRAY_LD_LIBRARY_PATH}:\${LD_LIBRARY_PATH}"
    for f in $(echo $PROGS); do
        echo "##### \$f"; srun -n1 --gpus-per-task 1 ./$out/\$f/\$f
    done

Expected on CCE 21.0.2 (measured; see README and results/run-verified.txt):

    resident_bare             host=982 device=982   PASS  <- baseline, no clause
    resident_defaultmap       host=982 device=0     FAIL  <- THE DEFECT
    dtptr_aggonly             host=982 device=0     FAIL  <- each clause alone
    dtptr_allocOnly           host=982 device=0     FAIL     is sufficient
    dtptr_ptronly             host=982 device=0     FAIL
    control_negative_bounds   host=170 device=170   PASS  <- not the trigger
    control_named_exit        host=3684 device=3684 PASS  <- not the trigger

All three FAIL rows read device=0: the resident array reads as all zeros inside
the target region.  NOTE the polarity -- device=0 is the bug REPRODUCING.  The
bare row and both controls must PASS; if they do not, suspect the toolchain
before believing anything about the failing rows.
EOF
