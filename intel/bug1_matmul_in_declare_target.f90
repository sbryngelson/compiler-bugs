! Bug 1: matmul() inside a !$omp declare target subroutine gives wrong results
! on Intel GPU (PVC / spir64_gen) with ifx OpenMP target offload.
!
! The subroutine s_apply is marked declare target and calls matmul() on a
! module-level matrix g_A that is also declare target. On CPU the result is
! correct; on Intel GPU every output element is 0.
!
! Workaround: replace matmul(g_A, v) with explicit dot-product expansion.
!
! Compile:
!   ifx -fiopenmp -fopenmp-targets=spir64_gen \
!       -Xopenmp-target-backend "-device pvc" \
!       -O2 -o bug1 bug1_matmul_in_declare_target.f90
!
! Expected: PASS
! Observed: FAIL (all elements 0.0)

module m_bug1
    implicit none
    integer, parameter :: wp = 8
    real(wp) :: g_A(3, 3)
    !$omp declare target(g_A)
contains
    subroutine s_apply(v_in, v_out)
        !$omp declare target
        real(wp), intent(in)  :: v_in(3)
        real(wp), intent(out) :: v_out(3)
        v_out = matmul(g_A, v_in)
    end subroutine

    subroutine s_run(v_in, v_out, n)
        integer,  intent(in)  :: n
        real(wp), intent(in)  :: v_in(3, n)
        real(wp), intent(out) :: v_out(3, n)
        real(wp) :: tmp_in(3), tmp_out(3)
        integer :: k
        !$omp target teams loop map(to:v_in) map(from:v_out) private(tmp_in, tmp_out)
        do k = 1, n
            tmp_in  = v_in(:, k)
            call s_apply(tmp_in, tmp_out)
            v_out(:, k) = tmp_out
        end do
    end subroutine
end module

program bug1
    use m_bug1
    implicit none
    integer, parameter :: N = 64
    real(wp) :: v_in(3, N), v_out(3, N)
    integer :: k, i
    logical :: pass

    ! Identity matrix — so v_out should equal v_in exactly
    g_A = 0.0_wp
    do i = 1, 3; g_A(i, i) = 1.0_wp; end do
    !$omp target update to(g_A)

    do k = 1, N
        do i = 1, 3; v_in(i, k) = real(i + k, wp); end do
    end do

    call s_run(v_in, v_out, N)

    pass = .true.
    do k = 1, N
        do i = 1, 3
            if (abs(v_out(i,k) - v_in(i,k)) > 1.0e-12_wp) then
                pass = .false.
                if (k <= 2) write(*,'(A,2I3,A,F10.4,A,F10.4)') &
                    'FAIL i,k=',i,k,' got=',v_out(i,k),' exp=',v_in(i,k)
            end if
        end do
    end do

    if (pass) then
        write(*,*) 'PASS'
    else
        write(*,*) 'FAIL'
        stop 1
    end if
end program
