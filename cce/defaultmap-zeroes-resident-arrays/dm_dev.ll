; ModuleID = '_x.bc'
source_filename = "The Accel Module"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

@bare__cray_acc = common addrspace(1) global [15 x i64] zeroinitializer, align 32
@bitcasted_bare__cray_acc = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@dalloc__cray_acc = common addrspace(1) global [15 x i64] zeroinitializer, align 32
@bitcasted_dalloc__cray_acc = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@dptr__cray_acc = addrspace(1) global [15 x i64] [i64 0, i64 32, i64 216172782113849476, i64 562958543355914, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0], align 32
@bitcasted_dptr__cray_acc = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc
@bitcasted_bare__cray_acc.1 = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@bitcasted_dalloc__cray_acc.2 = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@bitcasted_dptr__cray_acc.3 = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc
@bitcasted_bare__cray_acc.4 = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@bitcasted_dalloc__cray_acc.5 = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@bitcasted_dptr__cray_acc.6 = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc
@bitcasted_bare__cray_acc.7 = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@bitcasted_dalloc__cray_acc.8 = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@bitcasted_dptr__cray_acc.9 = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc

; Function Attrs: noinline
define amdgpu_kernel void @"resident_$ck_L45_1"(i64 %"$$arg_ptr_acc_d1_t105_t1951") #0 !dbg !16 !scalarlevel !19 !cachelevel !20 !fplevel !19 {
", bb98":
  %"$_pvt3_d1_t78" = alloca i32, align 4, addrspace(5), !dbg !21
  br label %"file resident_defaultmap.f90, line 45, bb99", !dbg !21

"file resident_defaultmap.f90, line 45, bb99":    ; preds = %", bb98"
  br label %"file resident_defaultmap.f90, line 45, bb100", !dbg !21

"file resident_defaultmap.f90, line 45, bb100":   ; preds = %"file resident_defaultmap.f90, line 45, bb99"
  %r2 = inttoptr i64 %"$$arg_ptr_acc_d1_t105_t1951" to ptr addrspace(1), !dbg !21
  %r3 = load i32, ptr addrspace(1) %r2, align 4, !dbg !21, !CrayMri !22
  store i32 %r3, ptr addrspace(5) %"$_pvt3_d1_t78", align 4, !dbg !21, !CrayMri !23
  %r4 = tail call i64 @__ockl_get_local_size(i32 0), !dbg !24
  %r5 = trunc i64 %r4 to i32, !dbg !24
  %r6 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !24
  %r7 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !24
  %r8 = mul i32 %r6, %r5, !dbg !24
  %r9 = add i32 %r7, %r8, !dbg !24
  %r10 = zext i32 %r9 to i64, !dbg !24
  %r12 = icmp ugt i32 %r9, 4912, !dbg !24
  br i1 %r12, label %"file resident_defaultmap.f90, line 51, bb105", label %"46utop3", !dbg !24

"46utop3":                                        ; preds = %"file resident_defaultmap.f90, line 45, bb100"
  br label %"file resident_defaultmap.f90, line 46, bb102", !dbg !24

"file resident_defaultmap.f90, line 46, bb102":   ; preds = %"46utop3"
  %r16 = udiv i64 %r10, 289, !dbg !24
  %r18 = mul nsw i64 %r16, -289, !dbg !24
  %r21 = add nsw i64 %r10, %r18, !dbg !24
  %r23 = sdiv i64 %r21, 17, !dbg !24
  %r24 = load ptr addrspace(1), ptr addrspace(1) @dptr__cray_acc, align 8, !dbg !25, !CrayMri !26
  %r25 = ptrtoint ptr addrspace(1) %r24 to i64, !dbg !25
  %r26 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 88), align 8, !dbg !25, !CrayMri !27
  %r28 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 72), align 8, !dbg !25, !CrayMri !28
  %r29 = sub i64 %r23, %r28, !dbg !25
  %r30 = mul i64 %r26, %r29, !dbg !25
  %r31 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 112), align 8, !dbg !25, !CrayMri !29
  %r33 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 96), align 8, !dbg !25, !CrayMri !30
  %r34 = sub i64 %r16, %r33, !dbg !25
  %r35 = mul i64 %r31, %r34, !dbg !25
  %r37 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 64), align 8, !dbg !25, !CrayMri !31
  %r39 = mul nsw i64 %r23, -17, !dbg !25
  %r41 = add nsw i64 %r21, %r39, !dbg !25
  %r42 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 48), align 8, !dbg !25, !CrayMri !32
  %r42.neg = sub i64 0, %r42, !dbg !25
  %r43 = add i64 %r41, %r42.neg, !dbg !25
  %r44 = mul i64 %r37, %r43, !dbg !25
  %r46 = inttoptr i64 %r25 to ptr, !dbg !25
  %0 = getelementptr i32, ptr %r46, i64 %r30, !dbg !25
  %1 = getelementptr i32, ptr %0, i64 %r35, !dbg !25
  %r47 = getelementptr i32, ptr %1, i64 %r44, !dbg !25
  %r48 = addrspacecast ptr %r47 to ptr addrspace(1), !dbg !25
  %r49 = load i32, ptr addrspace(1) %r48, align 4, !dbg !25, !CrayMri !33
  %r50 = icmp eq i32 %r49, 0, !dbg !25
  br i1 %r50, label %"file resident_defaultmap.f90, line 51, bb105", label %", bb103", !dbg !25

