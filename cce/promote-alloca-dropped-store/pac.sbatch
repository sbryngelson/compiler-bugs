#!/bin/bash
#SBATCH -A CFD154
#SBATCH -J pac
#SBATCH -N 1 -t 00:15:00 -p batch -q hackathon
#SBATCH -o /lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/promote-alloca-dropped-store/pac-%j.txt
cd /lustre/orion/cfd154/scratch/sbryngelson/wt-cce21 && source ./mfc.sh load -c f -m g >/dev/null 2>&1
cd /lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/promote-alloca-dropped-store
echo -n "C arm: "; srun -N1 -n1 ./pa_c_bin 2>&1 | tail -1
echo "======== PAC DONE ========"
