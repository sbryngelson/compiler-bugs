! CCE Fortran, gfx90a, OpenACC offload.
!
! A module-resident allocatable array of a derived type is passed to a routine
! whose dummy is EXPLICIT-SHAPE with a runtime extent, dimension(n_gp).  Device
! writes through that dummy are not visible on the host afterwards.
!
! The identical routine with an ASSUMED-SHAPE dummy, dimension(:), is correct.
!
! Run as:  ./dummyshape_acc explicit   -> wrong=64 of 64  FAIL
!          ./dummyshape_acc assumed    -> wrong=0  of 64  PASS
!
! Measured on CCE 21.0.2 AND CCE 19.0.0 -- this is not a 21.x regression.
! See README.md; note in particular that the data mapping is NOT the difference
! (both shapes map the same correct 2560 bytes), so do not describe this as a
! zero-length map without re-measuring.
!
! NOTE: the copy-back here is `update self` + `exit data delete`, not
! `exit data copyout`.  With `declare create` already making gps device-resident,
! an `exit data copyout` only decrements the reference count and transfers 0
! bytes, so BOTH shapes fail and the test isolates nothing.  That is a bug in the
! test, not in the compiler; it is fixed here.
module m_gp
    implicit none
    integer, parameter :: wp = selected_real_kind(15, 307)
    type :: gp_t
        integer, dimension(3)  :: loc
        real(wp), dimension(3) :: x
    end type gp_t
    type(gp_t), allocatable :: gps(:)
    integer :: n_gp
    !$acc declare create(gps, n_gp)
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
    !$acc enter data copyin(gps, n_gp)
    if (trim(mode) == 'assumed') then
        call fill_assumed(gps)
    else
        call fill_explicit(gps)
    end if
    !$acc update self(gps)
    !$acc exit data delete(gps)
    nbad = 0
    do i = 1, n_gp
        if (gps(i)%loc(1) /= i .or. gps(i)%loc(2) /= 2*i .or. gps(i)%loc(3) /= 3*i) nbad = nbad + 1
    end do
    write (*, '(a,a,a,i0,a,i0,a)') 'dummy=', trim(merge('explicit', 'assumed ', trim(mode) /= 'assumed')), &
        '  wrong=', nbad, ' of ', n_gp, merge('   PASS', '   FAIL', nbad == 0)
end program dummyshape