", bb103":                                        ; preds = %"file resident_defaultmap.f90, line 46, bb102"
  br label %"file resident_defaultmap.f90, line 48, bb104", !dbg !25

"file resident_defaultmap.f90, line 48, bb104":   ; preds = %", bb103"
  %2 = atomicrmw add ptr addrspace(5) %"$_pvt3_d1_t78", i32 1 syncscope("agent") monotonic, align 4, !dbg !34
  br label %"file resident_defaultmap.f90, line 51, bb105", !dbg !34

"file resident_defaultmap.f90, line 51, bb105":   ; preds = %"file resident_defaultmap.f90, line 48, bb104", %"file resident_defaultmap.f90, line 46, bb102", %"file resident_defaultmap.f90, line 45, bb100"
  call void @llvm.amdgcn.s.barrier(), !dbg !35
  br label %"file resident_defaultmap.f90, line 51, bb106", !dbg !35

"file resident_defaultmap.f90, line 51, bb106":   ; preds = %"file resident_defaultmap.f90, line 51, bb105"
  call void @llvm.amdgcn.s.barrier(), !dbg !35
  br label %"file resident_defaultmap.f90, line 51, bb107", !dbg !35

"file resident_defaultmap.f90, line 51, bb107":   ; preds = %"file resident_defaultmap.f90, line 51, bb106"
  ret void, !dbg !35
}

declare hidden i64 @__ockl_get_local_size(i32)

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #1

; Function Attrs: convergent nocallback nofree nounwind willreturn
declare void @llvm.amdgcn.s.barrier() #2

; Function Attrs: noinline
define amdgpu_kernel void @"resident_$ck_L53_4"(i64 %"$$arg_ptr_acc_d2_t107_t1961") #0 !dbg !36 !scalarlevel !19 !cachelevel !20 !fplevel !19 {
", bb109":
  %"$_pvt3_d2_t82" = alloca i32, align 4, addrspace(5), !dbg !37
  br label %"file resident_defaultmap.f90, line 53, bb110", !dbg !37

"file resident_defaultmap.f90, line 53, bb110":   ; preds = %", bb109"
  br label %"file resident_defaultmap.f90, line 53, bb111", !dbg !37

"file resident_defaultmap.f90, line 53, bb111":   ; preds = %"file resident_defaultmap.f90, line 53, bb110"
  %r2 = inttoptr i64 %"$$arg_ptr_acc_d2_t107_t1961" to ptr addrspace(1), !dbg !37
  %r3 = load i32, ptr addrspace(1) %r2, align 4, !dbg !37, !CrayMri !38
  store i32 %r3, ptr addrspace(5) %"$_pvt3_d2_t82", align 4, !dbg !37, !CrayMri !39
  %r4 = tail call i64 @__ockl_get_local_size(i32 0), !dbg !40
  %r5 = trunc i64 %r4 to i32, !dbg !40
  %r6 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !40
  %r7 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !40
  %r8 = mul i32 %r6, %r5, !dbg !40
  %r9 = add i32 %r7, %r8, !dbg !40
  %r10 = zext i32 %r9 to i64, !dbg !40
  %r12 = icmp ugt i32 %r9, 4912, !dbg !40
  br i1 %r12, label %"file resident_defaultmap.f90, line 59, bb116", label %"54utop3", !dbg !40

