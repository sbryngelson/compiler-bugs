#!/bin/bash
# Build a STOCK LLVM matching CCE's base, WITH ASSERTIONS -- the reference compiler that
# makes "is this defect upstream or Cray-side?" answerable.
#
# Why this exists: every vendor-shipped LLVM on Frontier has assertions COMPILED OUT
# (ROCm 6.3.1/7.0.2/7.2.0 all report "assertions=0"). A clean run from one of those cannot
# distinguish "fixed" from "bug not caught", so any attribution argued from them is vacuous.
# CCE's own toolchain has assertions ON, so comparing CCE against ROCm compares apples to
# oranges. This builds the apple.
#
# Usage:
#   ./build-reference-llvm.sh [tag] [tools...]
#     tag    LLVM release tag to build (default llvmorg-21.1.8 = CCE 21.0.2's base;
#            check yours with: ftn --version)
#     tools  ninja targets (default "llc opt"; add "lld" for link-crash work --
#            lld-infer-address-spaces reproduces ONLY through lld, not llc)
#
# Env:
#   SRC   existing llvm-project clone            (default $SCRATCH/llvm-src/llvm-project)
#   ROOT  where to put the source tree and build (default alongside SRC)
#   JOBS  parallelism (default 32 -- login nodes are shared, do not take all cores)
#
# Idempotent: safe to re-run: it resumes from whatever phase it reached.
set -u
TAG=${1:-llvmorg-21.1.8}; shift 2>/dev/null || true
TOOLS=${*:-llc opt}
SCRATCH=${SCRATCH:-$PWD}
SRC=${SRC:-$SCRATCH/llvm-src/llvm-project}
ROOT=${ROOT:-$(dirname "$SRC")}
WT=$ROOT/wt-${TAG#llvmorg-}
B=$ROOT/build-${TAG#llvmorg-}
JOBS=${JOBS:-32}
ROCMC=${ROCMC:-/opt/rocm-7.2.0/llvm/bin}     # host compiler: system gcc 7.5 is too old
module load cmake 2>/dev/null; export PATH="$HOME/.local/bin:$PATH"

[ -d "$SRC/.git" ] || { echo "no clone at $SRC -- set SRC=, or:"; \
  echo "  git clone https://github.com/llvm/llvm-project $SRC"; exit 1; }

# ---- phase 1: source tree ----------------------------------------------------
# `git archive | tar` rather than `git worktree add`: one streaming write, no registration
# that can go stale. A SENTINEL marks completion -- testing for a single source file is not
# enough, because an interrupted checkout leaves some files present and cmake then dies on
# the missing ones (that exact failure cost a run).
if [ ! -f "$WT/.checkout-complete" ]; then
    echo "[1] extracting $TAG (~160k files; minutes on a parallel filesystem)"
    rm -rf "$WT"; mkdir -p "$WT"
    git -C "$SRC" archive --format=tar "$TAG" | tar -x -C "$WT" || { echo "extract failed"; exit 1; }
    for f in llvm/CMakeLists.txt cmake/Modules/CMakePolicy.cmake; do
        [ -f "$WT/$f" ] || { echo "extract incomplete: missing $f"; exit 1; }
    done
    touch "$WT/.checkout-complete"
else
    echo "[1] source tree present"
fi

# ---- phase 2: configure ------------------------------------------------------
if [ ! -f "$B/build.ninja" ]; then
    echo "[2] configuring (assertions ON)"
    cmake -S "$WT/llvm" -B "$B" -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON \
      -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86" \
      -DLLVM_ENABLE_PROJECTS="$(echo "$TOOLS" | grep -qw lld && echo lld)" \
      -DCMAKE_C_COMPILER=$ROCMC/clang -DCMAKE_CXX_COMPILER=$ROCMC/clang++ \
      -DLLVM_USE_LINKER=$ROCMC/ld.lld \
      -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF \
      > "$ROOT/cfg-${TAG#llvmorg-}.log" 2>&1 \
      || { echo "CONFIGURE FAILED:"; tail -25 "$ROOT/cfg-${TAG#llvmorg-}.log"; exit 1; }
else
    echo "[2] already configured"
fi

# ---- phase 3: build ----------------------------------------------------------
echo "[3] building: $TOOLS (resumable)"
# shellcheck disable=SC2086
ninja -C "$B" -j "$JOBS" $TOOLS || { echo "BUILD FAILED"; exit 1; }

a=$("$B/bin/llc" --version 2>/dev/null | grep -ciE 'with assertions')
echo
echo "assertions=$a  (MUST be 1; 0 makes every comparison against this build meaningless)"
[ "$a" = 1 ] || { echo "ABORT: assertions OFF"; exit 1; }
echo "reference tools in $B/bin:"; for t in $TOOLS; do ls -1 "$B/bin/$t" "$B/bin/ld.lld" 2>/dev/null; done | sort -u | sed 's/^/  /'
