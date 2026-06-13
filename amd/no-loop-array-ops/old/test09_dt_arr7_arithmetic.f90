! test09_dt_arr7_arithmetic.f90
!
! Tests whether PRIVATE rigid derived type with arr7 members supports
! element-wise arithmetic inside a GPU target loop.
! Mirrors the HLLD solver's U/F/U_star/F_star update pattern in MFC.
program test09_dt_arr7_arithmetic
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: N = 50000

    type :: flux_t
        real(wp) :: U(7), F(7), U_star(7), F_star(7), U_double(7)
    end type

    real(wp) :: out_F1(N), out_Fstar7(N), ref_F1(N), ref_Fstar7(N)
    real(wp) :: s_L(N), s_M(N)
    integer :: i, k, nerr

    do i = 1, N
        s_L(i) = -1._wp - 0.001_wp*real(i, wp)
        s_M(i) = 0.1_wp * real(i, wp) * 0.001_wp
    end do

    !$omp target teams distribute parallel do &
    !$omp   map(to:s_L,s_M) map(from:out_F1,out_Fstar7) private(i,k)
    do i = 1, N
        block
            type(flux_t) :: st
            do k = 1, 7
                st%U(k) = real(k, wp) * 0.1_wp
                st%F(k) = real(k, wp) * 0.2_wp
                st%U_star(k) = st%U(k) + s_M(i) * real(k, wp)
            end do
            do k = 1, 7
                st%F_star(k) = st%F(k) + s_L(i)*(st%U_star(k) - st%U(k))
            end do
            out_F1(i)    = st%F(1)
            out_Fstar7(i) = st%F_star(7)
        end block
    end do
    !$omp end target teams distribute parallel do

    do i = 1, N
        ref_F1(i)    = 1._wp * 0.2_wp
        ref_Fstar7(i) = 7._wp*0.2_wp + s_L(i)*((7._wp*0.1_wp + s_M(i)*7._wp) - 7._wp*0.1_wp)
    end do

    nerr = 0
    do i = 1, N
        if (abs(out_F1(i)    - ref_F1(i))    > 1.e-10_wp*abs(ref_F1(i)))    nerr = nerr + 1
        if (abs(out_Fstar7(i) - ref_Fstar7(i)) > 1.e-10_wp*abs(ref_Fstar7(i))) nerr = nerr + 1
    end do

    if (nerr == 0) then
        print *, "PASS test09: arr7 arithmetic in BLOCK construct inside target loop"
    else
        print *, "FAIL test09:", nerr, "errors -- arr7 arithmetic broken"
        print *, "  cell 1 F(1): got", out_F1(1), "ref", ref_F1(1)
        print *, "  cell 1 F_star(7): got", out_Fstar7(1), "ref", ref_Fstar7(1)
    end if
end program test09_dt_arr7_arithmetic
