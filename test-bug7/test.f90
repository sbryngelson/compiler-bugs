program p_main

    use m_mod
    use m_mod2

    integer :: iV

    call s_mod_init
    ! call s_mod2()

    !$acc parallel loop present(outer(1))
    do iV = 1,ndat
        call s_faire(iV)
    end do

    call s_mod_finalize

end program p_main
