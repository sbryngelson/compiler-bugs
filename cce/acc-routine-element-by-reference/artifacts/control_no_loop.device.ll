; ModuleID = '_control_no_loop.bc'
source_filename = "The Accel Module"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

@b__cray_acc = common addrspace(1) global [9 x i64] zeroinitializer, align 32
@bitcasted_b__cray_acc = private addrspace(1) global ptr addrspace(1) @b__cray_acc
@bitcasted_b__cray_acc.1 = private addrspace(1) global ptr addrspace(1) @b__cray_acc
@"$sca_b_i0_AMD_LDS_0" = internal addrspace(3) externally_initialized global double poison, align 32

; Function Attrs: alwaysinline
define hidden void @"inner$m_ctl_noloop_"(ptr noalias %x, ptr noalias %y) #0 !dbg !15 !scalarlevel !18 !cachelevel !19 !fplevel !18 {
", bb1":
  br label %"file control_no_loop.f90, line 10, bb22", !dbg !20

"file control_no_loop.f90, line 10, bb22": ; preds = %", bb1"
  %r4 = load double, ptr %x, align 8, !dbg !21, !CrayMri !22
  %r5 = fadd double %r4, 8.000000e+00, !dbg !21
  store double %r5, ptr %y, align 8, !dbg !21, !CrayMri !23
  ret void, !dbg !24
}

; Function Attrs: noinline
define amdgpu_kernel void @"control_no_loop_$ck_L29_1"(i64 %"$$arg_dvmbr_p1_t361") #1 !dbg !25 !scalarlevel !18 !cachelevel !19 !fplevel !18 {
", bb10":
  br label %"file control_no_loop.f90, line 29, bb11", !dbg !26

"file control_no_loop.f90, line 29, bb11": ; preds = %", bb10"
  br label %"file control_no_loop.f90, line 30, bb12", !dbg !26

"file control_no_loop.f90, line 30, bb12": ; preds = %"file control_no_loop.f90, line 29, bb11"
  %r = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !27
  %r2 = zext i32 %r to i64, !dbg !27
  %r4 = icmp ugt i32 %r, 299, !dbg !27
  br i1 %r4, label %"file control_no_loop.f90, line 32, bb27", label %"30utop1", !dbg !27

"30utop1":                                        ; preds = %"file control_no_loop.f90, line 30, bb12"
  br label %"file control_no_loop.f90, line 30, bb14", !dbg !27

"file control_no_loop.f90, line 30, bb14": ; preds = %"30utop1"
  %r9 = sub i64 %r2, %"$$arg_dvmbr_p1_t361", !dbg !28
  %r11 = uitofp i32 %r to double, !dbg !28
  %r12 = load ptr addrspace(1), ptr addrspace(1) @b__cray_acc, align 8, !dbg !28, !CrayMri !29
  %r13 = ptrtoint ptr addrspace(1) %r12 to i64, !dbg !28
  tail call void @llvm.amdgcn.s.barrier(), !dbg !28
  %r14 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !28
  %r15.not = icmp eq i32 %r14, 0, !dbg !28
  br i1 %r15.not, label %", bb15", label %"file control_no_loop.f90, line 30, bb17", !dbg !28

", bb15":                                         ; preds = %"file control_no_loop.f90, line 30, bb14"
  br label %"file control_no_loop.f90, line 31, bb16", !dbg !28

"file control_no_loop.f90, line 31, bb16": ; preds = %", bb15"
  %r21 = inttoptr i64 %r13 to ptr, !dbg !28
  %r22 = getelementptr double, ptr %r21, i64 %r9, !dbg !28
  store double %r11, ptr %r22, align 8, !dbg !28, !CrayMri !30
  br label %"file control_no_loop.f90, line 30, bb17", !dbg !28

"file control_no_loop.f90, line 30, bb17": ; preds = %"file control_no_loop.f90, line 31, bb16", %"file control_no_loop.f90, line 30, bb14"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !28
  %r26 = icmp samesign ugt i32 %r14, 7, !dbg !28
  br i1 %r26, label %"file control_no_loop.f90, line 31, bb20", label %"ipa_lbl$2", !dbg !28

"ipa_lbl$2":                                      ; preds = %"file control_no_loop.f90, line 30, bb17"
  br label %"file control_no_loop.f90, line 31, bb19", !dbg !28

"file control_no_loop.f90, line 31, bb19": ; preds = %"ipa_lbl$2"
  %narrow = add nuw nsw i32 %r14, 1, !dbg !28
  %0 = add nuw nsw i32 %narrow, %r, !dbg !28
  %r33 = uitofp i32 %0 to double, !dbg !28
  %.not = icmp eq i32 %r14, 7, !dbg !28
  br label %"file control_no_loop.f90, line 31, bb20", !dbg !28

