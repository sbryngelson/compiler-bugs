import struct,sys,re
src,dst=sys.argv[1],sys.argv[2]
d=open(src,'rb').read()
off=None
for m in re.finditer(b'\x7fELF', d):
    o=m.start()
    if o+20<=len(d) and int.from_bytes(d[o+18:o+20],'little')==224:  # EM_AMDGPU
        off=o; break
if off is None:
    print("NO AMDGPU IMAGE FOUND"); sys.exit(2)
sub=d[off:]
e_shoff=struct.unpack_from('<Q',sub,0x28)[0]
e_shnum=struct.unpack_from('<H',sub,0x3c)[0]
e_shentsize=struct.unpack_from('<H',sub,0x3a)[0]
total=e_shoff+e_shnum*e_shentsize
open(dst,'wb').write(sub[:total])
print(f"device image at 0x{off:x}, {total} bytes")
