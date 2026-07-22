! flang: lastprivate on any construct containing `distribute` aborts with
! "not yet implemented", unless `simd` is also present.
!   flang -fopenmp --offload-arch=gfx90a -O3 -c repro.f90
subroutine k(a, b, n, last)
  real(8), intent(in)    :: a(*)
  real(8), intent(inout) :: b(*)
  integer, intent(in)    :: n
  real(8), intent(out)   :: last
  integer :: i
  real(8) :: t
  !$omp target teams distribute parallel do lastprivate(t)
  do i = 1, n
     t = a(i) * 2.0d0
     b(i) = t
  end do
  last = t
end subroutine
