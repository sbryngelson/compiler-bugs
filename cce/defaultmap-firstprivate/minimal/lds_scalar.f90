program p
    implicit none
    integer, parameter :: n = 4096
    real(8) :: a(n), s, e
    real(8) :: t1, t2, t3, t4, t5, t6, t7, t8
    real(8) :: t9, t10, t11, t12, t13, t14, t15, t16
    real(8) :: t17, t18, t19, t20, t21, t22, t23, t24
    real(8) :: t25, t26, t27, t28, t29, t30, t31, t32
    real(8) :: t33, t34, t35, t36, t37, t38, t39, t40
    real(8) :: t41, t42, t43, t44, t45, t46, t47, t48
    real(8) :: t49, t50, t51, t52, t53, t54, t55, t56
    real(8) :: t57, t58, t59, t60, t61, t62, t63, t64
    real(8) :: t65, t66, t67, t68, t69, t70, t71, t72
    real(8) :: t73, t74, t75, t76, t77, t78, t79, t80
    real(8) :: t81, t82, t83, t84, t85, t86, t87, t88
    real(8) :: t89, t90, t91, t92, t93, t94, t95, t96
    integer :: i, bad
    a = 0.0d0
#ifdef EXPLICIT
    !$omp target teams distribute parallel do map(tofrom:a) &
    !$omp   private(s, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31, t32, t33, t34, t35, t36, t37, t38, t39, t40, t41, t42, t43, t44, t45, t46, t47, t48, t49, t50, t51, t52, t53, t54, t55, t56, t57, t58, t59, t60, t61, t62, t63, t64, t65, t66, t67, t68, t69, t70, t71, t72, t73, t74, t75, t76, t77, t78, t79, t80, t81, t82, t83, t84, t85, t86, t87, t88, t89, t90, t91, t92, t93, t94, t95, t96)
#else
    !$omp target teams distribute parallel do map(tofrom:a) defaultmap(firstprivate:scalar)
