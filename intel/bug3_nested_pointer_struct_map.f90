! Bug 3: Mapping a derived type that contains an allocatable array of derived
! types where each element has a pointer component causes an OpenMP runtime
! abort on Intel GPU (PVC):
!
!   omptarget message: explicit extension not allowed: host address specified
!   is 0x... (240 bytes), but device allocation maps to host at 0x... (120 bytes)
!
! This is the "vector_field -> scalar_field -> sf(:,:,:)" pattern common in
! multi-physics CFD codes (e.g. MFC).
!
! The workaround is to map the struct hierarchy in order (outer first, then
! attach inner pointers):
!   1. map(to: q)             -- outer struct
!   2. map(to: q%vf)          -- allocatable array (attaches pointer)
!   3. map(to: q%vf(i)%sf)    -- pointer data (attaches pointer)
! See bug3_workaround below.
!
! Compile:
!   ifx -fiopenmp -fopenmp-targets=spir64_gen \
!       -Xopenmp-target-backend "-device pvc" \
!       -O2 -o bug3 bug3_nested_pointer_struct_map.f90
!
! Expected: PASS
! Observed: omptarget runtime abort

module m_bug3
    implicit none
    integer, parameter :: wp = 8

    type :: t_scalar_field
        real(wp), pointer :: sf(:,:,:) => null()
    end type

    type :: t_vector_field
        type(t_scalar_field), allocatable :: vf(:)
    end type
contains
    subroutine s_run(q, n, nx, ny, out)
        type(t_vector_field), intent(in) :: q
        integer, intent(in)  :: n, nx, ny
        real(wp), intent(out) :: out(nx, ny)
        integer :: i, j, k
        !$omp target teams loop collapse(2) map(from:out)
        do k = 1, ny
            do j = 1, nx
                out(j,k) = 0.0_wp
                do i = 1, n
                    out(j,k) = out(j,k) + q%vf(i)%sf(j,k,1)
                end do
            end do
        end do
    end subroutine
end module

program bug3
    use m_bug3
    implicit none
    integer, parameter :: N = 2, NX = 8, NY = 8
    type(t_vector_field) :: q
    real(wp) :: out(NX, NY)
    integer :: i, j, k
    logical :: pass

    allocate(q%vf(N))
    do i = 1, N
        allocate(q%vf(i)%sf(NX, NY, 1))
        do k = 1, NY; do j = 1, NX
            q%vf(i)%sf(j,k,1) = real(i, wp)
        end do; end do
        !$omp target enter data map(to:q%vf(i)%sf)  ! mapped without container — causes abort
    end do

    call s_run(q, N, NX, NY, out)   ! ABORT here

    pass = .true.
    do k = 1, NY; do j = 1, NX
        if (abs(out(j,k) - real(N*(N+1)/2, wp)) > 1.0e-10_wp) then
            pass = .false.
            if (j<=2 .and. k==1) write(*,'(A,2I3,A,F6.2)') 'FAIL j,k=',j,k,' got=',out(j,k)
        end if
    end do; end do

    do i = 1, N
        !$omp target exit data map(delete:q%vf(i)%sf)
        deallocate(q%vf(i)%sf)
    end do
    deallocate(q%vf)

    if (pass) then
        write(*,*) 'PASS'
    else
        write(*,*) 'FAIL'
        stop 1
    end if
end program
