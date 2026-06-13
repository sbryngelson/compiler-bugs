! Bug 4: Allocatable module-level variable with !$omp declare target accessed
! inside a !$omp declare target function causes a GPU segfault (null pointer
! dereference) on Intel GPU (PVC).
!
! The variable is allocated on host, its data is copied via
! !$omp target update to(...), but on device the pointer is null — accessing
! it in a declare target function faults at address 0x0.
!
!   Segmentation fault from GPU at 0x0, ctx_id: 1 (CCS) type: 0 (NotPresent),
!   level: 3 (PML4), access: 0 (Read), banned: 1, aborting.
!
! Note: non-allocatable module variables with declare target work correctly.
!
! Compile:
!   ifx -fiopenmp -fopenmp-targets=spir64_gen \
!       -Xopenmp-target-backend "-device pvc" \
!       -O2 -o bug4 bug4_allocatable_declare_target_segfault.f90
!
! Expected: PASS
! Observed: GPU segfault at address 0x0

module m_bug4
    implicit none
    integer, parameter :: wp = 8

    real(wp) :: g_gamma               ! scalar — works correctly
    real(wp), allocatable :: g_gamma_fluid(:)  ! allocatable — crashes
    !$omp declare target(g_gamma, g_gamma_fluid)
contains
    pure function f_pressure(rho_e, i_fluid) result(p)
        !$omp declare target
        real(wp), intent(in) :: rho_e
        integer,  intent(in) :: i_fluid
        real(wp) :: p
        p = (g_gamma_fluid(i_fluid) - 1.0_wp) * rho_e   ! segfault: g_gamma_fluid null on device
    end function

    subroutine s_run(rho_e, out, n)
        integer,  intent(in)  :: n
        real(wp), intent(in)  :: rho_e(n)
        real(wp), intent(out) :: out(n)
        integer :: k
        !$omp target teams loop map(to:rho_e) map(from:out)
        do k = 1, n
            out(k) = f_pressure(rho_e(k), 1)
        end do
    end subroutine
end module

program bug4
    use m_bug4
    implicit none
    integer, parameter :: N = 64
    real(wp) :: rho_e(N), out(N)
    integer :: k
    logical :: pass

    g_gamma = 1.4_wp
    !$omp target update to(g_gamma)

    allocate(g_gamma_fluid(2))
    g_gamma_fluid(1) = 1.4_wp
    g_gamma_fluid(2) = 1.6_wp
    !$omp target update to(g_gamma_fluid)   ! device pointer remains null

    do k = 1, N; rho_e(k) = real(k, wp) * 1.0e4_wp; end do

    call s_run(rho_e, out, N)   ! GPU segfault here

    pass = .true.
    do k = 1, N
        if (abs(out(k) - 0.4_wp * rho_e(k)) > abs(0.4_wp * rho_e(k)) * 1.0e-12_wp) then
            pass = .false.
            if (k <= 3) write(*,'(A,I4,A,E14.8,A,E14.8)') &
                'FAIL k=',k,' got=',out(k),' exp=',0.4_wp*rho_e(k)
        end if
    end do

    !$omp target exit data map(delete:g_gamma_fluid)
    deallocate(g_gamma_fluid)

    if (pass) then
        write(*,*) 'PASS'
    else
        write(*,*) 'FAIL'
        stop 1
    end if
end program
