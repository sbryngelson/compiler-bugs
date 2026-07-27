#!/bin/bash
#SBATCH -A CFD154
#SBATCH -J mfcv_mp
#SBATCH -N 1
#SBATCH -t 02:00:00
#SBATCH -p batch
#SBATCH -q hackathon
#SBATCH -o %x-%j.out
set -x
cd /lustre/orion/cfd154/scratch/sbryngelson/wt-cce21 || exit 1
. ./mfc.sh load -c f -m g
hash -r
ftn --version | head -1
./mfc.sh test -v --dry-run -a -j 8 --gpu mp --mpi || { echo "BUILD FAILED"; exit 1; }
echo "======== 10% sample (mp, MPI) ========"
./mfc.sh test --no-build -a -j 8 -% 10 --gpu mp --mpi -- -c frontier
echo "rc(sample_mp)=$?"
echo "======== multi-rank set (mp, MPI) ========"
for t in 0FCCE9F1 8C7AA13B CE232828 AFBACA70 CB0DC420 75D7CC39 0090B316 0DDE8A87; do
    ./mfc.sh test --only $t --no-build -j 1 --gpu mp --mpi -- -c frontier
    echo "rc($t)=$?"
done
echo "======== DONE (mp) ========"
