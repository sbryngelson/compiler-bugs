; Minimal IR for the dropped store. Models Fortran `integer :: idx(3)` (1-based)
; with a runtime index: the GEP subtracts 1 from the index, so the access is at
; a non-zero offset from the alloca base.
;
;   idx(1)=0; idx(2)=0; idx(3)=0
;   idx(nd) = 5*j        <- dynamic store, nd is a runtime value
;   out = idx(1)         <- reads back 0 instead of 5*j
target datalayout = "e-p:64:64-p1:64:64-p5:32:32-i64:64-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @k(ptr addrspace(1) %out, i32 %nd, i32 %val) {
entry:
  %idx = alloca [3 x i32], align 4, addrspace(5)
  ; idx(1..3) = 0
  %p1 = getelementptr inbounds [3 x i32], ptr addrspace(5) %idx, i32 0, i32 0
  store i32 0, ptr addrspace(5) %p1, align 4
  %p2 = getelementptr inbounds [3 x i32], ptr addrspace(5) %idx, i32 0, i32 1
  store i32 0, ptr addrspace(5) %p2, align 4
  %p3 = getelementptr inbounds [3 x i32], ptr addrspace(5) %idx, i32 0, i32 2
  store i32 0, ptr addrspace(5) %p3, align 4
  ; idx(nd) = val   -- Fortran 1-based: element offset is (nd - 1)
  %off = add nsw i32 %nd, -1
  %pd = getelementptr inbounds [3 x i32], ptr addrspace(5) %idx, i32 0, i32 %off
  store i32 %val, ptr addrspace(5) %pd, align 4
  ; out = idx(1)
  %r = load i32, ptr addrspace(5) %p1, align 4
  store i32 %r, ptr addrspace(1) %out, align 4
  ret void
}
