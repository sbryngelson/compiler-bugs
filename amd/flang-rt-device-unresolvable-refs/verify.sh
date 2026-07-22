#!/bin/bash
# Verify the defect statically from the shipped archive. No GPU, no reproducer needed.
# Usage: ./verify.sh <path to amdgcn libflang_rt.runtime.a> [llvm-nm]
set -u
A=${1:?path to amdgcn libflang_rt.runtime.a}
NM=${2:-llvm-nm}
echo "archive: $A"
echo
u_tik=$($NM --undefined-only "$A" 2>/dev/null | grep -c DescriptorIoTicket)
d_tik=$($NM --defined-only  "$A" 2>/dev/null | grep -c DescriptorIoTicket)
u_ab=$($NM --undefined-only "$A" 2>/dev/null | grep -c flang_rt_verbose_abort)
d_ab=$($NM --defined-only  "$A" 2>/dev/null | grep -c flang_rt_verbose_abort)
printf "  DescriptorIoTicket    undefined=%s  defined=%s\n" "$u_tik" "$d_tik"
printf "  flang_rt_verbose_abort undefined=%s  defined=%s   (mangled _Z22flang_rt_verbose_abortPKcz => (const char*, ...) => VARIADIC)\n" "$u_ab" "$d_ab"
echo
tmp=$(mktemp -d); trap 'rm -rf $tmp' EXIT; cp "$A" $tmp/ && (cd $tmp && ar x "$(basename "$A")")
echo "  members referencing flang_rt_verbose_abort:"
for f in $tmp/*.o; do $NM --undefined-only "$f" 2>/dev/null | grep -q flang_rt_verbose_abort && echo "    $(basename $f)"; done
echo "  members pulling WorkQueue (and their _Fortran* entry points):"
for f in $tmp/*.o; do
  [ "$(basename $f)" = work-queue.cpp.o ] && continue
  if $NM --undefined-only "$f" 2>/dev/null | grep -q WorkQueue; then
    e=$($NM --defined-only "$f" 2>/dev/null | grep -oE "_Fortran[A-Za-z]+" | sort -u | tr '\n' ' ')
    [ -n "$e" ] && echo "    $(basename $f) -> $e"
  fi
done
