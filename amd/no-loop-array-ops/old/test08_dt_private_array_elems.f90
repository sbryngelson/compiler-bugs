! test08_dt_private_array_elems.f90
!
! Tests whether a PRIVATE derived type with fixed array members
! (not VLAs) survives an OpenMP target parallel loop without memory faults.
! Uses element-by-element filling rather than array constructors.
program test08_dt_private_array_elems
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: N = 50000

    type :: state_t
        real(wp) :: U(7), F(7), U_star(7), F_star(7)
    end type

    real(wp) :: res(N), ref
    type(state_t) :: st
    integer :: i, k, nerr

    res = 0._wp

    !$omp target teams distribute parallel do map(from:res) private(st,k)
    do i = 1, N
        do k = 1, 7
            st%U(k)      = real(k, wp) * real(i, wp) * 0.001_wp
            st%F(k)      = real(k, wp) * real(i, wp) * 0.002_wp
            st%U_star(k) = st%U(k) * 1.1_wp
            st%F_star(k) = st%F(k) + 0.5_wp * (st%U_star(k) - st%U(k))
        end do
        res(i) = st%F_star(1) + st%F_star(7)
    end do
    !$omp end target teams distribute parallel do

    nerr = 0
    do i = 1, N
        ref = (1._wp*real(i,wp)*0.002_wp + 0.5_wp*(1._wp*real(i,wp)*0.001_wp*1.1_wp - 1._wp*real(i,wp)*0.001_wp)) &
            + (7._wp*real(i,wp)*0.002_wp + 0.5_wp*(7._wp*real(i,wp)*0.001_wp*1.1_wp - 7._wp*real(i,wp)*0.001_wp))
        if (abs(res(i) - ref) > 1.e-8_wp * abs(ref)) nerr = nerr + 1
    end do

    if (nerr == 0) then
        print *, "PASS test08: private DT with fixed arr7 members"
    else
        print *, "FAIL test08:", nerr, "errors -- private DT arr7 broken"
        print *, "  cell 1: got", res(1)
    end if
end program test08_dt_private_array_elems
