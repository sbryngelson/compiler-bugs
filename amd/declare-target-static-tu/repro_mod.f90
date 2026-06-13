! TU 1: the three declare-target variables and the kernel that reads them.
!   s_sc  static scalar   stale across TU
!   s_ar  static array    stale across TU (storage class, not array-ness)
!   a_ar  allocatable      correct
! Kernel runs here; the host->device update is in repro_main, a separate TU.
module repro_mod
   implicit none
   integer              :: s_sc       ! static scalar, declare target
   integer              :: s_ar(1)    ! static array,  declare target
   integer, allocatable :: a_ar(:)    ! allocatable,   declare target
   !$omp declare target(s_sc)
   !$omp declare target(s_ar)
   !$omp declare target(a_ar)
contains
   subroutine kernel(out)
      integer, intent(out) :: out(3)
      !$omp target map(from: out)
      out(1) = s_sc       ! expect 2 ; AMD flang reads 0
      out(2) = s_ar(1)    ! expect 2 ; AMD flang reads 0
      out(3) = a_ar(1)    ! expect 2 ; correct
      !$omp end target
   end subroutine
end module repro_mod
