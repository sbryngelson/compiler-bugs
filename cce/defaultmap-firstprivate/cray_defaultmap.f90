!=============================================================================
! Cray CCE-19 OpenMP-offload reproducer (Frontier / gfx90a).
!
! `defaultmap(firstprivate:scalar)` does not privatize the scalars it covers the
! same way an explicit `firstprivate` clause does. On a register-heavy
! `target teams distribute parallel do simd collapse(3)` kernel whose per-cell
! scalar temporaries are left OFF the `private()` list and instead ride on
! `defaultmap(firstprivate:scalar)`, the result is NaN -- but listing those exact
! scalars in an explicit `private()` OR `firstprivate()` clause gives the correct
! answer. Since defaultmap(firstprivate:scalar) is *defined* to make them
! firstprivate, the divergence from an explicit firstprivate of the identical set
! is a compiler bug, not a semantic difference.
!
! Build knobs (set via -D):
!   (none)         private(all scalars)                         -> correct
!   -DOMIT_SCALARS scalars omitted, ride defaultmap(firstprivate:scalar) -> NaN
!   -DEXPLICIT_FP  same scalars in an explicit firstprivate()    -> correct
!   -DNO_SIMD      drop the simd clause (still NaN -> not a simd issue)
!   -DWITH_FP      also add firstprivate(re) (no effect -> not the trigger)
!
! Wrong at -O3, -O2 (NaN) and -O1 (finite but off); independent of simd. The
! register-heavy body matters: with only a few scalars omitted defaultmap copes;
! the bug needs enough of them to spill (which is how MFC's kernels, omitting a
! few, stayed correct until an added firstprivate raised the pressure).
! Output: checksum of the field (correct = 8.0406447725...e7).
!=============================================================================
program cray_defaultmap

    use iso_fortran_env, only: int32, real64
    implicit none

    integer(int32), parameter :: nx = 256, ny = 128, nz = 128
    integer(int32), parameter :: ntot = nx*ny*nz
    real(real64), allocatable :: field(:), ina(:), inb(:), inc(:)
    integer(int32) :: re(2)
    integer(int32) :: ii, jj, kk, e, i, q, trip
    real(real64) :: checksum
    character(len=40) :: vname

    real(real64) :: vel_L_rms, vel_R_rms, vel_avg_rms, rho_L, rho_R, pres_L, pres_R
    real(real64) :: E_L, E_R, H_L, H_R, gamma_L, gamma_R, pi_inf_L, pi_inf_R, qv_L, qv_R
    real(real64) :: alpha_L_sum, alpha_R_sum, c_L, c_R, c_avg, G_L, G_R, rho_avg, H_avg
    real(real64) :: gamma_avg, qv_avg, Ms_L, Ms_R, pres_SL, pres_SR, rho_Star, E_Star
    real(real64) :: p_Star, vel_K_Star, s_L, s_R, s_S, xi_M, xi_P, xi_L, xi_R, xi_MP, xi_PP
    real(real64) :: acc, accv
    real(real64) :: vel_L(3), vel_R(3), alpha_L(3), alpha_R(3), Re_L(2), Re_R(2)
    real(real64) :: tau_e_L(6), tau_e_R(6)

#if defined(EXPLICIT_FP)
    vname = 'firstprivate(all)'
#elif defined(OMIT_SCALARS)
    vname = 'defaultmap(fp:scalar)'
#else
    vname = 'private(all)'
#endif
#ifdef NO_SIMD
    vname = trim(vname)//' nosimd'
#else
    vname = trim(vname)//' simd'
#endif
#ifdef WITH_FP
    vname = trim(vname)//' +fp(re)'
#endif

    allocate (field(ntot), ina(ntot), inb(ntot), inc(ntot))
    re = [1, 0]
    do e = 1, ntot
        ina(e) = 1.0d0 + mod(real(e, real64), 7.0d0)*0.13d0
        inb(e) = 0.5d0 + mod(real(e, real64), 11.0d0)*0.07d0
        inc(e) = 2.0d0 + mod(real(e, real64), 13.0d0)*0.05d0
    end do
    field = 0.0d0

    !$omp target enter data map(to: ina, inb, inc, field, re)

! Knobs (set via -D): OMIT_SCALARS = leave ALL physics scalars off private() and
! rely on defaultmap(firstprivate:scalar) to privatize them (else list them all,
! the "fix"); NO_SIMD = drop the simd clause; WITH_FP = add firstprivate(re).
! defaultmap is placed LAST so the cpp toggles compose without a dangling "&".
#ifdef NO_SIMD
    !$omp target teams distribute parallel do collapse(3) &
#else
    !$omp target teams distribute parallel do simd collapse(3) &
#endif
#if defined(OMIT_SCALARS) || defined(EXPLICIT_FP)
    !$omp   private(e, i, q, trip, vel_L, vel_R, alpha_L, alpha_R, Re_L, Re_R, tau_e_L, tau_e_R) &