"file control_no_loop.f90, line 31, bb20": ; preds = %"file control_no_loop.f90, line 31, bb19", %"file control_no_loop.f90, line 30, bb17"
  %"$pvt2_sca_b_i0_t25.0" = phi double [ 0.000000e+00, %"file control_no_loop.f90, line 30, bb17" ], [ %r33, %"file control_no_loop.f90, line 31, bb19" ], !dbg !28
  %"$$lpsnap_t21.0" = phi i1 [ false, %"file control_no_loop.f90, line 30, bb17" ], [ %.not, %"file control_no_loop.f90, line 31, bb19" ], !dbg !28
  br i1 %"$$lpsnap_t21.0", label %", bb21", label %"file control_no_loop.f90, line 31, bb23", !dbg !28

", bb21":                                         ; preds = %"file control_no_loop.f90, line 31, bb20"
  br label %"file control_no_loop.f90, line 31, bb22", !dbg !28

"file control_no_loop.f90, line 31, bb22": ; preds = %", bb21"
  store double %"$pvt2_sca_b_i0_t25.0", ptr addrspace(3) @"$sca_b_i0_AMD_LDS_0", align 8, !dbg !28, !CrayMri !31
  br label %"file control_no_loop.f90, line 31, bb23", !dbg !28

"file control_no_loop.f90, line 31, bb23": ; preds = %"file control_no_loop.f90, line 31, bb22", %"file control_no_loop.f90, line 31, bb20"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !28
  tail call void @llvm.amdgcn.s.barrier(), !dbg !28
  br i1 %r15.not, label %", bb24", label %"file control_no_loop.f90, line 31, bb26", !dbg !28

", bb24":                                         ; preds = %"file control_no_loop.f90, line 31, bb23"
  br label %"file control_no_loop.f90, line 31, bb25", !dbg !28

"file control_no_loop.f90, line 31, bb25": ; preds = %", bb24"
  %r44 = load double, ptr addrspace(3) @"$sca_b_i0_AMD_LDS_0", align 8, !dbg !28, !CrayMri !32
  %r47 = inttoptr i64 %r13 to ptr, !dbg !28
  %r48 = getelementptr double, ptr %r47, i64 %r9, !dbg !28
  store double %r44, ptr %r48, align 8, !dbg !28, !CrayMri !33
  br label %"file control_no_loop.f90, line 31, bb26", !dbg !28

"file control_no_loop.f90, line 31, bb26": ; preds = %"file control_no_loop.f90, line 31, bb25", %"file control_no_loop.f90, line 31, bb23"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !28
  br label %"file control_no_loop.f90, line 32, bb27", !dbg !28

"file control_no_loop.f90, line 32, bb27": ; preds = %"file control_no_loop.f90, line 31, bb26", %"file control_no_loop.f90, line 30, bb12"
  ret void, !dbg !34
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #2

; Function Attrs: convergent nocallback nofree nounwind willreturn
declare void @llvm.amdgcn.s.barrier() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #2

attributes #0 = { alwaysinline "device_resident" }
attributes #1 = { noinline "amdgpu-flat-work-group-size"="1,256" "amdgpu-no-completion-action" "kernel" "uniform-work-group-size"="true" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { convergent nocallback nofree nounwind willreturn }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7, !8}
!llvm.dbg.cu = !{!9}
!PDGFunctionMap = !{!11}
!PDGVariableMap = !{!12, !13}
!llvm.ident = !{!14, !14, !14, !14, !14, !14, !14, !14, !14}

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
!10 = !DIFile(filename: "/lustre/orion/cfd154/scratch/sbryngelson/testbug/cb/cce/acc-routine-element-by-reference/minimal/control_no_loop.f90", directory: "/lustre/orion/cfd154/scratch/sbryngelson/testbug/ir")
!11 = !{i32 7, !"control_no_loop_$ck_L29_1"}
!12 = !{i32 60, ptr addrspace(1) @b__cray_acc}
!13 = !{i32 116, ptr addrspace(3) @"$sca_b_i0_AMD_LDS_0"}
!14 = !{!"Cray clang version 0.0.0.0  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!15 = distinct !DISubprogram(name: "inner", linkageName: "inner$m_ctl_noloop_", scope: !10, file: !10, line: 10, type: !16, scopeLine: 10, spFlags: DISPFlagDefinition, unit: !9)
!16 = !DISubroutineType(types: !17)
!17 = !{null}
!18 = !{i64 2}
!19 = !{i64 0}
!20 = !DILocation(line: 10, scope: !15)
!21 = !DILocation(line: 17, scope: !15)
!22 = !{i64 34359738370}
!23 = !{i64 18014428574253058}
!24 = !DILocation(line: 19, scope: !15)
!25 = distinct !DISubprogram(name: "control_no_loop_$ck_L29_1", linkageName: "control_no_loop_$ck_L29_1", scope: !10, file: !10, line: 29, type: !16, scopeLine: 29, spFlags: DISPFlagDefinition, unit: !9)
!26 = !DILocation(line: 29, scope: !25)
!27 = !DILocation(line: 30, scope: !25)
!28 = !DILocation(line: 31, scope: !25)
!29 = !{i64 146028888130}
!30 = !{i64 18015682704703633}
!31 = !{i64 18014785056538701}
!32 = !{i64 386547056789}
!33 = !{i64 18015682704703637}
!34 = !DILocation(line: 32, scope: !25)
