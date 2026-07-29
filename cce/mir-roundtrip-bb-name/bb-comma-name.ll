; Cray names outlined blocks like ", bb71" and "file f.f90, line 12, bb99".
; The MIR printer emits bb.N.<name>: unquoted, so a leading/embedded comma
; produces MIR its own parser rejects.
target triple = "amdgcn-amd-amdhsa"
define amdgpu_kernel void @k(ptr addrspace(1) %o, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %", bb71", label %"file f.f90, line 12, bb99"
", bb71":
  store i32 1, ptr addrspace(1) %o, align 4
  br label %"file f.f90, line 12, bb99"
"file f.f90, line 12, bb99":
  store i32 2, ptr addrspace(1) %o, align 4
  ret void
}
