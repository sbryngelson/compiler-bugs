! Bug 2: Allocatable module-level variable with !$omp declare target is not
! correctly accessible inside declare target device functions on Intel GPU (PVC).
!
! g_coeff is an allocatable array marked declare target. After allocation and
! !$omp target update to(g_coeff) the host values are correctly set, but
! inside a declare target function on the device g_coeff returns zeros.
!
! Note: the non-allocatable variant (fixed-size array) works correctly.
!
! Compile:
!   ifx -fiopenmp -fopenmp-targets=spir64_gen \
!       -Xopenmp-target-backend "-device pvc" \
!       -O2 -o bug2 bug2_allocatable_declare_target.f90
!
! Expected: PASS
! Observed: FAIL (all elements 0.0) or GPU segfault at 0x0

module m_bug2
    implicit none
    integer, parameter :: wp = 8

    real(wp), allocatable :: g_coeff(:)
    !$omp declare target(g_coeff)
contains
    pure function f_apply(x, i) result(y)
        !$omp declare target
        real(wp), intent(in) :: x
        integer,  intent(in) :: i
        real(wp) :: y
        y = g_coeff(i) * x       ! g_coeff read from device — returns 0
    end function

    subroutine s_run(a_in, a_out, n, i_coeff)
        integer,  intent(in)  :: n, i_coeff
        real(wp), intent(in)  :: a_in(n)
        real(wp), intent(out) :: a_out(n)
        integer :: k
        !$omp target teams loop map(to:a_in) map(from:a_out)
        do k = 1, n
            a_out(k) = f_apply(a_in(k), i_coeff)
        end do
    end subroutine
end module

program bug2
    use m_bug2
    implicit none
    integer, parameter :: N = 64
    real(wp) :: a_in(N), a_out(N)
    integer :: k
    logical :: pass

    allocate(g_coeff(4))
    g_coeff(1) = 2.0_wp
    g_coeff(2) = 3.0_wp
    g_coeff(3) = 4.0_wp
    g_coeff(4) = 5.0_wp
    !$omp target update to(g_coeff)

    do k = 1, N; a_in(k) = real(k, wp); end do

    call s_run(a_in, a_out, N, 1)   ! expects a_out(k) = 2 * k

    pass = .true.
    do k = 1, N
        if (abs(a_out(k) - 2.0_wp * real(k, wp)) > 1.0e-12_wp) then
            pass = .false.
            if (k <= 3) write(*,'(A,I4,A,F10.4,A,F10.4)') &
                'FAIL k=',k,' got=',a_out(k),' exp=',2.0_wp*real(k,wp)
        end if
    end do

    !$omp target exit data map(delete:g_coeff)
    deallocate(g_coeff)

    if (pass) then
        write(*,*) 'PASS'
    else
        write(*,*) 'FAIL'
        stop 1
    end if
end program
