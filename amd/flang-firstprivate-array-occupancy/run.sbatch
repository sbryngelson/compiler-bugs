#!/bin/bash
#SBATCH -J fp_array_occupancy
#SBATCH -t 00:20:00
#SBATCH -N 1
#SBATCH -n 1
# Run the five variants on one MI250X GCD with the kernel trace on, so the
# scratch / AGPR / occupancy numbers print next to the ns/element timing.
# Adjust the account/partition for your allocation, or run interactively:
#   LIBOMPTARGET_KERNEL_TRACE=1 ./fp_B 2>&1 | grep -E 'ns per|run_sweep'
cd "$(dirname "$0")"
module load PrgEnv-amd amd rocm 2>/dev/null || true
export OMP_TARGET_OFFLOAD=MANDATORY
export LIBOMPTARGET_KERNEL_TRACE=1

for tag in A B C D E; do
    echo "############################## fp_$tag ##############################"
    # ns/element on stdout, kernel trace on stderr; keep the timed dispatch line.
    srun -n1 ./"fp_$tag" 2>&1 | grep -E 'ns per element|variant|run_sweep' | tail -3
    echo
done
