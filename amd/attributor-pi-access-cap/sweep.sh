#!/bin/bash
# Compile the generated reproducer at several kernel counts and print the victim
# kernel's LDS/scratch/VGPR plus the image-wide LDS histogram. A jump of +512 B
# LDS and added scratch, with the victim's source unchanged, is the bug.
R=${AFAR:-/work1/spencerbryngelson/sbryngelson/software/therock-afar-23.2.1-gfx90a-7.13.0-7357b5084b}
cd "$(dirname "$0")" || exit 1
printf "%-6s %-8s | %s\n" fillers kernels "victim lds / scratch / vgpr   (image LDS histogram)"
for N in "$@"; do
  python3 gen.py "$N" > gen_$N.f90
  $R/bin/amdflang -fopenmp --offload-arch=gfx90a -O3 gen_$N.f90 -o gen_$N 2> gen_$N.err || {
    printf "%-6s %-8s | BUILD FAILED: %s\n" "$N" "?" "$(grep -m1 -i error gen_$N.err | cut -c1-60)"; continue; }
  $R/lib/llvm/bin/llvm-objcopy --dump-section=.llvm.offloading=gen_$N.bin gen_$N /dev/null 2>/dev/null
  python3 - "$N" <<'EOF'
import re, sys, subprocess, collections, os
N = sys.argv[1]
R = os.environ.get("AFAR", "/work1/spencerbryngelson/sbryngelson/software/therock-afar-23.2.1-gfx90a-7.13.0-7357b5084b")
d = open(f"gen_{N}.bin", "rb").read()
o = d.index(b"\x7fELF")
open(f"gen_{N}.elf", "wb").write(d[o:])
notes = subprocess.run([f"{R}/lib/llvm/bin/llvm-readelf", "--notes", f"gen_{N}.elf"],
                       capture_output=True, text=True).stdout
lds = collections.Counter(); vic = None; nk = 0
for e in notes.split("  - .agpr_count:")[1:]:
    g = lambda f: re.search(rf"\.{f}:\s+(\S+)", e).group(1)
    nk += 1
    lds[int(g("group_segment_fixed_size"))] += 1
    if "Pvictim" in g("name"):
        vic = (g("group_segment_fixed_size"), g("private_segment_fixed_size"), g("vgpr_count"))
hist = ", ".join(f"{v}@{k}B" for k, v in sorted(lds.items()))
print("%-6s %-8s | lds=%s scratch=%s vgpr=%s   (%s)" % (N, nk, vic[0], vic[1], vic[2], hist))
EOF
done
