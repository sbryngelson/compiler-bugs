! test06_dt_member_as_array_arg.f90
! Tests passing a derived type array member as an explicit-shape array argument
! to a GPU device routine. Pattern: call sub(v%L, 3, result)
program test06_dt_member_as_array_arg
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
        v%L(1) = real(i, wp)
        v%L(2) = real(i, wp) * 2._wp
        v%L(3) = real(i, wp) * 3._wp
        call dot3(v%L, v%L, res(i))
    end do
    !$omp end target teams distribute parallel do

    nerr = 0
    do i = 1, N
        if (abs(res(i) - real(i,wp)**2*(1._wp+4._wp+9._wp)) > 1.e-10_wp * res(i)) nerr = nerr + 1
    end do

    if (nerr == 0) then
        print *, "PASS test06: DT member as explicit-shape array arg to device routine"
    else
        print *, "FAIL test06:", nerr, "errors -- DT member as array arg broken"
    end if

contains
    subroutine dot3(a, b, result)
        !$omp declare target
        real(wp), intent(in)  :: a(3), b(3)
        real(wp), intent(out) :: result
        result = a(1)*b(1) + a(2)*b(2) + a(3)*b(3)
    end subroutine
end program test06_dt_member_as_array_arg
