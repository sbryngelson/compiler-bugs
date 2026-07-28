; ---------------------------------------------------------------------------
; AMDGPU (gfx90a): a flat pointer built from a private-segment offset WITHOUT
; the private aperture is round-tripped back to addrspace(5).  For the object
; at private frame offset 0 and element index 0 the flat value is literally 0,
; so the legal flat->private lowering
;       select(flat == null, ~0 /* private null */, trunc flat)
; constant-folds to 0xFFFFFFFF and is used as the `offen` voffset of a swizzled
; MUBUF private-segment store.  Effective address = scratch_base + 2^32,
; i.e. 4 GiB outside the scratch allocation -> GPU memory access fault.
;
; This is the pattern the Cray Fortran front end emits for a local array in a
; device routine (`ptrtoint p5 -> zext i32->i64 -> inttoptr to flat -> gep ->
; addrspacecast to p5`).  Exactly ONE alloca so it lands at frame offset 0, and
; a CONSTANT index 0 so the null check folds instead of staying dynamic.
;
; EXPECTED (both CCE 19.0.0 and CCE 21.0.2):
;   s_mov_b32 s<n>, -1        (or s_cselect_b32 s<n>, 0, -1)
;   buffer_store_dword ..., v<n>, s[0:3], 0 offen      with v<n> == 0xFFFFFFFF
;
; REPRODUCE (the cce module does not put llc on PATH):
;   /opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin/llc -O2 -mcpu=gfx90a \
;       repro-p5-null-fold.ll -o out21.s
;   /opt/cray/pe/cce/19.0.0/cce-clang/x86_64/bin/llc -O2 -mcpu=gfx90a \
;       repro-p5-null-fold.ll -o out19.s
;   grep -nE 'offen|, -1|0xffffffff' out21.s out19.s
;
; The companion file repro-p5-null-dyn.ll keeps a DYNAMIC index; there the null
; check survives as a runtime `s_cselect_b32 sN, sM, -1` and the store is only
; wild when the runtime flat value happens to be 0.  MFC's real code hits the
; folded form solely because CCE 21's frame layout placed the array at offset 0.
; ---------------------------------------------------------------------------
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @k(ptr addrspace(1) %out) #0 {
entry:
  %a = alloca [10 x double], align 32, addrspace(5)
  %off = ptrtoint ptr addrspace(5) %a to i32
  %z = zext i32 %off to i64
  %flat = inttoptr i64 %z to ptr
  %g = getelementptr double, ptr %flat, i64 0
  %p5 = addrspacecast ptr %g to ptr addrspace(5)
  store double 1.000000e+00, ptr addrspace(5) %p5, align 8
  %l = load volatile double, ptr addrspace(5) %a, align 8
  store double %l, ptr addrspace(1) %out, align 8
  ret void
}

attributes #0 = { "amdgpu-flat-work-group-size"="1,256" }
