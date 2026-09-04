! THE DEFECT, minimal form: an `!$acc loop` inside an `!$acc routine seq`, called
! from a kernel with an ARRAY ELEMENT as the intent(out) actual argument.
! The routine's store is discarded -- the array keeps its previous contents.
!
! Delete the one marked line and this is correct. Keep it and pass a scalar
! instead (control_scalar_arg.f90) and this is correct. Both are needed.
!
! Single file, one call level, an eight-line callee: nothing here is big enough
! to need inlining, a second translation unit, or a derived type.
!
!   ftn -hacc -O2 element_out.f90 -o element_out && ./element_out
module m_out
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

program element_out
  use m_out
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
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'element out : bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
  print '(a,i0)', 'BAD=', bad
end program
