! CCE 21.0.2 / gfx90a, OpenMP target offload.
!
! A resident allocatable array of a derived type is passed to a routine that
! declares its dummy EXPLICIT-SHAPE with a runtime extent, dimension(n_gp).
! Inside a target region the runtime maps that dummy as 0 bytes and hands back
! the HOST address as the device pointer, so the kernel writes to host memory
! from the GPU.
!
! The identical routine with an ASSUMED-SHAPE dummy, dimension(:), is correct.
module m_gp
    implicit none
    integer, parameter :: wp = selected_real_kind(15, 307)
    type :: gp_t
        integer, dimension(3)  :: loc
        real(wp), dimension(3) :: x
    end type gp_t
    type(gp_t), allocatable :: gps(:)
    integer :: n_gp
    !$acc declare create(n_gp)
contains
    subroutine fill_explicit(a)                      ! dimension(n_gp): runtime extent
        type(gp_t), dimension(n_gp), intent(inout) :: a
        integer :: i
        !$acc parallel loop gang vector default(present)
        do i = 1, n_gp
            a(i)%loc = [i, 2*i, 3*i]
        end do
    end subroutine fill_explicit

    subroutine fill_assumed(a)                       ! dimension(:): carries a descriptor
        type(gp_t), dimension(:), intent(inout) :: a
        integer :: i
        !$acc parallel loop gang vector default(present)
        do i = 1, size(a)
            a(i)%loc = [i, 2*i, 3*i]
        end do
    end subroutine fill_assumed
end module m_gp

program dummyshape
    use m_gp
    implicit none
    character(len=16) :: mode
    integer :: i, nbad
    call get_command_argument(1, mode)
    n_gp = 64
    allocate (gps(n_gp))
    do i = 1, n_gp
        gps(i)%loc = -1
    end do
    !$acc update device(n_gp)
    !$acc enter data copyin(gps)
    if (trim(mode) == 'assumed') then
        call fill_assumed(gps)
    else
        call fill_explicit(gps)
    end if
    !$acc exit data copyout(gps)
    nbad = 0
    do i = 1, n_gp
        if (gps(i)%loc(1) /= i .or. gps(i)%loc(2) /= 2*i .or. gps(i)%loc(3) /= 3*i) nbad = nbad + 1
    end do
    write (*, '(a,a,a,i0,a,i0,a)') 'dummy=', trim(merge('explicit', 'assumed ', trim(mode) /= 'assumed')), &
        '  wrong=', nbad, ' of ', n_gp, merge('   PASS', '   FAIL', nbad == 0)
end program dummyshape
