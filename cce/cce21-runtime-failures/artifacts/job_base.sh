#!/bin/bash
#SBATCH -A CFD154
#SBATCH -J mfcbase
#SBATCH -N 1
#SBATCH -t 02:00:00
#SBATCH -p batch
#SBATCH -q hackathon
#SBATCH -o %x-%j.out
set -x
cd /lustre/orion/cfd154/scratch/sbryngelson/wt-base || exit 1
. ./mfc.sh load -c f -m g
hash -r
ftn --version | head -1
./mfc.sh test -v --dry-run -a -j 8 --gpu acc --mpi || { echo "BUILD FAILED"; exit 1; }
echo "======== 10% sample (acc, CCE19 BASELINE) ========"
./mfc.sh test --no-build -a -j 8 -% 10 --gpu acc --mpi -- -c frontier
echo "rc(sample_base)=$?"
echo "======== multi-rank set (acc, CCE19 BASELINE) ========"
for t in 0FCCE9F1 8C7AA13B CE232828 AFBACA70 CB0DC420 75D7CC39 0090B316 0DDE8A87; do
    ./mfc.sh test --only $t --no-build -j 1 --gpu acc --mpi -- -c frontier
    echo "rc($t)=$?"
done
echo "======== targeted repeats of CCE21 failures ========"
for t in CD6DC908 18B832DD D1C97CD1; do
    ./mfc.sh test --only $t --no-build -j 1 --gpu acc --mpi -- -c frontier
    echo "rc($t)=$?"
done
echo "======== DONE (baseline) ========"
