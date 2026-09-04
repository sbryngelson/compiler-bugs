! The defect is NOT confined to code of doubtful validity.
!
! An `!$acc loop` in a `routine seq` is arguably meaningless -- a seq routine generates no
! parallelism -- so a reader might dismiss element_out.f90 as invalid input. This file is
! not dismissible: an `!$acc loop vector` inside an `!$acc routine vector`, called from a
! gang-partitioned loop, is textbook conforming OpenACC. It is miscompiled identically.
!
! All four routine levels fail the same way (seq, vector, worker, gang).
!
!   ftn -hacc -O2 legal_routine_vector.f90 -o legal_routine_vector && ./legal_routine_vector
module m_vec
  implicit none
  integer, parameter :: wp = kind(1.0d0)
  real(wp), allocatable :: b(:)
  !$acc declare create(b)
contains
  subroutine inner(x, y)
    !$acc routine vector
    real(wp), intent(in)  :: x
    real(wp), intent(out) :: y
    integer :: it
    y = x
    !$acc loop vector         ! <=== conforming here, and still miscompiled
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program legal_routine_vector
  use m_vec
  implicit none
  integer, parameter :: n = 299
  integer :: k, bad
  allocate(b(0:n)); b = 0.0_wp
  !$acc update device(b)
  !$acc parallel loop gang
  do k = 0, n
    call inner(real(k, wp), b(k))        ! array element as the intent(out) actual arg
  end do
  !$acc update host(b)
  bad = count(b /= [(real(k, wp) + 8.0_wp, k = 0, n)])
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'legal vector: bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
  print '(a,i0)', 'BAD=', bad
end program