#else
    !$omp   private(e, i, q, trip, vel_L, vel_R, alpha_L, alpha_R, Re_L, Re_R, tau_e_L, tau_e_R, &
    !$omp           vel_L_rms, vel_R_rms, vel_avg_rms, rho_L, rho_R, pres_L, pres_R, E_L, E_R, &
    !$omp           H_L, H_R, gamma_L, gamma_R, pi_inf_L, pi_inf_R, qv_L, qv_R, alpha_L_sum, &
    !$omp           alpha_R_sum, c_L, c_R, c_avg, G_L, G_R, rho_avg, H_avg, gamma_avg, qv_avg, &
    !$omp           Ms_L, Ms_R, pres_SL, pres_SR, rho_Star, E_Star, p_Star, vel_K_Star, s_L, &
    !$omp           s_R, s_S, xi_M, xi_P, xi_L, xi_R, xi_MP, xi_PP, acc, accv) &
#endif
#ifdef WITH_FP
    !$omp   firstprivate(re) &
#endif
#ifdef EXPLICIT_FP
    ! Same scalars as OMIT, but via an EXPLICIT firstprivate clause (no defaultmap).
    ! If this is correct while OMIT (defaultmap) is NaN, defaultmap is not honoring
    ! the firstprivate it promises -> unambiguous compiler bug.
    !$omp   firstprivate(vel_L_rms, vel_R_rms, vel_avg_rms, rho_L, rho_R, pres_L, pres_R, E_L, E_R, &
    !$omp           H_L, H_R, gamma_L, gamma_R, pi_inf_L, pi_inf_R, qv_L, qv_R, alpha_L_sum, &
    !$omp           alpha_R_sum, c_L, c_R, c_avg, G_L, G_R, rho_avg, H_avg, gamma_avg, qv_avg, &
    !$omp           Ms_L, Ms_R, pres_SL, pres_SR, rho_Star, E_Star, p_Star, vel_K_Star, s_L, &
    !$omp           s_R, s_S, xi_M, xi_P, xi_L, xi_R, xi_MP, xi_PP, acc, accv)
#else
    !$omp   defaultmap(firstprivate: scalar)
