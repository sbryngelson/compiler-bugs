! OpenMPOpt asserts in an assertions-enabled build when a *reachable* target
! region contains a parallel region:
!   OpenMPOpt.cpp:4273: changeToSPMDMode:
!     Assertion `omp::isOpenMPKernel(*Kernel) && "Expected kernel function!"' failed.
!
!   flang -fc1 -emit-llvm -fopenmp -fopenmp-is-target-device \
!         -triple amdgcn-amd-amdhsa -O1 -o - repro.f90
!
! Release builds compile this fine; only assertions builds abort.
module m
contains
  subroutine k(a, b, n)
    real(8), intent(in)    :: a(*)
    real(8), intent(inout) :: b(*)
    integer, intent(in)    :: n
    integer :: i
    !$omp target teams distribute parallel do
    do i = 1, n
       b(i) = a(i) * 2.0d0
    end do
  end subroutine
end module

program p
  use m
  implicit none
  integer, parameter :: n = 64
  real(8) :: a(n), b(n)
  a = 1; b = 0
  call k(a, b, n)
  print *, b(1)
end program