"54utop3":                                        ; preds = %"file resident_defaultmap.f90, line 53, bb111"
  br label %"file resident_defaultmap.f90, line 54, bb113", !dbg !40

"file resident_defaultmap.f90, line 54, bb113":   ; preds = %"54utop3"
  %r16 = udiv i64 %r10, 289, !dbg !40
  %r19 = mul nsw i64 %r16, -289, !dbg !40
  %r20 = add nsw i64 %r10, %r19, !dbg !40
  %r21 = sdiv i64 %r20, 17, !dbg !40
  %r22 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 88), align 8, !dbg !41, !CrayMri !42
  %r23 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 112), align 8, !dbg !41, !CrayMri !43
  %r24 = load ptr addrspace(1), ptr addrspace(1) @dalloc__cray_acc, align 8, !dbg !41, !CrayMri !44
  %r25 = ptrtoint ptr addrspace(1) %r24 to i64, !dbg !41
  %r28 = add i64 %r22, -17, !dbg !41
  %r29 = mul i64 %r21, %r28, !dbg !41
  %r31 = add i64 %r10, %r29, !dbg !41
  %r32 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 72), align 8, !dbg !41, !CrayMri !45
  %r34 = mul i64 %r22, %r32, !dbg !41
  %r34.neg = mul i64 %r34, -1, !dbg !41
  %r35 = add i64 %r31, %r34.neg, !dbg !41
  %r38 = add i64 %r23, -289, !dbg !41
  %r39 = mul i64 %r16, %r38, !dbg !41
  %r40 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 48), align 8, !dbg !41, !CrayMri !46
  %r42 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 96), align 8, !dbg !41, !CrayMri !47
  %r44 = mul i64 %r23, %r42, !dbg !41
  %r40.neg = sub i64 0, %r40, !dbg !41
  %r44.neg = mul i64 %r44, -1, !dbg !41
  %.neg = add i64 %r40.neg, %r44.neg, !dbg !41
  %r45 = add i64 %r39, %.neg, !dbg !41
  %r47 = inttoptr i64 %r25 to ptr, !dbg !41
  %0 = getelementptr i32, ptr %r47, i64 %r35, !dbg !41
  %r48 = getelementptr i32, ptr %0, i64 %r45, !dbg !41
  %r49 = addrspacecast ptr %r48 to ptr addrspace(1), !dbg !41
  %r50 = load i32, ptr addrspace(1) %r49, align 4, !dbg !41, !CrayMri !48
  %r51 = icmp eq i32 %r50, 0, !dbg !41
  br i1 %r51, label %"file resident_defaultmap.f90, line 59, bb116", label %", bb114", !dbg !41

", bb114":                                        ; preds = %"file resident_defaultmap.f90, line 54, bb113"
  br label %"file resident_defaultmap.f90, line 56, bb115", !dbg !41

"file resident_defaultmap.f90, line 56, bb115":   ; preds = %", bb114"
  %1 = atomicrmw add ptr addrspace(5) %"$_pvt3_d2_t82", i32 1 syncscope("agent") monotonic, align 4, !dbg !49
  br label %"file resident_defaultmap.f90, line 59, bb116", !dbg !49

"file resident_defaultmap.f90, line 59, bb116":   ; preds = %"file resident_defaultmap.f90, line 56, bb115", %"file resident_defaultmap.f90, line 54, bb113", %"file resident_defaultmap.f90, line 53, bb111"
  call void @llvm.amdgcn.s.barrier(), !dbg !50
  br label %"file resident_defaultmap.f90, line 59, bb117", !dbg !50

"file resident_defaultmap.f90, line 59, bb117":   ; preds = %"file resident_defaultmap.f90, line 59, bb116"
  call void @llvm.amdgcn.s.barrier(), !dbg !50
  br label %"file resident_defaultmap.f90, line 59, bb118", !dbg !50

"file resident_defaultmap.f90, line 59, bb118":   ; preds = %"file resident_defaultmap.f90, line 59, bb117"
  ret void, !dbg !50
}

