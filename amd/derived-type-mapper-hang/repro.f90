! ============================================================================================
! Minimal reproducer: AMD AFAR flang 23.0.0git (gfx90a, OpenMP offload) busy-loops for minutes
! in the offload runtime's per-element custom mapper when a target kernel maps a device-resident
! allocatable array of a FLAT derived type.
!
! ROOT CAUSE
!   flang 23 emits a per-COMPONENT "._omp_default_mapper" for the derived type even though it is
!   flat (no allocatable/pointer components, i.e. trivially bit-copyable). When the kernel maps an
!   array of that type, the runtime invokes the mapper and does N * (#components) per-element
!   component pushes (targetDataBegin -> targetDataMapper -> targetDataBegin, cycling through
!   present-table lookups / SourceInfo string parsing / free). At scale (large array x many kernel
!   invocations) this is a multi-minute host busy-loop (99% CPU, GPU idle).
!
! VERSION-SENSITIVE
!   flang 23 (AMD AFAR drop 23.2.0):  emits the mapper  -> HANG   (this is the regression)
!   flang 22 (rocm-7.2.0 amdflang):   no mapper          -> fast
!   Check:  nm ./a.out | grep omp_mapper   (present in the hanging build, absent in the FIX build)
!
! WORKAROUND
!   defaultmap(present:allocatable) on the kernel -> the allocatable arrays are treated present with
!   NO map entry, so flang generates/invokes no mapper.  (flang accepts only ONE defaultmap clause.)
!
! BUILD (note -cpp is REQUIRED for the -DFIX toggle to take effect on a .f90 file):
!   amdflang -cpp -fopenmp --offload-arch=gfx90a -O3        repro.f90 -o hang && OMP_TARGET_OFFLOAD=MANDATORY ./hang
!   amdflang -cpp -fopenmp --offload-arch=gfx90a -O3 -DFIX  repro.f90 -o fix  && OMP_TARGET_OFFLOAD=MANDATORY ./fix
!   hang: runs for minutes (n=20000, 500 kernel invocations).   fix: completes instantly.
! ============================================================================================
module m
  implicit none
  type :: gp_t                                 ! flat derived type (cf. MFC ghost_point): no ptr/alloc members
     integer :: loc(3), ip_grid(3), id, DB(3)
     real(8) :: ip_loc(3), coeffs(2,2,2), levelset, lsnorm(3)
     logical :: slip
  end type
  type(gp_t), allocatable :: ghost_points(:), gp_park(:,:)
  !$omp declare target(ghost_points)
end module

program r
  use m
  implicit none
  integer :: a, n, s
  n = 20000
  allocate(ghost_points(n), gp_park(n, 3)); ghost_points(:)%id = 7
  !$omp target enter data map(alloc: ghost_points)
  !$omp target enter data map(alloc: gp_park)
  do s = 1, 500                                ! many kernel invocations (cf. per-RK-stage swap/restore)
#ifdef FIX
    !$omp target teams distribute parallel do private(a) firstprivate(n) defaultmap(present:allocatable)
#else
    !$omp target teams distribute parallel do private(a) firstprivate(n)
#endif
    do a = 1, n
      gp_park(a, 1) = ghost_points(a)          ! implicit map of the flat-derived-type arrays -> mapper -> hang
    end do
  end do
  write(*,*) 'returned OK'
end program
