#!/bin/bash
#SBATCH -A CFD154
#SBATCH -J ptratt
#SBATCH -N 1
#SBATCH -t 00:20:00
#SBATCH -p batch
#SBATCH -q hackathon
#SBATCH -o /lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/ptr-component-attach/out-%j.txt
cd /lustre/orion/cfd154/scratch/sbryngelson/wt-cce21 || exit 1
source ./mfc.sh load -c f -m g > /dev/null 2>&1
ftn --version | head -1
D=/lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/ptr-component-attach
cd $D
echo "=== build ==="
ftn -homp -DUSE_OMP -o ptr_omp ptrattach.f90 2>&1 | grep -E "ftn-[0-9]" | head -3
ftn -hacc        -o ptr_acc ptrattach.f90 2>&1 | grep -E "ftn-[0-9]" | head -3
echo "=== A = two separate maps (what MFC's ACC_SETUP_SFs emits) ==="
echo -n "  omp "; srun -N1 -n1 ./ptr_omp A 2>&1 | tail -1
echo -n "  acc "; srun -N1 -n1 ./ptr_acc A 2>&1 | tail -1
echo "=== B = one map with both objects (candidate workaround) ==="
echo -n "  omp "; srun -N1 -n1 ./ptr_omp B 2>&1 | tail -1
echo -n "  acc "; srun -N1 -n1 ./ptr_acc B 2>&1 | tail -1
