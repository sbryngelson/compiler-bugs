! If the defect is the missing lane-serialization loop, doing it by hand in
! Fortran -- exactly what CGOpenMPRuntimeGPU emits for C -- should restore
! correct behaviour with the very same critical construct.
program p
  use omp_lib
  integer :: s_plain, s_manual, i, t, tl, me
  character(len=16) :: a
  call get_command_argument(1, a); read(a,*) tl
  s_plain = 0; s_manual = 0

  !$omp target parallel do num_threads(tl) map(tofrom: s_plain)
  do i = 1, tl
     !$omp critical
     s_plain = s_plain + 1
     !$omp end critical
  end do

  !$omp target parallel do num_threads(tl) private(me, t) map(tofrom: s_manual)
  do i = 1, tl
     me = omp_get_thread_num()
     do t = 0, tl - 1
        if (me == t) then
           !$omp critical
           s_manual = s_manual + 1
           !$omp end critical
        end if
     end do
  end do

  print '(A,I5,A,I6,A,I6)', "threads=", tl, "  plain_critical=", s_plain, "  manually_serialized=", s_manual
end program p
