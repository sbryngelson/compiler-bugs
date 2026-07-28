#!/bin/bash
# Build the atomic-capture variant matrix and print the run commands.  Needs a
# GPU to run; the build is guarded because a host-only build makes every variant
# print PASS and the defect vanish.
#
#   module reset
#   module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
#   module swap cce cce/21.0.2
#   ./build_and_run.sh
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

echo "== environment (want CCE 21.0.2)"
guard_ftn 21.0.2
guard_accel

ACC=atomcap_acc
OMP="atomcap_omp_maponly atomcap_omp_bare atomcap_omp_defaultmap \
     atomcap_omp_order atomcap_omp_tofrom atomcap_omp_tofrommap \
     atomcap_omp_update atomcap_acc_update"

echo
echo "== building"
out=build; mkdir -p "$out"
build_one() {   # $1=name  $2=flag
    if ! ftn "$2" -o "$out/$1" "$1.f90" >"$out/$1.buildlog" 2>&1; then
        echo "build failed for $1:"; cat "$out/$1.buildlog"; exit 1
    fi
    grep -q 'ftn-1350' "$out/$1.buildlog" && guard_fatal \
        "ftn ignored $2 for $1 (ftn-1350) -- this would be a host build."
}
build_one "$ACC" -hacc
for f in $OMP; do
    case $f in atomcap_acc*) build_one "$f" -hacc ;; *) build_one "$f" -homp ;; esac
done
echo "  built $(ls "$out" | grep -vc buildlog) binaries"

echo
echo "== verifying each binary really contains GPU code"
for f in "$ACC" $OMP; do guard_device_image "$out/$f"; done

echo
cat <<'EOF'
== now run them on a GPU node

    export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"
    for b in build/atomcap_*; do [ -x "$b" ] && srun -n1 --gpus-per-task 1 "./$b"; done

Expected on CCE 21.0.2 (measured; see README variant matrix and run-output.txt):

    acc copyin (control)      duplicates=0     PASS   <- reference
    omp map only              duplicates=0     PASS   <- the only correct OpenMP form
    omp no-map no-defmap      duplicates=3840  FAIL   <- conforming: 256 unique, the
                                                         OpenMP 5.0 scalar default
    omp defaultmap+map        duplicates=4095  FAIL   <- THE DEFECT
    omp map-then-defaultmap   duplicates=4095  FAIL   <- order is irrelevant
    omp tofrom+map            duplicates=4095  FAIL
    omp defmap+map(tofrom)    duplicates=4095  FAIL

NOTE the polarity: FAIL on the defaultmap rows is the bug REPRODUCING.  The
'bare' row failing is expected and conforming -- it is included so the defect is
not confused with the language default.

The two *_update variants (atomic update rather than atomic capture) are extra
controls; their results are not in the measured matrix above.
EOF
