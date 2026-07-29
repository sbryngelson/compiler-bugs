#!/bin/bash
# Cray CCE-19 OpenMP-offload defaultmap(firstprivate:scalar) bug. Frontier MI250X (gfx90a).
#
# Load a working CCE-19 GPU-offload environment FIRST, then run this script. On Frontier the bare
# `module load`s are not enough (ftn fails with "libopenacc not found"); use MFC's module loader,
# which sets the cpe / pkg-config / library paths:
#
#     source /path/to/MFlowCode-MFC/mfc.sh load -c f -m g     # gives CCE 19 + craype-accel-amd-gfx90a
#     ./build_and_run.sh
#
# The login node has a GPU, so this runs as-is (or wrap the ./cdm_* in `srun` on a compute node).
cd "$(dirname "$0")"
if ! ftn --version >/dev/null 2>&1; then
    echo "ftn not functional. Load the env first:  source <MFC>/mfc.sh load -c f -m g" >&2
    exit 1
fi
ftn --version | head -1
export OMP_TARGET_OFFLOAD=MANDATORY

# crayftn takes the gfx90a target from the craype-accel-amd-gfx90a module (loaded by `-m g`),
# NOT from --offload-arch; -eZ runs the C preprocessor for the -D knobs.
REF=8.040644772571076E+07
TOL=1e-6          # relative; the WRONG runs are NaN or ~0.6% off, so this is not delicate

# Build+run one variant, print the checksum with a correct/WRONG label, and echo the
# bare verdict on fd 3 so the aggregate below can score it.
run_variant() {                       # run_variant <label> <binary> <flags...>
    local label=$1 bin=$2; shift 2
    if ! ftn -fopenmp -eZ "$@" cray_defaultmap.f90 -o "$bin" 2>/dev/null; then
        printf '  %-42s %s\n' "$label" 'BUILD FAILED'; echo build >&3; return
    fi
    local out cks
    out=$(./"$bin" 2>&1)
    cks=$(printf '%s\n' "$out" | sed -n 's/.*checksum *= *//p' | tail -1 | tr -d ' ')
    local v
    v=$(awk -v c="$cks" -v r="$REF" -v t="$TOL" 'BEGIN{
            if (c+0 != c+0 || c ~ /[Nn][Aa][Nn]/) { print "wrong"; exit }   # NaN
            d = (c-r)/r; if (d<0) d=-d
            print (d<t) ? "correct" : "wrong" }')
    printf '  %-42s checksum = %22s   %s\n' "$label" "$cks" \
           "$([ "$v" = correct ] && echo correct || echo WRONG)"
    echo "$v" >&3
}

echo "correct checksum = $REF"
echo
exec 3>/tmp/dmfp_verdicts.$$; : >/tmp/dmfp_verdicts.$$

run_variant "private(all) simd"            cdm_private      -O3
run_variant "defaultmap(fp:scalar) simd"   cdm_defaultmap   -O3 -DOMIT_SCALARS
run_variant "firstprivate(all) simd"       cdm_firstprivate -O3 -DEXPLICIT_FP

echo
echo "--- robustness: defaultmap is wrong regardless of opt level / simd ---"
run_variant "defaultmap(fp:scalar) -O2 simd"            cdm_d_O2     -O2 -DOMIT_SCALARS
run_variant "defaultmap(fp:scalar) -O1 simd"            cdm_d_O1     -O1 -DOMIT_SCALARS
run_variant "defaultmap(fp:scalar) -O3 nosimd"          cdm_d_nosimd -O3 -DOMIT_SCALARS -DNO_SIMD
run_variant "defaultmap(fp:scalar) -O3 + fp(re)"        cdm_d_fp     -O3 -DOMIT_SCALARS -DWITH_FP

exec 3>&-
mapfile -t V </tmp/dmfp_verdicts.$$; rm -f /tmp/dmfp_verdicts.$$

# V[0]=private V[1]=defaultmap V[2]=firstprivate, then 4 robustness runs.
echo
if printf '%s\n' "${V[@]}" | grep -q build; then
    echo "VERDICT: INCONCLUSIVE -- at least one variant failed to build."
    exit 2
elif [ "${V[0]}" = correct ] && [ "${V[2]}" = correct ] && [ "${V[1]}" = wrong ]; then
    n=0; for k in 3 4 5 6; do [ "${V[$k]}" = wrong ] && n=$((n+1)); done
    echo "VERDICT: BUG PRESENT (as documented) -- defaultmap(firstprivate:scalar) is wrong while the"
    echo "         explicit private(all) and firstprivate(all) spellings of the SAME"
    echo "         scalars are both correct. Wrong in $n/4 robustness configs too."
    exit 0
elif [ "${V[0]}" = correct ] && [ "${V[1]}" = correct ] && [ "${V[2]}" = correct ]; then
    echo "VERDICT: FIXED -- defaultmap(firstprivate:scalar) now matches the explicit spellings."
    echo "         This DEVIATES from the documented behaviour; confirm it is a real fix."
    exit 1
else
    echo "VERDICT: INCONCLUSIVE -- private=${V[0]} defaultmap=${V[1]} firstprivate=${V[2]}."
    echo "         The controls are supposed to be correct; if they are not, the"
    echo "         environment is wrong, not the compiler."
    exit 2
fi
