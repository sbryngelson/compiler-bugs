! test04_dt_zero_init.f90
! Tests whether private derived type members are zero-initialized correctly
! when accessing members before writing them.
! Some AMD flang versions fail to zero-init private DT stack vars on GPU.
program test04_dt_zero_init
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: N = 10000

    type :: vec3
        real(wp) :: L(3), R(3)
    end type

    real(wp) :: res(N)
    type(vec3) :: v
    integer :: i, nerr

    res = 0._wp

    !$omp target teams distribute parallel do map(from:res) private(v)
    do i = 1, N
        v%L = 0._wp
        v%R = 0._wp
        v%L(1) = real(i, wp)
        res(i) = v%L(1) + v%L(2) + v%L(3) + v%R(1) + v%R(2) + v%R(3)
    end do
    !$omp end target teams distribute parallel do

    nerr = 0
    do i = 1, N
        if (abs(res(i) - real(i, wp)) > 1.e-10_wp * real(i, wp)) nerr = nerr + 1
    end do

    if (nerr == 0) then
        print *, "PASS test04: derived type zero-init of private members"
    else
        print *, "FAIL test04:", nerr, "errors -- DT zero-init broken"
        print *, "  cell 1: got", res(1), "expected", 1._wp
    end if
end program test04_dt_zero_init