; Function Attrs: noinline
define amdgpu_kernel void @"resident_$ck_L61_7"(i64 %"$$arg_dvmbr_p13_t1971", i64 %"$$arg_dvmbr_p15_t1982", i64 %"$$arg_dvmbr_p17_t1993", i64 %"$$arg_ptr_acc_bare_t109_t2004", i64 %"$$arg_ptr_acc_d3_t111_t2015") #0 !dbg !51 !scalarlevel !19 !cachelevel !20 !fplevel !19 {
", bb120":
  %"$_pvt3_d3_t86" = alloca i32, align 4, addrspace(5), !dbg !52
  br label %"file resident_defaultmap.f90, line 61, bb121", !dbg !52

"file resident_defaultmap.f90, line 61, bb121":   ; preds = %", bb120"
  br label %"file resident_defaultmap.f90, line 59, bb122", !dbg !52

"file resident_defaultmap.f90, line 59, bb122":   ; preds = %"file resident_defaultmap.f90, line 61, bb121"
  %r6 = inttoptr i64 %"$$arg_ptr_acc_d3_t111_t2015" to ptr addrspace(1), !dbg !52
  %r7 = load i32, ptr addrspace(1) %r6, align 4, !dbg !52, !CrayMri !53
  store i32 %r7, ptr addrspace(5) %"$_pvt3_d3_t86", align 4, !dbg !52, !CrayMri !54
  %r8 = tail call i64 @__ockl_get_local_size(i32 0), !dbg !55
  %r9 = trunc i64 %r8 to i32, !dbg !55
  %r10 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !55
  %r11 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !55
  %r12 = mul i32 %r10, %r9, !dbg !55
  %r13 = add i32 %r11, %r12, !dbg !55
  %r14 = zext i32 %r13 to i64, !dbg !55
  %r16 = icmp ugt i32 %r13, 4912, !dbg !55
  br i1 %r16, label %"file resident_defaultmap.f90, line 67, bb127", label %"62utop3", !dbg !55

"62utop3":                                        ; preds = %"file resident_defaultmap.f90, line 59, bb122"
  br label %"file resident_defaultmap.f90, line 62, bb124", !dbg !55

"file resident_defaultmap.f90, line 62, bb124":   ; preds = %"62utop3"
  %r20 = udiv i64 %r14, 289, !dbg !55
  %r23 = mul nsw i64 %r20, -289, !dbg !55
  %r24 = add nsw i64 %r14, %r23, !dbg !55
  %r26 = sdiv i64 %r24, 17, !dbg !55
  %r29 = shl nsw i64 %r26, 2, !dbg !56
  %r31 = sub i64 %r29, %"$$arg_dvmbr_p13_t1971", !dbg !56
  %r43 = inttoptr i64 %"$$arg_ptr_acc_bare_t109_t2004" to ptr, !dbg !56
  %0 = getelementptr i32, ptr %r43, i64 %r31, !dbg !56
  %.idx = mul i64 %"$$arg_dvmbr_p17_t1993", -1764, !dbg !56
  %1 = getelementptr i8, ptr %0, i64 %.idx, !dbg !56
  %.idx51 = mul nuw nsw i64 %r20, 608, !dbg !56
  %2 = getelementptr i8, ptr %1, i64 %.idx51, !dbg !56
  %3 = getelementptr i32, ptr %2, i64 %r14, !dbg !56
  %r44.idx = mul i64 %"$$arg_dvmbr_p15_t1982", -84, !dbg !56
  %r44 = getelementptr i8, ptr %3, i64 %r44.idx, !dbg !56
  %r45 = addrspacecast ptr %r44 to ptr addrspace(1), !dbg !56
  %r46 = load i32, ptr addrspace(1) %r45, align 4, !dbg !56, !CrayMri !57
  %r47 = icmp eq i32 %r46, 0, !dbg !56
  br i1 %r47, label %"file resident_defaultmap.f90, line 67, bb127", label %", bb125", !dbg !56

", bb125":                                        ; preds = %"file resident_defaultmap.f90, line 62, bb124"
  br label %"file resident_defaultmap.f90, line 64, bb126", !dbg !56

"file resident_defaultmap.f90, line 64, bb126":   ; preds = %", bb125"
  %4 = atomicrmw add ptr addrspace(5) %"$_pvt3_d3_t86", i32 1 syncscope("agent") monotonic, align 4, !dbg !58
  br label %"file resident_defaultmap.f90, line 67, bb127", !dbg !58

