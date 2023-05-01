module m_mod

    type inner_type
        real, allocatable, dimension(:) :: dat
    end type inner_type

    type(inner_type) :: inner

    integer, parameter :: ndat = 5

contains

    subroutine s_mod_init()

        integer :: i,j

        allocate(inner%dat(1:ndat))

    end subroutine s_mod_init

    subroutine s_mod_finalize()

        print*, 'inner', inner%dat(1:ndat)

    end subroutine s_mod_finalize

end module m_mod

module m_mod2

 use m_mod

 contains

subroutine s_mod2()

    integer :: i,j,k

    do j = 1,ndat
        inner%dat(j) = j
    end do

end subroutine s_mod2

 end module m_mod2

program p_main

    use m_mod
    use m_mod2

    call s_mod_init
    call s_mod2()
    call s_mod_finalize

end program p_main
