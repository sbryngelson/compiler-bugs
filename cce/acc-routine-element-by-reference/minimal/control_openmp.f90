! CONTROL, other offload model: the same shape written in OpenMP is CORRECT.
!
! A `declare target` routine containing an orphaned `!$omp simd` (also tried:
! `!$omp loop bind(thread)`, and no inner directive at all), called from a
! `target teams distribute parallel do` with an array element as the intent(out)
! actual argument. All three spellings give exact results, so this is specific to
! CCE's OpenACC lowering rather than to its device code generation generally.
!
!   ftn -homp -O2 control_openmp.f90 -o control_openmp && ./control_openmp
module m_omp
  implicit none
  integer, parameter :: wp = kind(1.0d0)
  real(wp), allocatable :: b(:)
  !$omp declare target(b)
contains
  subroutine inner(x, y)
    !$omp declare target
    real(wp), intent(in)  :: x
    real(wp), intent(out) :: y
    integer :: it
    y = x
    !$omp simd reduction(+:y)
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program control_openmp
  use m_omp
  implicit none
  integer, parameter :: n = 299
  integer :: k, bad
  allocate(b(0:n)); b = 0.0_wp
  !$omp target update to(b)
  !$omp target teams distribute parallel do
  do k = 0, n
    call inner(real(k, wp), b(k))
  end do
  !$omp target update from(b)
  bad = count(b /= [(real(k, wp) + 8.0_wp, k = 0, n)])
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'openmp      : bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
  print '(a,i0)', 'BAD=', bad
end program
