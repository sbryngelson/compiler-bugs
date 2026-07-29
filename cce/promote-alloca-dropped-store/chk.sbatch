#!/bin/bash
#SBATCH -A CFD154
#SBATCH -J pachk
#SBATCH -N 1 -t 00:15:00 -p batch -q hackathon
#SBATCH -o /lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/promote-alloca-dropped-store/chk-%j.txt
cd /lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/promote-alloca-dropped-store
for f in v_write_chk v_lb0_chk v_read_chk; do echo -n "$f: "; srun -N1 -n1 ./$f 2>&1 | tail -1; done
