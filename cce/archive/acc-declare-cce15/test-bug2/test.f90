module mod
implicit none
real, allocatable, dimension(:), target :: cherche
!$acc declare link(cherche)

contains
  subroutine s_init ( ) 
    integer :: i
    allocate(cherche(-5:5))
    !$acc enter data create(cherche)

    !$acc parallel loop
    do i = -5,5
        cherche(i) = i
    end do

    !$acc update host(cherche)
    print*, cherche(:)
    end subroutine s_init
end module mod

program p_main
    use mod
    implicit none
    call s_init()
end program p_main