"file resident_defaultmap.f90, line 67, bb127":   ; preds = %"file resident_defaultmap.f90, line 64, bb126", %"file resident_defaultmap.f90, line 62, bb124", %"file resident_defaultmap.f90, line 59, bb122"
  call void @llvm.amdgcn.s.barrier(), !dbg !59
  br label %"file resident_defaultmap.f90, line 67, bb128", !dbg !59

"file resident_defaultmap.f90, line 67, bb128":   ; preds = %"file resident_defaultmap.f90, line 67, bb127"
  call void @llvm.amdgcn.s.barrier(), !dbg !59
  br label %"file resident_defaultmap.f90, line 67, bb129", !dbg !59

"file resident_defaultmap.f90, line 67, bb129":   ; preds = %"file resident_defaultmap.f90, line 67, bb128"
  ret void, !dbg !59
}

attributes #0 = { noinline "amdgpu-flat-work-group-size"="1,256" "amdgpu-no-completion-action" "kernel" "uniform-work-group-size"="true" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nofree nounwind willreturn }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7, !8}
!llvm.dbg.cu = !{!9}
!PDGFunctionMap = !{!11}
!PDGVariableMap = !{!12, !13, !14}
!llvm.ident = !{!15, !15, !15, !15, !15, !15, !15, !15, !15}

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
!10 = !DIFile(filename: "resident_defaultmap.f90", directory: "/lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/defaultmap-zeroes-resident-arrays")
!11 = !{i32 13, !"resident_$ck_L61_7"}
!12 = !{i32 219, ptr addrspace(1) @bare__cray_acc}
!13 = !{i32 220, ptr addrspace(1) @dalloc__cray_acc}
!14 = !{i32 221, ptr addrspace(1) @dptr__cray_acc}
!15 = !{!"Cray clang version 0.0.0.0  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!16 = distinct !DISubprogram(name: "resident_$ck_L45_1", linkageName: "resident_$ck_L45_1", scope: !10, file: !10, line: 45, type: !17, scopeLine: 45, spFlags: DISPFlagDefinition, unit: !9)
!17 = !DISubroutineType(types: !18)
!18 = !{null}
!19 = !{i64 2}
!20 = !{i64 0}
!21 = !DILocation(line: 45, scope: !16)
!22 = !{i64 5759551144290}
!23 = !{i64 18014866660917602}
!24 = !DILocation(line: 46, scope: !16)
!25 = !DILocation(line: 47, scope: !16)
!26 = !{i64 4045859193194}
!27 = !{i64 4024384356714}
!28 = !{i64 4041564225898}
!29 = !{i64 4028679324010}
!30 = !{i64 4037269258602}
!31 = !{i64 4020089389418}
!32 = !{i64 4032974291306}
!33 = !{i64 8345121456490}
!34 = !DILocation(line: 49, scope: !16)
!35 = !DILocation(line: 51, scope: !16)
!36 = distinct !DISubprogram(name: "resident_$ck_L53_4", linkageName: "resident_$ck_L53_4", scope: !10, file: !10, line: 53, type: !17, scopeLine: 53, spFlags: DISPFlagDefinition, unit: !9)
!37 = !DILocation(line: 53, scope: !36)
!38 = !{i64 5768141078971}
!39 = !{i64 18014875250852283}
!40 = !DILocation(line: 54, scope: !36)
!41 = !DILocation(line: 55, scope: !36)
!42 = !{i64 4054449127874}
!43 = !{i64 4058744095171}
!44 = !{i64 4075923964356}
!45 = !{i64 4067334029764}
!46 = !{i64 4063039062468}
!47 = !{i64 4071628997060}
!48 = !{i64 8353711391172}
!49 = !DILocation(line: 57, scope: !36)
!50 = !DILocation(line: 59, scope: !36)
!51 = distinct !DISubprogram(name: "resident_$ck_L61_7", linkageName: "resident_$ck_L61_7", scope: !10, file: !10, line: 61, type: !17, scopeLine: 61, spFlags: DISPFlagDefinition, unit: !9)
!52 = !DILocation(line: 61, scope: !51)
!53 = !{i64 5793910882852}
!54 = !{i64 18014879545819684}
!55 = !DILocation(line: 62, scope: !51)
!56 = !DILocation(line: 63, scope: !51)
!57 = !{i64 8362301325867}
!58 = !DILocation(line: 65, scope: !51)
!59 = !DILocation(line: 67, scope: !51)