#endif
    do kk = 1, nz
        do jj = 1, ny
            do ii = 1, nx
                e = ii + nx*(jj - 1) + nx*ny*(kk - 1)
                rho_L = ina(e); rho_R = inb(e)
                pres_L = inc(e); pres_R = ina(e)*0.9d0 + 0.1d0
                gamma_L = 1.4d0 + 0.01d0*ina(e); gamma_R = 1.6d0 + 0.01d0*inb(e)
                pi_inf_L = 0.3d0*inc(e); pi_inf_R = 0.2d0*ina(e)
                qv_L = 0.05d0*inb(e); qv_R = 0.04d0*inc(e)
                vel_L_rms = 0.0d0; vel_R_rms = 0.0d0
                do i = 1, 3
                    vel_L(i) = ina(e)*0.1d0*real(i, real64) + inb(e)*0.01d0
                    vel_R(i) = inb(e)*0.1d0*real(i, real64) + inc(e)*0.01d0
                    vel_L_rms = vel_L_rms + vel_L(i)*vel_L(i)
                    vel_R_rms = vel_R_rms + vel_R(i)*vel_R(i)
                    alpha_L(i) = 0.3d0 + 0.1d0*real(i, real64) + inc(e)*0.001d0
                    alpha_R(i) = 0.2d0 + 0.1d0*real(i, real64) + ina(e)*0.001d0
                end do
                alpha_L_sum = alpha_L(1) + alpha_L(2) + alpha_L(3)
                alpha_R_sum = alpha_R(1) + alpha_R(2) + alpha_R(3)
                Re_L(1) = 0.0d0; Re_L(2) = 0.0d0
                Re_R(1) = 0.0d0; Re_R(2) = 0.0d0
                do i = 1, 2
                    trip = re(i)
                    if (trip > 0) then
                        accv = 0.0d0
                        do q = 1, trip
                            accv = accv + (pres_L + real(q, real64))/(rho_L + 1.0d-16)
                        end do
                        Re_L(i) = 1.0d0/max(accv, 1.0d-16)
                        Re_R(i) = 1.0d0/max(accv*0.97d0 + 1.0d-3, 1.0d-16)
                    end if
                end do
                E_L = gamma_L*pres_L + pi_inf_L + 0.5d0*rho_L*vel_L_rms + qv_L
                E_R = gamma_R*pres_R + pi_inf_R + 0.5d0*rho_R*vel_R_rms + qv_R
                H_L = (E_L + pres_L)/rho_L
                H_R = (E_R + pres_R)/rho_R
                rho_avg = sqrt(rho_L*rho_R)
                H_avg = (H_L*sqrt(rho_L) + H_R*sqrt(rho_R))/(sqrt(rho_L) + sqrt(rho_R))
                gamma_avg = 0.5d0*(gamma_L + gamma_R)
                qv_avg = 0.5d0*(qv_L + qv_R)
                vel_avg_rms = 0.5d0*(vel_L_rms + vel_R_rms)
                c_L = sqrt(((H_L - 0.5d0*vel_L_rms)/gamma_L)*(1.0d0 + 1.0d0/gamma_L) + 1.0d-12)
                c_R = sqrt(((H_R - 0.5d0*vel_R_rms)/gamma_R)*(1.0d0 + 1.0d0/gamma_R) + 1.0d-12)
                c_avg = sqrt(((H_avg - 0.5d0*vel_avg_rms)/gamma_avg)*(1.0d0 + 1.0d0/gamma_avg) + 1.0d-12)
                c_avg = c_avg + 1.0d-6*(Re_L(1) + Re_R(1) + Re_L(2) + Re_R(2))
                G_L = alpha_L(1)*0.2d0 + alpha_L(2)*0.3d0 + alpha_L(3)*0.5d0
                G_R = alpha_R(1)*0.2d0 + alpha_R(2)*0.3d0 + alpha_R(3)*0.5d0
                do i = 1, 6
                    tau_e_L(i) = 0.01d0*real(i, real64)*pres_L
                    tau_e_R(i) = 0.01d0*real(i, real64)*pres_R
                    E_L = E_L + (tau_e_L(i)*tau_e_L(i))/(4.0d0*G_L + 1.0d-9)
                    E_R = E_R + (tau_e_R(i)*tau_e_R(i))/(4.0d0*G_R + 1.0d-9)
                end do
                pres_SL = 0.5d0*(pres_L + pres_R + rho_avg*c_avg*(vel_L(1) - vel_R(1)))
                pres_SR = pres_SL
                Ms_L = max(1.0d0, sqrt(1.0d0 + ((0.5d0 + gamma_L)/(1.0d0 + gamma_L)) &
                       *(pres_SL/pres_L - 1.0d0)*pres_L/(pres_L + pi_inf_L/(1.0d0 + gamma_L))))
                Ms_R = max(1.0d0, sqrt(1.0d0 + ((0.5d0 + gamma_R)/(1.0d0 + gamma_R)) &
                       *(pres_SR/pres_R - 1.0d0)*pres_R/(pres_R + pi_inf_R/(1.0d0 + gamma_R))))
                s_L = vel_L(1) - c_L*Ms_L
                s_R = vel_R(1) + c_R*Ms_R
                s_S = 0.5d0*((vel_L(1) + vel_R(1)) + (pres_L - pres_R)/(rho_avg*c_avg))
                ! xi_M, xi_P: per-cell, written here, read below; OMITTED from private()
                ! in BASELINE/FP, so they ride on defaultmap(firstprivate:scalar).
                xi_M = 0.5d0 + sign(0.5d0, s_S)
                xi_P = 0.5d0 - sign(0.5d0, s_S)
                xi_L = (s_L - vel_L(1))/min(s_L - s_S, -1.0d-16)
                xi_R = (s_R - vel_R(1))/max(s_R - s_S, 1.0d-16)
                xi_MP = -min(0.0d0, sign(1.0d0, s_L))
                xi_PP = max(0.0d0, sign(1.0d0, s_R))
                E_Star = xi_M*(E_L + xi_MP*(xi_L*(E_L + (s_S - vel_L(1))*(rho_L*s_S + pres_L/(s_L - vel_L(1)))) - E_L)) &
                         + xi_P*(E_R + xi_PP*(xi_R*(E_R + (s_S - vel_R(1))*(rho_R*s_S + pres_R/(s_R - vel_R(1)))) - E_R))
                p_Star = xi_M*(pres_L + xi_MP*(rho_L*(s_L - vel_L(1))*(s_S - vel_L(1)))) &
                         + xi_P*(pres_R + xi_PP*(rho_R*(s_R - vel_R(1))*(s_S - vel_R(1))))
                rho_Star = xi_M*(rho_L*(xi_MP*xi_L + 1.0d0 - xi_MP)) + xi_P*(rho_R*(xi_PP*xi_R + 1.0d0 - xi_PP))
                vel_K_Star = vel_L(1)*(1.0d0 - xi_MP) + xi_MP*vel_R(1) + xi_MP*xi_PP*(s_S - vel_R(1))
                acc = 0.0d0
                do i = 1, 3
                    acc = acc + rho_Star*vel_K_Star*(vel_L(i)*xi_M + vel_R(i)*xi_P) &
                          + p_Star*xi_M - xi_P*tau_e_L(i) - xi_M*tau_e_R(i)
                end do
                acc = acc + (E_Star + p_Star)*vel_K_Star + c_L + c_R + c_avg + Ms_L + Ms_R + xi_L + xi_R
                field(e) = acc + Re_L(1) + Re_R(1) + Re_L(2) + Re_R(2)
            end do
        end do
    end do
#ifdef NO_SIMD
    !$omp end target teams distribute parallel do
#else
    !$omp end target teams distribute parallel do simd
#endif

    !$omp target exit data map(from: field) map(delete: ina, inb, inc, re)

    checksum = 0.0d0
    do e = 1, ntot
        checksum = checksum + field(e)
    end do

    write (*, '(a,a,a,es22.15)') 'variant ', vname, ' checksum = ', checksum

    deallocate (field, ina, inb, inc)

end program cray_defaultmap
