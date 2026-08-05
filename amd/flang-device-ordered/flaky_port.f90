! Fortran port of offload/test/offloading/schedule.c (the ordered_example part),
! which upstream ships as a passing offload runtime test.
program p
  use omp_lib
  implicit none
  integer, parameter :: lb = 0, ub = 100, stride = 1, nteams = 8
  integer, parameter :: sz = (ub - lb) / stride
  real(8) :: output(sz)
  integer :: i, j, jj, bad
  output = 0.0d0
  !$omp target teams map(from:output) num_teams(nteams) thread_limit(128)
  !$omp parallel do ordered schedule(dynamic)
  do i = lb, ub - 1, stride
     !$omp ordered
     output((i - lb)/stride + 1) = omp_get_wtime()
     !$omp end ordered
  end do
  !$omp end target teams
  bad = 0
  do j = 1, sz
     do jj = j + 1, sz
        if (output(j) > output(jj)) bad = bad + 1
     end do
  end do
  if (bad == 0) then
     print *, "test ordered OK"
  else
     print '(A,I6,A)', "  Fail to schedule in order: ", bad, " inversions"
  end if
end program
