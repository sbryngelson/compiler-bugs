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
cat <<EOF
== now run them on a GPU node

    export LD_LIBRARY_PATH="\${ROCM_PATH}/lib:\${CRAY_LD_LIBRARY_PATH}:\${LD_LIBRARY_PATH}"
    for b in v_write v_read v_lb0; do srun -n1 --gpus-per-task 1 ./$out/\$b; done

Expected on CCE 21.0.2 -- the defect:

    v_write nbad=64 of 64  FAIL      <-- the dynamically-indexed store was discarded
       e.g. j=1 got 0 expected 5
    v_read  nbad=0 of 64   PASS      <-- control: dynamic *load* is fine
    v_lb0   nbad=0 of 64   PASS      <-- control: same store, lower bound 0, fine

Expected on CCE 19.0.0 (./build_and_run.sh 19.0.0) -- all three PASS.

NOTE the polarity: v_write printing FAIL is the bug REPRODUCING.  v_write
printing PASS on 21.0.2 means either the defect is fixed or -- far more likely --
something in the toolchain is not what you think it is.
EOF
