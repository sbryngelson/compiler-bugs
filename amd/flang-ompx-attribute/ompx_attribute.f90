! Reproducer: ompx_attribute is accepted by clang for C/C++ but is a parse
! error in flang, leaving Fortran OpenMP offload with no way to set per-kernel
! occupancy or launch-bound hints.
!
!   amdflang -fopenmp --offload-arch=gfx90a -O3 ompx_attribute.f90 -o /dev/null
!
! Observed (ROCm 7.2.0, AMD flang 22.0.0git):
!   error: Could not parse ompx_attribute.f90
!   error: expected end of line
!         !$omp target teams distribute parallel do ompx_attribute(...)
!                                                   ^
! Expected: accepted, lowering to the "amdgpu-waves-per-eu" function attribute,
! matching clang's behaviour on ompx_attribute.c.

program p
  implicit none
  real(8) :: a(1000)
  integer :: i
  a = 1.0d0
  !$omp target teams distribute parallel do ompx_attribute(amdgpu_waves_per_eu(4,4))
  do i = 1, 1000
     a(i) = a(i)*2.0d0
  end do
  print *, sum(a)
end program p
