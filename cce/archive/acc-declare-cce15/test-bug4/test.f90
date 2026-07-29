module m_mod
    type inner_type
        real, allocatable, dimension(:) :: dat
    end type inner_type

    type(inner_type) :: inner

    !$acc declare create(inner)

    integer, parameter :: ndat = 5

contains

    subroutine s_mod_init()

        integer :: i,j

        allocate(inner%dat(1:ndat))
        !$acc enter data create(inner%dat(1:ndat))

    end subroutine s_mod_init

    subroutine s_mod_finalize()

        integer :: i

        !$acc update host (inner%dat(1:ndat))
        print*, 'inner', inner%dat(1:ndat)

    end subroutine s_mod_finalize

end module m_mod

module m_mod2

 use m_mod

 contains

    subroutine s_mod2()

        integer :: i,j,k

        !$acc parallel loop
        do j = 1,ndat
            inner%dat(j) = j
        end do
        !$acc end parallel loop

    end subroutine s_mod2

    subroutine s_seq(ii)
        !$acc routine seq
        integer, intent(in) :: ii

        inner%dat(ii) = 1.23
    end subroutine s_seq

 end module m_mod2

program p_main

    use m_mod
    use m_mod2

    integer :: iv

    call s_mod_init
    call s_mod2()
    !$acc parallel loop
    do iv = 1,ndat
        call s_seq(iv)
    end do
    call s_mod_finalize

end program p_main
