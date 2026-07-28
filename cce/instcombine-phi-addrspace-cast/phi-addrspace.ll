; CCE 21.0.2 (Cray LLVM 21.1.8): InstCombine's foldIntegerTypedPHI builds a bitcast
; between two different address spaces and trips an assertion in CastInst::Create.
;
;   opt -passes=instcombine phi-addrspace.ll -o /dev/null
;   opt: llvm/lib/IR/Instructions.cpp:3040: static llvm::CastInst*
;        llvm::CastInst::Create(...): Assertion `castIsValid(op, S, Ty) && "Invalid cast!"' failed.
;
; The PHI is typed ptr addrspace(1). One incoming value reaches it through
; ptrtoint/inttoptr from a flat (addrspace 0) pointer, so tracing the incoming
; values back yields pointers in two different address spaces. p0 and p1 are both
; 64-bit, so the size check passes and CreateBitOrPointerCast emits a bitcast --
; but a bitcast between address spaces is not valid IR; it requires addrspacecast.
;
; The empty critical-edge block is load-bearing: branching to %join directly from
; %entry instead does not reproduce.

target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @kernel(i1 %cond, ptr %flat, ptr addrspace(1) %global) {
entry:
  br i1 %cond, label %cast, label %crit_edge

crit_edge:                                        ; preds = %entry
  br label %join

cast:                                             ; preds = %entry
  %i = ptrtoint ptr %flat to i64
  %as1 = inttoptr i64 %i to ptr addrspace(1)
  br label %join

join:                                             ; preds = %cast, %crit_edge
  %p = phi ptr addrspace(1) [ %global, %crit_edge ], [ %as1, %cast ]
  %pi = ptrtoint ptr addrspace(1) %p to i64
  %pf = inttoptr i64 %pi to ptr
  %v = load double, ptr %pf, align 8
  store double %v, ptr null, align 8
  ret void
}
