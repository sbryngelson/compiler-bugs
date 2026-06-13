#!/bin/bash
#SBATCH -A cfd154
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -t 00:10:00
#SBATCH -o /lustre/orion/cfd154/scratch/sbryngelson/amdflang-static-declare-target-xtu/run-%j.out
bash /lustre/orion/cfd154/scratch/sbryngelson/amdflang-static-declare-target-xtu/build_and_run.sh
