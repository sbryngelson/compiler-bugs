module vars

  implicit none

  integer, allocatable, dimension ( : ), target :: &
    cherche
  !$acc declare link ( cherche )
contains
  subroutine s_init ( )

  allocate ( cherche ( 1 : 10 ) )
  !$acc enter data create ( cherche )

  !-- Initialize to huge on the host and device
  cherche = huge ( 1 )
  !acc update device ( cherche )

  end subroutine s_init
end module vars

module mod
  use vars, only : cherche
  implicit none
contains
  subroutine s_faire ( myI )
    integer, intent ( in ) :: myI

    !$acc routine seq
    cherche ( myI ) = myI
  end subroutine s_faire
end module mod

program main
  use mod
  use vars

  implicit none

  integer :: iV

  call s_init ( )

  !$acc parallel loop present ( cherche )
  do iV = 1, 10
    call s_faire ( iV )
  end do

  !-- This should print out huge ( )
  print*, 'cherche 1: ', cherche

  !-- This should print 1 to 10
  !$acc update host ( cherche )
  print*, 'cherche 2: ', cherche

end program main
