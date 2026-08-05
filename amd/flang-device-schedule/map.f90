! schedule(static,C) prescribes which thread runs which iteration. Record the
! mapping and print it; if it does not change with C, the clause is ignored.
program p
  use omp_lib
  implicit none
  integer, parameter :: n = 32
  integer :: tid(n), i
  tid = -1
  !$omp target teams distribute parallel do num_teams(1) thread_limit(8) SCHEDCLAUSE map(tofrom:tid)
  do i = 1, n
     tid(i) = omp_get_thread_num()
  end do
  write(*,'(A,32I3)') "  tid: ", tid
end program
