! Reproducer: flang leaves the body of an OpenMP target region in a separate
! device function that the inliner then declines, so it is register-allocated
! without the enclosing kernel's occupancy target.
!
! Compare with outlined_region.c -- identical arithmetic and loop structure --
! which clang inlines into the kernel.
!
!   amdflang -fopenmp --offload-arch=gfx90a -O3 \
!            -Rpass-analysis=kernel-resource-usage outlined_region.f90 -o /dev/null
!
! Observed (upstream flang 24.0.0git): VGPRs 212, ScratchSize 48 B/lane, occupancy 2
! clang on outlined_region.c:          VGPRs  80, ScratchSize  0 B/lane, occupancy 6
!
! The inliner's decision is the defect:
!   'kern__l23..omp_par.2' not inlined ... because too costly (cost=1280, threshold=495)

subroutine kern(a, b, n)
  implicit none
  integer, parameter :: M = 16
  real(8), intent(in)    :: a(*)
  real(8), intent(inout) :: b(*)
  integer, intent(in)    :: n
  integer  :: i, k
  real(8)  :: t(M), u(M)
  real(8)  :: rk

  !$omp target teams distribute parallel do private(t,u,k,rk)
  do i = 1, n
     do k = 1, M
        rk   = real(k, 8)
        t(k) = (2.0d0*a(i) - 7.0d0*rk)/6.0d0 + 0.25d0*(a(i) - rk)*(a(i) - rk)
        u(k) = (2.0d0*rk - 7.0d0*a(i))/6.0d0 + 0.25d0*(rk - a(i))*(rk - a(i))
     end do
     do k = 2, M
        t(1) = t(1) + t(k)*u(k)
     end do
     b(i) = t(1) + u(1) + t(2)*u(3) + t(4)/u(5)
  end do
end subroutine kern

program p
  implicit none
  real(8) :: a(1024), b(1024)
  a = 1.0d0
  call kern(a, b, 1024)
  print *, b(1)
end program p
