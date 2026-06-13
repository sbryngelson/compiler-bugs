#!/bin/bash
#SBATCH --job-name=ifx2026_bugs
#SBATCH --partition=pvc
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:20:00
#SBATCH --output=%x_%j.out

# Source just the compiler component (avoids setvars.sh MPI/VTune hang)
source /scratch/user/u.sb27915/intel/oneapi-full/compiler/2026.0/env/vars.sh

# Add the 2026 UR loader (libur_loader.so.0.12) to the library path
export LD_LIBRARY_PATH="/scratch/user/u.sb27915/intel/oneapi-full/compiler/2026.0/lib:${LD_LIBRARY_PATH}"

echo "=== Compiler version ==="
ifx --version
echo ""

BUILD=/scratch/user/u.sb27915/intel-gpu-bugs/build_2026
mkdir -p "$BUILD"

# JIT compilation: spir64 (no ocloc needed, compiles on GPU at runtime)
FLAGS=(-fiopenmp -fopenmp-targets=spir64 -O2)

echo "=== Compiling with ifx 2026 (JIT/spir64) ==="
for src in /scratch/user/u.sb27915/intel-gpu-bugs/bug*.f90; do
    base=$(basename "$src")
    exe="$BUILD/${base%.f90}"
    printf "  %-50s" "$base"
    if ifx "${FLAGS[@]}" -o "$exe" "$src" 2>/tmp/ifx_err_$base; then
        echo "OK"
    else
        echo "FAILED"
        cat /tmp/ifx_err_$base
    fi
done

echo ""
echo "=== Running ==="
for exe in "$BUILD"/bug[1234]*; do
    [[ -x "$exe" ]] || continue
    echo "--- $(basename $exe) ---"
    timeout 120 "$exe" 2>&1
    rc=$?
    [[ $rc -eq 124 ]] && echo "TIMED OUT (>120s)"
    echo ""
done
