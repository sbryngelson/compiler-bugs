! CONTROL: element_out.f90 with the one `!$acc loop seq` line deleted, nothing else
! changed. Correct. This is the whole of the difference between right and wrong.
!
module m_ctl_noloop
  implicit none
  integer, parameter :: wp = kind(1.0d0)
  real(wp), allocatable :: b(:)
  !$acc declare create(b)
contains
  subroutine inner(x, y)
    !$acc routine seq
    real(wp), intent(in)  :: x
    real(wp), intent(out) :: y
    integer :: it
    y = x
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program control_no_loop
  use m_ctl_noloop
  implicit none
  integer, parameter :: n = 299
  integer :: k, bad
  allocate(b(0:n)); b = 0.0_wp
  !$acc update device(b)
  !$acc parallel loop
  do k = 0, n
    call inner(real(k, wp), b(k))        ! array element as the intent(out) actual arg
  end do
  !$acc update host(b)
  bad = count(b /= [(real(k, wp) + 8.0_wp, k = 0, n)])
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'no loop     : bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
  print '(a,i0)', 'BAD=', bad
end program
