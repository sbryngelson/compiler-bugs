; ModuleID = 'dev.ll'
source_filename = "The Accel Module"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

; Function Attrs: noinline
define amdgpu_kernel void @"v_write_$ck_L10_1"(i64 %"$$arg_ptr_acc_nd_t9_t291", i64 %"$$arg_ptr_acc_out_t11_t302") #0 !dbg !13 !scalarlevel !16 !cachelevel !17 !fplevel !16 {
", bb69":
  %"$$_idx_t8" = freeze <3 x i32> poison
  br label %"file v_write.f90, line 10, bb81", !dbg !18 ; v_write.f90:10

"file v_write.f90, line 10, bb81":                ; preds = %", bb69"
  br label %"file v_write.f90, line 1, bb66", !dbg !18 ; v_write.f90:10

"file v_write.f90, line 1, bb66":                 ; preds = %"file v_write.f90, line 10, bb81"
  %r = tail call i64 @__ockl_get_local_size(i32 0), !dbg !19 ; v_write.f90:11
  %r3 = trunc i64 %r to i32, !dbg !19 ; v_write.f90:11
  %r4 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !19 ; v_write.f90:11
  %r5 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !19 ; v_write.f90:11
  %r6 = mul i32 %r4, %r3, !dbg !19 ; v_write.f90:11
  %r7 = add i32 %r5, %r6, !dbg !19 ; v_write.f90:11
  %r8 = zext i32 %r7 to i64, !dbg !19 ; v_write.f90:11
  %r10 = icmp ugt i32 %r7, 63, !dbg !19 ; v_write.f90:11
  br i1 %r10, label %"file v_write.f90, line 16, bb80", label %"11utop1", !dbg !19 ; v_write.f90:11

"11utop1":                                        ; preds = %"file v_write.f90, line 1, bb66"
  br label %"file v_write.f90, line 11, bb10", !dbg !19 ; v_write.f90:11

"file v_write.f90, line 11, bb10":                ; preds = %"11utop1"
  %0 = insertelement <3 x i32> %"$$_idx_t8", i32 0, i32 0, !dbg !20 ; v_write.f90:12
  %r14 = mul nuw nsw i32 %r7, 5, !dbg !21 ; v_write.f90:13
  %r16 = add nuw nsw i32 %r14, 5, !dbg !21 ; v_write.f90:13
  %r18 = inttoptr i64 %"$$arg_ptr_acc_nd_t9_t291" to ptr addrspace(1), !dbg !21 ; v_write.f90:13
  %r19 = load i32, ptr addrspace(1) %r18, align 4, !dbg !21, !CrayMri !22 ; v_write.f90:13
  %1 = add i32 1073741823, %r19, !dbg !21 ; v_write.f90:13
  %2 = insertelement <3 x i32> %0, i32 %r16, i32 %1, !dbg !21 ; v_write.f90:13
  %3 = extractelement <3 x i32> %2, i32 0, !dbg !23 ; v_write.f90:14
  %r25 = inttoptr i64 %"$$arg_ptr_acc_out_t11_t302" to ptr, !dbg !23 ; v_write.f90:14
  %r26 = getelementptr i32, ptr %r25, i64 %r8, !dbg !23 ; v_write.f90:14
  %r27 = addrspacecast ptr %r26 to ptr addrspace(1), !dbg !23 ; v_write.f90:14
  store i32 %3, ptr addrspace(1) %r27, align 4, !dbg !23, !CrayMri !24 ; v_write.f90:14
  br label %"file v_write.f90, line 16, bb80", !dbg !23 ; v_write.f90:14

"file v_write.f90, line 16, bb80":                ; preds = %"file v_write.f90, line 11, bb10", %"file v_write.f90, line 1, bb66"
  ret void, !dbg !25 ; v_write.f90:16
}

declare hidden i64 @__ockl_get_local_size(i32) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #2

attributes #0 = { noinline "amdgpu-flat-work-group-size"="1,256" "amdgpu-no-completion-action" "kernel" "target-cpu"="gfx90a" "uniform-work-group-size"="true" }
attributes #1 = { "target-cpu"="gfx90a" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) "target-cpu"="gfx90a" }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7, !8}
!llvm.dbg.cu = !{!9}
!PDGFunctionMap = !{!11}
!llvm.ident = !{!12, !12, !12, !12, !12, !12, !12, !12, !12}

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
!10 = !DIFile(filename: "v_write.f90", directory: "/lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/promote-alloca-dropped-store")
!11 = !{i32 5, !"v_write_$ck_L10_1"}
!12 = !{!"Cray clang version 0.0.0.0  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!13 = distinct !DISubprogram(name: "v_write_$ck_L10_1", linkageName: "v_write_$ck_L10_1", scope: !10, file: !10, line: 10, type: !14, scopeLine: 10, spFlags: DISPFlagDefinition, unit: !9)
!14 = !DISubroutineType(types: !15)
!15 = !{null}
!16 = !{i64 2}
!17 = !{i64 0}
!18 = !DILocation(line: 10, scope: !13)
!19 = !DILocation(line: 11, scope: !13)
!20 = !DILocation(line: 12, scope: !13)
!21 = !DILocation(line: 13, scope: !13)
!22 = !{i64 1610612736097}
!23 = !DILocation(line: 14, scope: !13)
!24 = !{i64 18016017712152674}
!25 = !DILocation(line: 16, scope: !13)
