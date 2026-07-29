#!/bin/bash
#SBATCH -A CFD154
#SBATCH -J dmc
#SBATCH -N 1 -t 00:15:00 -p batch -q hackathon
#SBATCH -o /lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/defaultmap-zeroes-resident-arrays/ctest-%j.txt
cd /lustre/orion/cfd154/scratch/sbryngelson/wt-cce21 && source ./mfc.sh load -c f -m g >/dev/null 2>&1
cd /lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/defaultmap-zeroes-resident-arrays
echo -n "C arm: "; srun -N1 -n1 ./dm_min_c 2>&1 | tail -1
echo "======== CTEST DONE ========"
