! Bug 3 workaround: map the struct hierarchy in order (outer first, then attach
! inner pointers). This resolves the "explicit extension not allowed" abort from
! bug3_nested_pointer_struct_map.f90.
!
! The key is three separate target enter data calls in this order:
!   1. map(to: q)          -- outer struct (no recursive mapping)
!   2. map(to: q%vf)       -- allocatable array, attaches vf pointer on device
!   3. map(to: q%vf(i)%sf) -- pointer data, attaches sf pointer on device
!
! Compile:
!   ifx -fiopenmp -fopenmp-targets=spir64_gen \
!       -Xopenmp-target-backend "-device pvc" \
!       -O2 -o bug3_workaround bug3_workaround.f90
!
! Expected: PASS
! Observed: PASS (workaround confirmed on ifx 2025.1.0 / PVC)

module m_bug3w
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

program bug3_workaround
    use m_bug3w
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
    end do

    ! Workaround: map outer struct first, then attach inner pointers in order
    !$omp target enter data map(to:q)
    !$omp target enter data map(to:q%vf)
    do i = 1, N
        !$omp target enter data map(to:q%vf(i)%sf)
    end do

    call s_run(q, N, NX, NY, out)

    do i = 1, N
        !$omp target exit data map(delete:q%vf(i)%sf)
    end do
    !$omp target exit data map(delete:q%vf)
    !$omp target exit data map(delete:q)

    pass = .true.
    do k = 1, NY; do j = 1, NX
        if (abs(out(j,k) - real(N*(N+1)/2, wp)) > 1.0e-10_wp) then
            pass = .false.
            if (j<=2 .and. k==1) write(*,'(A,2I3,A,F6.2)') 'FAIL j,k=',j,k,' got=',out(j,k)
        end if
    end do; end do

    do i = 1, N
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
