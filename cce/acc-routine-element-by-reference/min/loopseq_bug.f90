! Minimal case (reconstructed from the bisection on Frontier, 2026-09-04): an `!$acc loop seq`
! inside an `!$acc routine seq`, called with an array element as the intent(out) actual argument.
! Delete the `!$acc loop seq` line, or pass a scalar and store it, and the result is correct.
!
!   ftn -hacc -O2 loopseq_bug.f90 -o loopseq_bug && ./loopseq_bug     (-O0 / -O1: correct)
module m
  implicit none
  integer, parameter :: wp = kind(1.0d0)
contains
  subroutine inner(x, y)
    !$acc routine seq
    real(wp), intent(in)  :: x
    real(wp), intent(out) :: y
    integer :: it
    y = x
    !$acc loop seq          ! <-- delete this one line and the result is correct
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program loopseq_bug
  use m
  implicit none
  integer, parameter :: n = 299
  real(wp) :: b(0:n)
  integer :: k
  b = 0.0_wp
  !$acc enter data copyin(b)
  !$acc parallel loop
  do k = 0, n
    call inner(real(k, wp), b(k))     ! array element as the intent(out) actual argument
  end do
  !$acc update host(b)
  print '(a,i5,a,i5,2es14.6)', 'bad ', count(.not. (abs(b - ([(real(k, wp), k = 0, n)] + 8.0_wp)) <= 1.0e-12_wp)), &
    & ' of ', n + 1, b(0), 8.0_wp
end program
