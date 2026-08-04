#!/usr/bin/env bash
#SBATCH -N 1 -t 01:30:00
set -u
ARCH=$1
M=/work1/spencerbryngelson/sbryngelson/meta
A=/work1/spencerbryngelson/sbryngelson/software/therock-afar-23.2.1-gfx90a-7.13.0-7357b5084b
export LD_LIBRARY_PATH="$A/lib/llvm/lib:$A/lib:${LD_LIBRARY_PATH:-}"
cd $M
FF="-fopenmp --offload-arch=$ARCH -fopenmp-assume-threads-oversubscription -fopenmp-assume-teams-oversubscription -fopenmp-target-fast"
for S in src2 src3; do
  B=b_${ARCH}_${S}; mkdir -p $B
  ls $S/*.f90 | xargs -P 24 -I{} bash -c 'n=$(basename {} .f90); [ -f '"$B"'/$n ] || timeout 900 '"$A"'/lib/llvm/bin/amdflang '"$FF"' -o '"$B"'/$n {} 2>/dev/null || true'
  R=res_${ARCH}_${S}.txt; > $R
  for f in $B/*; do n=$(basename $f); echo "$n | $(timeout 180 ./$f 2>&1 | tr -s ' ' | head -1)" >> $R; done
  echo "[$ARCH/$S] built $(ls $B|wc -l)  PASS $(grep -c ' PASS' $R)  FAIL $(grep -c FAIL $R)  other $(grep -vc 'PASS\|FAIL' $R)"
done