#endif
    do i = 1, n
        t1 = sqrt(real(i, 8) + 1.0d0)*1.000001d0
        t2 = sqrt(real(i, 8) + 2.0d0)*1.000001d0
        t3 = sqrt(real(i, 8) + 3.0d0)*1.000001d0
        t4 = sqrt(real(i, 8) + 4.0d0)*1.000001d0
        t5 = sqrt(real(i, 8) + 5.0d0)*1.000001d0
        t6 = sqrt(real(i, 8) + 6.0d0)*1.000001d0
        t7 = sqrt(real(i, 8) + 7.0d0)*1.000001d0
        t8 = sqrt(real(i, 8) + 8.0d0)*1.000001d0
        t9 = sqrt(real(i, 8) + 9.0d0)*1.000001d0
        t10 = sqrt(real(i, 8) + 10.0d0)*1.000001d0
        t11 = sqrt(real(i, 8) + 11.0d0)*1.000001d0
        t12 = sqrt(real(i, 8) + 12.0d0)*1.000001d0
        t13 = sqrt(real(i, 8) + 13.0d0)*1.000001d0
        t14 = sqrt(real(i, 8) + 14.0d0)*1.000001d0
        t15 = sqrt(real(i, 8) + 15.0d0)*1.000001d0
        t16 = sqrt(real(i, 8) + 16.0d0)*1.000001d0
        t17 = sqrt(real(i, 8) + 17.0d0)*1.000001d0
        t18 = sqrt(real(i, 8) + 18.0d0)*1.000001d0
        t19 = sqrt(real(i, 8) + 19.0d0)*1.000001d0
        t20 = sqrt(real(i, 8) + 20.0d0)*1.000001d0
        t21 = sqrt(real(i, 8) + 21.0d0)*1.000001d0
        t22 = sqrt(real(i, 8) + 22.0d0)*1.000001d0
        t23 = sqrt(real(i, 8) + 23.0d0)*1.000001d0
        t24 = sqrt(real(i, 8) + 24.0d0)*1.000001d0
        t25 = sqrt(real(i, 8) + 25.0d0)*1.000001d0
        t26 = sqrt(real(i, 8) + 26.0d0)*1.000001d0
        t27 = sqrt(real(i, 8) + 27.0d0)*1.000001d0
        t28 = sqrt(real(i, 8) + 28.0d0)*1.000001d0
        t29 = sqrt(real(i, 8) + 29.0d0)*1.000001d0
        t30 = sqrt(real(i, 8) + 30.0d0)*1.000001d0
        t31 = sqrt(real(i, 8) + 31.0d0)*1.000001d0
        t32 = sqrt(real(i, 8) + 32.0d0)*1.000001d0
        t33 = sqrt(real(i, 8) + 33.0d0)*1.000001d0
        t34 = sqrt(real(i, 8) + 34.0d0)*1.000001d0
        t35 = sqrt(real(i, 8) + 35.0d0)*1.000001d0
        t36 = sqrt(real(i, 8) + 36.0d0)*1.000001d0
        t37 = sqrt(real(i, 8) + 37.0d0)*1.000001d0
        t38 = sqrt(real(i, 8) + 38.0d0)*1.000001d0
        t39 = sqrt(real(i, 8) + 39.0d0)*1.000001d0
        t40 = sqrt(real(i, 8) + 40.0d0)*1.000001d0
        t41 = sqrt(real(i, 8) + 41.0d0)*1.000001d0
        t42 = sqrt(real(i, 8) + 42.0d0)*1.000001d0
        t43 = sqrt(real(i, 8) + 43.0d0)*1.000001d0
        t44 = sqrt(real(i, 8) + 44.0d0)*1.000001d0
        t45 = sqrt(real(i, 8) + 45.0d0)*1.000001d0
        t46 = sqrt(real(i, 8) + 46.0d0)*1.000001d0
        t47 = sqrt(real(i, 8) + 47.0d0)*1.000001d0
        t48 = sqrt(real(i, 8) + 48.0d0)*1.000001d0
        t49 = sqrt(real(i, 8) + 49.0d0)*1.000001d0
        t50 = sqrt(real(i, 8) + 50.0d0)*1.000001d0
        t51 = sqrt(real(i, 8) + 51.0d0)*1.000001d0
        t52 = sqrt(real(i, 8) + 52.0d0)*1.000001d0
        t53 = sqrt(real(i, 8) + 53.0d0)*1.000001d0
        t54 = sqrt(real(i, 8) + 54.0d0)*1.000001d0
        t55 = sqrt(real(i, 8) + 55.0d0)*1.000001d0
        t56 = sqrt(real(i, 8) + 56.0d0)*1.000001d0
        t57 = sqrt(real(i, 8) + 57.0d0)*1.000001d0
        t58 = sqrt(real(i, 8) + 58.0d0)*1.000001d0
        t59 = sqrt(real(i, 8) + 59.0d0)*1.000001d0
        t60 = sqrt(real(i, 8) + 60.0d0)*1.000001d0
        t61 = sqrt(real(i, 8) + 61.0d0)*1.000001d0
        t62 = sqrt(real(i, 8) + 62.0d0)*1.000001d0
        t63 = sqrt(real(i, 8) + 63.0d0)*1.000001d0
        t64 = sqrt(real(i, 8) + 64.0d0)*1.000001d0
        t65 = sqrt(real(i, 8) + 65.0d0)*1.000001d0
        t66 = sqrt(real(i, 8) + 66.0d0)*1.000001d0
        t67 = sqrt(real(i, 8) + 67.0d0)*1.000001d0
        t68 = sqrt(real(i, 8) + 68.0d0)*1.000001d0
        t69 = sqrt(real(i, 8) + 69.0d0)*1.000001d0
        t70 = sqrt(real(i, 8) + 70.0d0)*1.000001d0
        t71 = sqrt(real(i, 8) + 71.0d0)*1.000001d0
        t72 = sqrt(real(i, 8) + 72.0d0)*1.000001d0
        t73 = sqrt(real(i, 8) + 73.0d0)*1.000001d0
        t74 = sqrt(real(i, 8) + 74.0d0)*1.000001d0
        t75 = sqrt(real(i, 8) + 75.0d0)*1.000001d0
        t76 = sqrt(real(i, 8) + 76.0d0)*1.000001d0
        t77 = sqrt(real(i, 8) + 77.0d0)*1.000001d0
        t78 = sqrt(real(i, 8) + 78.0d0)*1.000001d0
        t79 = sqrt(real(i, 8) + 79.0d0)*1.000001d0
        t80 = sqrt(real(i, 8) + 80.0d0)*1.000001d0
        t81 = sqrt(real(i, 8) + 81.0d0)*1.000001d0
        t82 = sqrt(real(i, 8) + 82.0d0)*1.000001d0
        t83 = sqrt(real(i, 8) + 83.0d0)*1.000001d0
        t84 = sqrt(real(i, 8) + 84.0d0)*1.000001d0
        t85 = sqrt(real(i, 8) + 85.0d0)*1.000001d0
        t86 = sqrt(real(i, 8) + 86.0d0)*1.000001d0
        t87 = sqrt(real(i, 8) + 87.0d0)*1.000001d0
        t88 = sqrt(real(i, 8) + 88.0d0)*1.000001d0
        t89 = sqrt(real(i, 8) + 89.0d0)*1.000001d0
        t90 = sqrt(real(i, 8) + 90.0d0)*1.000001d0
        t91 = sqrt(real(i, 8) + 91.0d0)*1.000001d0
        t92 = sqrt(real(i, 8) + 92.0d0)*1.000001d0
        t93 = sqrt(real(i, 8) + 93.0d0)*1.000001d0
        t94 = sqrt(real(i, 8) + 94.0d0)*1.000001d0
        t95 = sqrt(real(i, 8) + 95.0d0)*1.000001d0
        t96 = sqrt(real(i, 8) + 96.0d0)*1.000001d0
        s = t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31 + t32 + t33 + t34 + t35 + t36 + t37 + t38 + t39 + t40 + t41 + t42 + t43 + t44 + t45 + t46 + t47 + t48 + t49 + t50 + t51 + t52 + t53 + t54 + t55 + t56 + t57 + t58 + t59 + t60 + t61 + t62 + t63 + t64 + t65 + t66 + t67 + t68 + t69 + t70 + t71 + t72 + t73 + t74 + t75 + t76 + t77 + t78 + t79 + t80 + t81 + t82 + t83 + t84 + t85 + t86 + t87 + t88 + t89 + t90 + t91 + t92 + t93 + t94 + t95 + t96
        a(i) = s
    end do
    bad = 0
    do i = 1, n
        e = 0.0d0
        do concurrent (integer :: k = 1:96)
        end do
        s = 0.0d0
        block
          integer :: k
          do k = 1, 96
            s = s + sqrt(real(i,8) + real(k,8))*1.000001d0
          end do
        end block
        if (abs(a(i) - s) > 1.0d-6*abs(s)) bad = bad + 1
    end do
    write (*, '(a,i0,a,i0)') 'lds_scalar: wrong = ', bad, ' of ', n
    if (bad == 0) then
        print *, 'PASS'
    else
        print *, 'FAIL'
    end if
end program p
