! Minimal reproducer for the WENO-kernel accumulator-VGPR blowup on amdflang (gfx90a).
! Models MFC's non-case-optimized s_weno inner kernel: fixed-max-size private arrays
! (0:4) indexed by RUNTIME loop bound `ns` (= weno_num_stencils), multiple weight
! schemes, and (optionally) a whole-array slice-copy central path.
!
! Build one variant at a time; read register usage WITHOUT running via ELF notes:
!   amdflang -cpp -fopenmp --offload-arch=gfx90a -O3 [-DVARIANT] repro.f90 -o r
!   <drop>/lib/llvm/bin/llvm-objcopy --dump-section=.llvm.offloading=o.bin r
!   python extract-elf ... ; llvm-readobj --notes dev.elf | grep -A4 sweep
! (or run with LIBOMPTARGET_KERNEL_TRACE=1 for the same numbers at launch).
!
! Variants (-D):
!   (none)      full model: runtime-ns arrays + 3 schemes + direct central reconstruct
!   SLICE       central path uses whole-array slice-copy omega(0:ns)=d_cbL(:)  (the fixed bug)
!   CONST_NS    ns is a compile-time PARAMETER (mimics --case-optimization)
!   ONE_SCHEME  only wenojs (drops the wenoz/mapped branches)
module m
  implicit none
  integer, parameter :: wp = kind(1.0d0)
#ifdef CONST_NS
  integer, parameter :: ns = 2
#else
  integer :: ns
  !$omp declare target(ns)
#endif
  logical :: wenojs, wenoz, mapped, use_central
  !$omp declare target(wenojs, wenoz, mapped, use_central)
  real(wp), allocatable :: v_rs(:, :), vL(:, :), vR(:, :)
  real(wp), allocatable :: d_cbL(:, :), d_cbR(:, :), pcL(:, :), pcR(:, :), bc(:, :)
end module

program p
  use m
  implicit none
  integer :: n, nv, j, i, q, it
  real(wp) :: dvd(-3:2), poly(0:4), alpha(0:4), omega(0:4), beta(0:4)
  real(wp) :: vp0, vm1, vp1, tau, s
  character(len=16) :: buf
#ifdef CONST_NS
  ! ns fixed
#endif
  call get_environment_variable('N', buf); read (buf, *) n
  nv = 8
#ifndef CONST_NS
  ns = 2
#endif
  wenojs = .true.; wenoz = .false.; mapped = .false.; use_central = .false.
  allocate (v_rs(-3:n + 3, nv), vL(n, nv), vR(n, nv))
  allocate (d_cbL(0:4, nv), d_cbR(0:4, nv), pcL(nv, 0:4), pcR(nv, 0:4), bc(nv, 0:4))
  v_rs = 1._wp; d_cbL = 0.5_wp; d_cbR = 0.5_wp; pcL = 0.1_wp; pcR = 0.1_wp; bc = 1._wp
  !$omp target enter data map(to: v_rs, d_cbL, d_cbR, pcL, pcR, bc) map(alloc: vL, vR)
#ifndef CONST_NS
  !$omp target update to(ns)
#endif
  !$omp target update to(wenojs, wenoz, mapped, use_central)
  do it = 1, 50
    !$omp target teams distribute parallel do collapse(2) &
    !$omp   private(dvd, poly, alpha, omega, beta, vp0, vm1, vp1, tau, s, q)
    do j = 4, n - 3
      do i = 1, nv
        vp0 = v_rs(j, i); vm1 = v_rs(j - 1, i); vp1 = v_rs(j + 1, i)
        dvd(0) = vp1 - vp0; dvd(-1) = vp0 - vm1
        poly(0) = vp0 + pcL(i, 0)*dvd(0); poly(1) = vp0 + pcL(i, 1)*dvd(-1)
        beta(0) = bc(i, 0)*dvd(0)*dvd(0) + 1.e-6_wp
        beta(1) = bc(i, 1)*dvd(-1)*dvd(-1) + 1.e-6_wp
        ! ---- left ----
#ifdef SLICE
        if (use_central) then
          omega(0:ns) = d_cbL(:, i)
        else
#endif
          if (wenojs) then
            do q = 0, ns
              alpha(q) = d_cbL(q, i)/(beta(q)**2._wp)
            end do
#ifndef ONE_SCHEME
          else if (mapped) then
            do q = 0, ns
              alpha(q) = d_cbL(q, i)/(beta(q)**2._wp)
            end do
            omega = alpha/sum(alpha)
            do q = 0, ns
              alpha(q) = (d_cbL(q, i)*(1._wp + d_cbL(q, i) - 3._wp*omega(q)) + omega(q)**2._wp) &
                         *(omega(q)/(d_cbL(q, i)**2._wp + omega(q)*(1._wp - 2._wp*d_cbL(q, i))))
            end do
          else if (wenoz) then
            tau = abs(beta(1) - beta(0))
            do q = 0, ns
              alpha(q) = d_cbL(q, i)*(1._wp + tau/beta(q))
            end do
#endif
          end if
          s = 0._wp
          do q = 0, ns
            s = s + alpha(q)
          end do
          do q = 0, ns
            omega(q) = alpha(q)/s
          end do
#ifdef SLICE
        end if
#endif
        vL(j, i) = omega(0)*poly(0) + omega(1)*poly(1)
        ! ---- right ----
        poly(0) = vp0 + pcR(i, 0)*dvd(0); poly(1) = vp0 + pcR(i, 1)*dvd(-1)
        if (wenojs) then
          do q = 0, ns
            alpha(q) = d_cbR(q, i)/(beta(q)**2._wp)
          end do
#ifndef ONE_SCHEME
        else if (wenoz) then
          tau = abs(beta(1) - beta(0))
          do q = 0, ns
            alpha(q) = d_cbR(q, i)*(1._wp + tau/beta(q))
          end do
#endif
        end if
        s = 0._wp
        do q = 0, ns
          s = s + alpha(q)
        end do
        do q = 0, ns
          omega(q) = alpha(q)/s
        end do
        vR(j, i) = omega(0)*poly(0) + omega(1)*poly(1)
      end do
    end do
  end do
  !$omp target exit data map(from: vL, vR)
  write (*, *) 'checksum', sum(vL) + sum(vR)
end program
