program lp
  implicit none
  integer, parameter :: n = 1000
  real(8) :: a(n), b(n), last
  integer :: i
  do i = 1, n; a(i) = real(i,8); end do
  last = -1
  !$omp target teams distribute parallel do simd lastprivate(last) map(to:a) map(from:b,last)
  do i = 1, n
     last = a(i) * 2.0d0
     b(i) = last
  end do
  print '(a,f10.1,a,f10.1)', ' lastprivate=', last, '  expected=', 2.0d0*real(n,8)
end program
