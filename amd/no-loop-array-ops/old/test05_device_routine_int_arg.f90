! test05_device_routine_int_arg.f90
! Tests whether passing an integer argument to a GPU device (declare target)
! subroutine works correctly with AMD flang OpenMP target offload.
! This isolates a pattern used heavily in MFC's Riemann solvers.
program test05_device_routine_int_arg
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: N = 10000

    real(wp) :: res_norm1(N), res_norm2(N), res_norm3(N)
    real(wp) :: rho_in(N), c_in(N), B1(N), B2(N), B3(N)
    integer :: i, nerr_1, nerr_2, nerr_3

    do i = 1, N
        rho_in(i) = 1.0_wp + 0.001_wp*real(i, wp)
        c_in(i) = 0.5_wp + 0.0001_wp*real(i, wp)
        B1(i) = 0.3_wp
        B2(i) = 0.4_wp + 0.0001_wp*real(i, wp)
        B3(i) = 0.2_wp
    end do

    !$omp target teams distribute parallel do &
    !$omp   map(to:rho_in,c_in,B1,B2,B3) map(from:res_norm1)
    do i = 1, N
        call compute_c_fast(rho_in(i), c_in(i), B1(i), B2(i), B3(i), 1, res_norm1(i))
    end do
    !$omp end target teams distribute parallel do

    !$omp target teams distribute parallel do &
    !$omp   map(to:rho_in,c_in,B1,B2,B3) map(from:res_norm2)
    do i = 1, N
        call compute_c_fast(rho_in(i), c_in(i), B1(i), B2(i), B3(i), 2, res_norm2(i))
    end do
    !$omp end target teams distribute parallel do

    !$omp target teams distribute parallel do &
    !$omp   map(to:rho_in,c_in,B1,B2,B3) map(from:res_norm3)
    do i = 1, N
        call compute_c_fast(rho_in(i), c_in(i), B1(i), B2(i), B3(i), 3, res_norm3(i))
    end do
    !$omp end target teams distribute parallel do

    nerr_1 = 0; nerr_2 = 0; nerr_3 = 0
    do i = 1, N
        block
            real(wp) :: ref1, ref2, ref3, B2loc, term
            B2loc = B1(i)**2 + B2(i)**2 + B3(i)**2
            term = c_in(i)**2 + B2loc/rho_in(i)
            ref1 = sqrt(0.5_wp*(term + sqrt(max(0._wp, term**2 - 4._wp*c_in(i)**2*B1(i)**2/rho_in(i)))))
            ref2 = sqrt(0.5_wp*(term + sqrt(max(0._wp, term**2 - 4._wp*c_in(i)**2*B2(i)**2/rho_in(i)))))
            ref3 = sqrt(0.5_wp*(term + sqrt(max(0._wp, term**2 - 4._wp*c_in(i)**2*B3(i)**2/rho_in(i)))))
            if (abs(res_norm1(i) - ref1) > 1.e-10_wp*ref1) nerr_1 = nerr_1 + 1
            if (abs(res_norm2(i) - ref2) > 1.e-10_wp*ref2) nerr_2 = nerr_2 + 1
            if (abs(res_norm3(i) - ref3) > 1.e-10_wp*ref3) nerr_3 = nerr_3 + 1
        end block
    end do

    if (nerr_1 == 0) then
        print *, "PASS test05a: device routine with integer arg norm=1"
    else
        print *, "FAIL test05a:", nerr_1, "errors -- device routine norm=1 broken"
    end if
    if (nerr_2 == 0) then
        print *, "PASS test05b: device routine with integer arg norm=2"
    else
        print *, "FAIL test05b:", nerr_2, "errors -- device routine norm=2 broken"
    end if
    if (nerr_3 == 0) then
        print *, "PASS test05c: device routine with integer arg norm=3"
    else
        print *, "FAIL test05c:", nerr_3, "errors -- device routine norm=3 broken"
    end if

contains

    subroutine compute_c_fast(rho, c, Bx, By, Bz, norm, c_fast)
        !$omp declare target
        real(wp), intent(in)  :: rho, c, Bx, By, Bz
        integer,  intent(in)  :: norm
        real(wp), intent(out) :: c_fast
        real(wp) :: B2loc, Bnorm, term, disc
        B2loc = Bx**2 + By**2 + Bz**2
        if (norm == 1) then
            Bnorm = Bx
        else if (norm == 2) then
            Bnorm = By
        else
            Bnorm = Bz
        end if
        term = c**2 + B2loc/rho
        disc = max(0._wp, term**2 - 4._wp*c**2*(Bnorm**2/rho))
        c_fast = sqrt(0.5_wp*(term + sqrt(disc)))
    end subroutine

end program test05_device_routine_int_arg
