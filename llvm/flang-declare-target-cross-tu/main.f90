program p
  use mod_a
  use mod_b
  implicit none
  integer :: k(1), v(1), i
  call set_nsz(42)
  k = -55555; v = -55555
  !$omp target teams distribute parallel do map(tofrom: k, v)
  do i = 1, 1
     call probe(k(i), v(i))
  end do
  print '(A,I0,A)', "constant store  -> ", k(1), "   (want 12345)"
  print '(A,I0,A)', "module var read -> ", v(1), "   (want 42)"
  if (k(1) /= 12345 .or. v(1) /= 42) then
     print '(A)', "FAIL: declare-target module variable not visible in cross-TU device routine"
     stop 1
  end if
  print '(A)', "PASS"
end program p
