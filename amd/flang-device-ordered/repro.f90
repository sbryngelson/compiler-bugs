! An ordered region must execute in iteration order. Record the order in which
! iterations enter it; any inversion means the guarantee was not honoured.
program p
  use omp_lib
  implicit none
  integer, parameter :: n = 64
  integer :: seq(n), pos, i, bad
  pos = 0
  seq = -1
  !$omp target parallel do ordered map(tofrom:seq,pos)
  do i = 1, n
     !$omp ordered
     pos = pos + 1
     seq(pos) = i
     !$omp end ordered
  end do
  bad = 0
  do i = 1, n
     if (seq(i) /= i) bad = bad + 1
  end do
  if (bad == 0) then
     print *, "PASS ordered preserved"
  else
     write(*,'(A,I4,A)') "  FAIL: ", bad, " iterations out of order"
     write(*,'(A,16I4)') "  first 16: ", seq(1:16)
  end if
end program
