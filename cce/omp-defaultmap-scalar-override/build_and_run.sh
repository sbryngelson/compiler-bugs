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
# ---------------------------------------------------------------------------
# Run and score against the documented duplicate counts. The login node has a
# GPU, so no srun is needed; NO_RUN=1 stops after the build.
#
# Scoring the exact count, not just PASS/FAIL, is deliberate: 'bare' and
# 'defaultmap' both FAIL, but for different reasons (3840 = the conforming
# OpenMP 5.0 scalar default with 256 unique values; 4095 = the defect, a single
# shared scalar). A pass/fail harness would call those the same thing.
# ---------------------------------------------------------------------------
export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

if [ "${NO_RUN:-0}" = 1 ]; then
    echo "== NO_RUN set; run these yourself (on a GPU node: srun -n1 --gpus-per-task 1 ./b)"
    for b in "$ACC" $OMP; do echo "    ./$out/$b"; done
    exit 0
fi

# binary                 expected-duplicates   role
EXPECT="atomcap_acc:0:control-reference
atomcap_omp_maponly:0:control-only-correct-omp-form
atomcap_omp_bare:3840:conforming-omp5-scalar-default
atomcap_omp_defaultmap:4095:THE-DEFECT
atomcap_omp_order:4095:defect-order-irrelevant
atomcap_omp_tofrom:4095:defect
atomcap_omp_tofrommap:4095:defect"

echo "== running (login node has a GPU; no srun needed)"
for e in $EXPECT; do
    b=${e%%:*}; rest=${e#*:}; want=${rest%%:*}; role=${rest#*:}
    line=$(./"$out/$b" 2>&1 | grep -m1 'duplicates=')
    got=$(printf '%s\n' "$line" | grep -oE 'duplicates=[0-9]+' | grep -oE '[0-9]+')
    guard_verdict "$want" "${got:-none}" "$(printf '%-24s %-32s' "$b" "$role")"
done

# The two *_update variants drop the capture and keep only the increment. Both
# must PASS -- they are what attributes the defect to defaultmap's data
# environment rather than to the atomic itself.
for b in atomcap_omp_update atomcap_acc_update; do
    o=$(./"$out/$b" 2>&1)
    case "$o" in *PASS*) g=PASS;; *FAIL*) g=FAIL;; *) g=UNKNOWN;; esac
    guard_verdict PASS "$g" "$(printf '%-24s %-32s' "$b" "control-increment-only")"
done

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT (as documented) -- with defaultmap in play every thread"
    echo "        shares one scalar (4095 duplicates of 4096), regardless of clause order"
    echo "        or tofrom. 'bare' at 3840 is the conforming default, and the OpenACC and"
    echo "        increment-only controls are clean, so the atomic is not at fault."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        NOTE the polarity: 4095 on the defaultmap rows is the bug REPRODUCING."
    echo "        Check the controls (acc, maponly, *_update) first -- if one of those"
    echo "        moved, the comparison proves nothing and the environment is suspect."
fi
exit "$GUARD_RC"
