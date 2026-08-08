! Identical shape, three protections: none, atomic, critical.
program p
  integer :: s1, s2, s3, i, tl
  character(len=16) :: a
  call get_command_argument(1, a); read(a,*) tl
  s1 = 0; s2 = 0; s3 = 0
  !$omp target parallel do num_threads(tl) map(tofrom: s1)
  do i = 1, tl
     s1 = s1 + 1            ! unprotected: racy, expect << tl
  end do
  !$omp target parallel do num_threads(tl) map(tofrom: s2)
  do i = 1, tl
     !$omp atomic update
     s2 = s2 + 1            ! atomic: must be tl
  end do
  !$omp target parallel do num_threads(tl) map(tofrom: s3)
  do i = 1, tl
     !$omp critical
     s3 = s3 + 1            ! critical: must be tl
     !$omp end critical
  end do
  print '(A,I5,A,I6,A,I6,A,I6)', "threads=", tl, "  none=", s1, "  atomic=", s2, "  critical=", s3
end program p
