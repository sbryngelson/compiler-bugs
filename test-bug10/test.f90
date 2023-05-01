module m_mod

    type inner_type
        real, allocatable, dimension(:) :: data
    end type inner_type

    type(inner_type), allocatable, dimension(:) :: inner
    !$acc declare link (inner)

    integer, parameter :: ninner = 10
    integer, parameter :: ndat = 10

    contains

    subroutine s_mod_init()

        integer :: i,j

        allocate(inner(1:ninner))
        do i = 1,ninner
            allocate(inner(i)%data(1:ndat))
        end do

        !$acc enter data copyin(inner)
        do i = 1,ninner
            !$acc enter data copyin(inner(i))
            !$acc enter data create(inner(i)%data(1:ndat))
        end do

    end subroutine s_mod_init

    subroutine s_mod_finalize()

        integer :: i

        do i = 1,ninner
            !$acc update host (inner(i)%data(1:ndat))
            print*, 'inner', i, ':', inner(i)%data(1:ndat)
        end do

    end subroutine s_mod_finalize

end module m_mod

module m_mod2

    use m_mod

    contains

    subroutine s_mod2()
        integer :: i,j

        ! ! !$acc kernels present(inner)
        !$acc kernels default(present)
        do j = 1,ndat
            do i = 1,ninner
                inner(i)%data(j) = i*j
            end do
        end do
        !$acc end kernels
    end subroutine s_mod2

    subroutine s_seq(ii)
        !$acc routine seq
        integer, intent(in) :: ii

        inner(1)%data(ii) = 1.23
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
