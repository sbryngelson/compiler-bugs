module m_mod2

    use m_mod

    contains

    subroutine s_mod2()
        integer :: i,j,k

        !$acc kernels
        do k = 1,nouter
            do j = 1,ndat
                do i = 1,ninner
                    outer(k)%inner(i)%data(j) = i*j
                end do
            end do
        end do
        !$acc end kernels
    end subroutine s_mod2

    subroutine s_faire(myI)
        integer, intent(in) :: myI

        !$acc routine seq
        outer(1)%inner(1)%data(myI) = myI
    end subroutine s_faire

end module m_mod2
