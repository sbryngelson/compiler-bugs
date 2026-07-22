! upstream flang, gfx90a: a scalar OpenMP reduction in a target region emits a
! !dbg whose scope is the enclosing kernel's DISubprogram rather than the
! outlined function's own, so the module fails LLVM verification during the
! device LTO link. Needs -g (or anything else that runs the verifier) at -O1+.
!   flang -fopenmp --offload-arch=gfx90a -O2 -g reduction_dbg_verifier.f90
subroutine k(a, n, s)
  real(8), intent(in)  :: a(*)
  integer, intent(in)  :: n
  real(8), intent(out) :: s
  integer :: i
  s = 0
  !$omp target teams distribute parallel do reduction(+:s)
  do i = 1, n
     s = s + a(i)
  end do
end subroutine

program drv
  implicit none
  integer, parameter :: n = 1024
  real(8) :: a(n), s
  a = 1
  call k(a, n, s)
  print *, s
end program
