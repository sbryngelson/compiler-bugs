! test03_dt_whole_array_ops.f90
! Whole-array intrinsic ops on derived type members inside a target region.
!   v%L = v%R + scalar * (v%L - v%R)   (whole array)
! Known AMD bug pattern: whole-array arithmetic on struct members produces
! silent wrong values.
program test03_dt_whole_array_ops
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: N = 10000

    type :: vec3
        real(wp) :: L(3), R(3)
    end type

    real(wp) :: res(N), ref(N)
    type(vec3) :: v
    real(wp) :: s
    integer :: i, nerr

    res = 0._wp

    !$omp target teams distribute parallel do map(from:res) private(v, s)
    do i = 1, N
        v%L(1) = real(i, wp);     v%L(2) = real(i, wp)*2._wp; v%L(3) = real(i, wp)*3._wp
        v%R(1) = real(i, wp)*0.5_wp; v%R(2) = real(i, wp);   v%R(3) = real(i, wp)*1.5_wp
        s = 0.5_wp
        v%L = v%R + s * (v%L - v%R)   ! whole-array op
        res(i) = v%L(1) + v%L(2) + v%L(3)
    end do
    !$omp end target teams distribute parallel do

    do i = 1, N
        ref(i) = (real(i,wp)*0.5_wp + 0.5_wp*(real(i,wp) - real(i,wp)*0.5_wp)) &
               + (real(i,wp)        + 0.5_wp*(real(i,wp)*2._wp - real(i,wp))) &
               + (real(i,wp)*1.5_wp + 0.5_wp*(real(i,wp)*3._wp - real(i,wp)*1.5_wp))
    end do

    nerr = 0
    do i = 1, N
        if (abs(res(i) - ref(i)) > 1.e-10_wp * abs(ref(i))) nerr = nerr + 1
    end do

    if (nerr == 0) then
        print *, "PASS test03: whole-array ops on derived type members"
    else
        print *, "FAIL test03:", nerr, "errors -- whole-array ops on derived type members"
        print *, "  cell 1: got", res(1), "ref", ref(1)
    end if
end program test03_dt_whole_array_ops
