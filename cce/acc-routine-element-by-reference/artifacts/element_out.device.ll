; ModuleID = '_element_out.bc'
source_filename = "The Accel Module"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

@b__cray_acc = common addrspace(1) global [9 x i64] zeroinitializer, align 32
@bitcasted_b__cray_acc = private addrspace(1) global ptr addrspace(1) @b__cray_acc
@bitcasted_b__cray_acc.1 = private addrspace(1) global ptr addrspace(1) @b__cray_acc

; Function Attrs: alwaysinline
define hidden void @"inner$m_out_"(ptr noalias %x, ptr noalias %y) #0 !dbg !14 !scalarlevel !17 !cachelevel !18 !fplevel !17 {
", bb1":
  br label %"file element_out.f90, line 18, bb11", !dbg !19

"file element_out.f90, line 18, bb11": ; preds = %", bb1"
  br label %"file element_out.f90, line 18, bb12", !dbg !19

"file element_out.f90, line 18, bb12": ; preds = %"file element_out.f90, line 18, bb11"
  %r4 = load double, ptr %x, align 8, !dbg !20, !CrayMri !21
  %r5 = fadd double %r4, 8.000000e+00, !dbg !20
  store double %r5, ptr %y, align 8, !dbg !20, !CrayMri !22
  ret void, !dbg !23
}

; Function Attrs: noinline
define amdgpu_kernel void @"element_out_$ck_L38_1"(i64 %"$$arg_dvmbr_p1_t291") #1 !dbg !24 !scalarlevel !17 !cachelevel !18 !fplevel !17 {
", bb54":
  br label %"file element_out.f90, line 38, bb64", !dbg !25

"file element_out.f90, line 38, bb64": ; preds = %", bb54"
  br label %"file element_out.f90, line 39, bb52", !dbg !25

"file element_out.f90, line 39, bb52": ; preds = %"file element_out.f90, line 38, bb64"
  %r = tail call i64 @__ockl_get_local_size(i32 0), !dbg !26
  %r2 = trunc i64 %r to i32, !dbg !26
  %r3 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !26
  %r4 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !26
  %r5 = mul i32 %r3, %r2, !dbg !26
  %r6 = add i32 %r4, %r5, !dbg !26
  %r9 = icmp ugt i32 %r6, 299, !dbg !26
  br i1 %r9, label %"file element_out.f90, line 41, bb63", label %"39utop1", !dbg !26

"39utop1":                                        ; preds = %"file element_out.f90, line 39, bb52"
  br label %"file element_out.f90, line 39, bb7", !dbg !26

"file element_out.f90, line 39, bb7": ; preds = %"39utop1"
  br label %"file element_out.f90, line 41, bb63", !dbg !27

"file element_out.f90, line 41, bb63": ; preds = %"file element_out.f90, line 39, bb7", %"file element_out.f90, line 39, bb52"
  ret void, !dbg !28
}

declare hidden i64 @__ockl_get_local_size(i32)

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #2

attributes #0 = { alwaysinline "device_resident" }
attributes #1 = { noinline "amdgpu-flat-work-group-size"="1,256" "amdgpu-no-completion-action" "kernel" "uniform-work-group-size"="true" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7, !8}
!llvm.dbg.cu = !{!9}
!PDGFunctionMap = !{!11}
!PDGVariableMap = !{!12}
!llvm.ident = !{!13, !13, !13, !13, !13, !13, !13, !13, !13}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{i32 4, !"Dwarf Version", i32 5}
!2 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{i32 8, !"PIC Level", i32 0}
!5 = !{i32 7, !"openmp", i32 51}
!6 = !{i32 7, !"openmp-device", i32 51}
!7 = !{i32 1, !"ThinLTO", i32 0}
!8 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!9 = distinct !DICompileUnit(language: DW_LANG_Fortran90, file: !10, producer: "Cray Fortran : Version 21.0.2", isOptimized: false, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, nameTableKind: None)
!10 = !DIFile(filename: "/lustre/orion/cfd154/scratch/sbryngelson/testbug/cb/cce/acc-routine-element-by-reference/minimal/element_out.f90", directory: "/lustre/orion/cfd154/scratch/sbryngelson/testbug/ir")
!11 = !{i32 7, !"element_out_$ck_L38_1"}
!12 = !{i32 66, ptr addrspace(1) @b__cray_acc}
!13 = !{!"Cray clang version 0.0.0.0  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!14 = distinct !DISubprogram(name: "inner", linkageName: "inner$m_out_", scope: !10, file: !10, line: 18, type: !15, scopeLine: 18, spFlags: DISPFlagDefinition, unit: !9)
!15 = !DISubroutineType(types: !16)
!16 = !{null}
!17 = !{i64 2}
!18 = !{i64 0}
!19 = !DILocation(line: 18, scope: !14)
!20 = !DILocation(line: 26, scope: !14)
!21 = !{i64 34359738370}
!22 = !{i64 18014428574253058}
!23 = !DILocation(line: 28, scope: !14)
!24 = distinct !DISubprogram(name: "element_out_$ck_L38_1", linkageName: "element_out_$ck_L38_1", scope: !10, file: !10, line: 38, type: !15, scopeLine: 38, spFlags: DISPFlagDefinition, unit: !9)
!25 = !DILocation(line: 38, scope: !24)
!26 = !DILocation(line: 39, scope: !24)
!27 = !DILocation(line: 40, scope: !24)
!28 = !DILocation(line: 41, scope: !24)
