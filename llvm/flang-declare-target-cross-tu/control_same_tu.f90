! CONTROL: identical logic, but the device routine and the target region are in
! the SAME translation unit. This passes on every compiler tested, which is what
! makes the cross-TU case above a bug rather than a misuse of declare target.
module mod_c
  implicit none
  integer :: nsz = -999
  !$omp declare target(nsz)
contains
  subroutine set_nsz(v)
    integer, intent(in) :: v
    nsz = v
    !$omp target update to(nsz)
  end subroutine set_nsz

  subroutine probe(ran, seen)
    !$omp declare target
    integer, intent(out) :: ran, seen
    ran = 1
    seen = nsz
  end subroutine probe
end module mod_c

program p
  use mod_c
  implicit none
  integer :: ran(1), seen(1), i
  call set_nsz(42)
  ran = -1; seen = -55555        ! distinct from every other sentinel
  !$omp target teams distribute parallel do map(tofrom: ran, seen)
  do i = 1, 1
     call probe(ran(i), seen(i))
  end do
  print '(A,I0,A,I0)', "control: executed = ", ran(1), "   device saw nsz = ", seen(1)
  if (ran(1) /= 1 .or. seen(1) /= 42) then
     print '(A)', "control FAIL"
     stop 1
  end if
  print '(A)', "control PASS"
end program p
