module m_mod

    type inner_type
        real, allocatable, dimension(:) :: data
    end type inner_type

    type outer_type
        type(inner_type), allocatable, dimension(:) :: inner
    end type outer_type

    type(outer_type) :: outer

    integer, parameter :: ninner = 2
    integer, parameter :: ndat = 2

contains

    subroutine s_mod_init()

        integer :: i,j

        allocate(outer%inner(1:ninner))
        do i = 1,ninner
            allocate(outer%inner(i)%data(1:ndat))
        end do

        !$acc enter data copyin(outer)
        !$acc enter data copyin(outer%inner)
        do i = 1,ninner
            !$acc enter data copyin(outer%inner(i))
            !$acc enter data create(outer%inner(i)%data(1:ndat))
        end do

    end subroutine s_mod_init

    subroutine s_mod_finalize()

        integer :: i

        do i = 1,ninner
            !$acc update host (outer%inner(i)%data(1:ndat))
            print*, 'inner', i, outer%inner(i)%data(1:ndat)
        end do

    end subroutine s_mod_finalize

end module m_mod

module m_mod2

use m_mod

contains

subroutine s_mod2()

    integer :: i,j,k

    !$acc kernels
    do j = 1,ndat
        do i = 1,ninner
            outer%inner(i)%data(j) = i*j
        end do
    end do
    !$acc end kernels

end subroutine s_mod2

end module m_mod2

program p_main

    use m_mod
    use m_mod2

    call s_mod_init
    call s_mod2()
    call s_mod_finalize

end program p_main
