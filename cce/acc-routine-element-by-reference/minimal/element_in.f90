! The SAME defect in the other direction: the array element is the intent(IN)
! actual argument. The callee reads garbage rather than losing a store, so the
! symptom is NaN instead of a stale value. Same trigger, same one-line fix.
!
!   ftn -hacc -O2 element_in.f90 -o element_in && ./element_in
module m_in
  implicit none
  integer, parameter :: wp = kind(1.0d0)
  real(wp), allocatable :: a(:), b(:)
  !$acc declare create(a, b)
contains
  subroutine inner(x, y)
    !$acc routine seq
    real(wp), intent(in)  :: x
    real(wp), intent(out) :: y
    integer :: it
    y = x
    !$acc loop seq            ! <=== same trigger
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program element_in
  use m_in
  implicit none
  integer, parameter :: n = 299
  integer :: k, bad
  real(wp) :: t
  allocate(a(0:n), b(0:n))
  a = [(real(k, wp), k = 0, n)]; b = 0.0_wp
  !$acc update device(a, b)
  !$acc parallel loop private(t)
  do k = 0, n
    call inner(a(k), t)                  ! array element as the intent(in) actual arg
    b(k) = t                             ! scalar out -- this direction is fine
  end do
  !$acc update host(b)
  bad = count(b /= a + 8.0_wp)
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'element in  : bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
  print '(a,i0)', 'BAD=', bad
end program
