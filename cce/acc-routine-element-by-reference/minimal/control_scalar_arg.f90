! CONTROL: element_out.f90 with the `!$acc loop seq` KEPT but the result received
! into a scalar and stored afterwards. Correct -- this is the workaround MFC applied.
!
module m_ctl_scalar
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
    !$acc loop seq            ! <=== THE TRIGGER. Delete this line and the answer is right.
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program control_scalar_arg
  use m_ctl_scalar
  implicit none
  integer, parameter :: n = 299
  integer :: k, bad
  real(wp) :: t
  allocate(b(0:n)); b = 0.0_wp
  !$acc update device(b)
  !$acc parallel loop private(t)
  do k = 0, n
    call inner(real(k, wp), t)           ! scalar out ...
    b(k) = t                             ! ... then store. This is the workaround.
  end do
  !$acc update host(b)
  bad = count(b /= [(real(k, wp) + 8.0_wp, k = 0, n)])
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'scalar arg  : bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
  print '(a,i0)', 'BAD=', bad
end program
