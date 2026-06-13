#!/bin/bash
#SBATCH -A cfd154
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -t 00:10:00
#SBATCH -o /lustre/orion/cfd154/scratch/sbryngelson/amdflang-static-declare-target-xtu/run-new-%j.out
set -e
NEW=/sw/crusher/ums/compilers/afar/therock-afar-23.2.0-gfx90a-7.13.0-663ad81964a
cd /lustre/orion/cfd154/scratch/sbryngelson/amdflang-static-declare-target-xtu
export PATH=$NEW/bin:$PATH
export LD_LIBRARY_PATH=$NEW/lib/llvm/lib:$NEW/lib:$NEW/lib/rocm_sysdeps/lib:$LD_LIBRARY_PATH
FC=$NEW/bin/amdflang
echo "=== compiler ==="; "$FC" --version 2>&1 | head -1
CF="-fopenmp --offload-arch=gfx90a -O3 -fopenmp-assume-threads-oversubscription -fopenmp-assume-teams-oversubscription"
export OMP_TARGET_OFFLOAD=MANDATORY
rm -f *.o *.mod repro_new
"$FC" $CF -c repro_mod.f90  -o repro_mod.o
"$FC" $CF -c repro_main.f90 -o repro_main.o
"$FC" -fopenmp --offload-arch=gfx90a -flto-partitions=16 repro_mod.o repro_main.o -o repro_new
echo "--- run (newest amdflang: LLVM 23.0.0git / AFAR drop 23.2.0) ---"
srun -n1 ./repro_new; echo "exit=$?"
echo "=== DONE ==="
