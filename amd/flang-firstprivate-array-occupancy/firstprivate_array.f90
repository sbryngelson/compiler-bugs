!=============================================================================
! AMD flang OpenMP-offload reproducer (Frontier / gfx90a)
!
! firstprivate of a small, fixed-size INTEGER ARRAY on a register-heavy
! `target teams distribute parallel do` kernel forces a ~20 KB/work-item scratch
! spill, pins AGPRs to the hardware max, and collapses occupancy 4 -> 1
! wave/SIMD. The kernel runs ~36x slower. firstprivate of the same data as two
! scalars, or a plain private array of the same data, does not.
!
! Build one of five ways (exactly one macro defined). The kernel arithmetic is
! byte-identical in all five; only the clause and the index expression differ:
!
!   -DVARIANT_A_BASELINE       no firstprivate; trip count from a host literal
!   -DVARIANT_B_FP_ARRAY       firstprivate(re)            ; read re(i)      [dyn]
!   -DVARIANT_C_FP_SCALARS     firstprivate(re1, re2)      ; merge(re1,re2,..)
!   -DVARIANT_D_FP_ARRAY_CONST firstprivate(re)            ; merge(re(1),re(2),..) [const]
!   -DVARIANT_E_PRIV_ARRAY_DYN private(repriv)+fp(re1,re2) ; read repriv(i)  [dyn]
!
! The 2x2 over {clause} x {index} isolates the trigger:
!   B (fp array, dyn idx)  : SLOW  - 20816 B scratch, 128 AGPR, occ 12%
!   D (fp array, CONST idx): SLOW  - identical resources to B
!   E (priv array, dyn idx): FAST  - 0 B scratch, 0 AGPR, occ 50%
!   C (fp scalars)         : FAST  - 0 B scratch, 0 AGPR, occ 50%
! So it is not the dynamic indexing (E proves a dyn-indexed private array is
! fine; D proves a const-indexed firstprivate array is still broken). The
! trigger is `firstprivate` OF AN ARRAY, specifically. E reaches the exact
! firstprivate semantics by hand - a private array seeded from firstprivate
! scalars - and the compiler lowers THAT optimally, so the lowering of the
! `firstprivate(array)` form itself is the defect.
!
! The kernel body is a register-heavy arithmetic blob modelled on MFC's HLLC
! Riemann solver (m_riemann_solver_hllc.fpp ~141-540): ~90 private real scalar
! temporaries + several small private arrays through a long dependent chain
! (sqrt / sign / divide) so nothing folds away. The integer array `re` (or
! scalars re1/re2) is consumed exactly as Re_size is in the real viscous branch:
! as the trip count of an inner sequential loop and inside the arithmetic.
!
! Timing: 50 outer repeats over a 400x200x200 index space (flattened to 1D,
! matching the production case size), omp_get_wtime, ns/element reported. Run
! with LIBOMPTARGET_KERNEL_TRACE=1 to see the scratch / AGPR / occupancy figures.
!=============================================================================
program firstprivate_array

    use omp_lib, only: omp_get_wtime
    use iso_fortran_env, only: int32, real64

    implicit none

    ! --- Problem size: 400 x 200 x 200, like the production HLLC sweep. -------
    integer(int32), parameter :: nx = 400, ny = 200, nz = 200
    integer(int32), parameter :: ntot = nx*ny*nz          ! 16,000,000 elements
    integer(int32), parameter :: nrep = 50                ! outer timing repeats

    ! --- Output field (one real per cell), and read-only input fields. --------
    real(real64), allocatable :: field(:)
    real(real64), allocatable :: ina(:), inb(:), inc(:)

    ! --- The small viscous datum. re = [1, 0] : phase 1 has 1 Re term, phase 2
    !     has 0. This matches Re_size = [1, 0] in the real case. -----------------
    integer(int32) :: re(2)
    integer(int32) :: re1, re2

    real(real64) :: t0, t1, secs, ns_per_elem, checksum
    integer(int32) :: e, rep, variant_id
    character(len=24) :: variant_name

#if defined(VARIANT_A_BASELINE)
    variant_id = 1; variant_name = 'A baseline (no fp array)'
#elif defined(VARIANT_B_FP_ARRAY)
    variant_id = 2; variant_name = 'B firstprivate(int(2))   '
#elif defined(VARIANT_C_FP_SCALARS)
    variant_id = 3; variant_name = 'C firstprivate(2 scalars)'
#elif defined(VARIANT_D_FP_ARRAY_CONST)
    variant_id = 4; variant_name = 'D fp(array) const-index  '
#elif defined(VARIANT_E_PRIV_ARRAY_DYN)
    variant_id = 5; variant_name = 'E priv(array) dyn-index  '
#else
#error "Define exactly one VARIANT_*"
#endif

    allocate (field(ntot), ina(ntot), inb(ntot), inc(ntot))

    re = [1, 0]
    re1 = re(1); re2 = re(2)

    ! Nontrivial, per-cell-varying inputs so nothing is a loop invariant.
    do e = 1, ntot
        ina(e) = 1.0d0 + mod(real(e, real64), 7.0d0)*0.13d0
        inb(e) = 0.5d0 + mod(real(e, real64), 11.0d0)*0.07d0
        inc(e) = 2.0d0 + mod(real(e, real64), 13.0d0)*0.05d0
    end do
    field = 0.0d0

    !$omp target enter data map(to: ina, inb, inc, field, re)

    ! ---- Warm-up (JIT, first-touch) is excluded from timing. -----------------
    call run_sweep(field, ina, inb, inc, ntot, re, re1, re2, variant_id)

    t0 = omp_get_wtime()
    do rep = 1, nrep
        call run_sweep(field, ina, inb, inc, ntot, re, re1, re2, variant_id)
    end do
    t1 = omp_get_wtime()

    !$omp target exit data map(from: field) map(delete: ina, inb, inc, re)

    secs = t1 - t0
    ns_per_elem = secs*1.0d9/(real(ntot, real64)*real(nrep, real64))

    checksum = 0.0d0
    do e = 1, ntot, max(1, ntot/10000)
        checksum = checksum + field(e)
    end do

    write (*, '(a)')        '=========== BUG 1: firstprivate-array occupancy regression ==========='
    write (*, '(a,a)')      'variant            : ', trim(variant_name)
    write (*, '(a,i0,a,i0,a,i0,a,i0)') 'grid               : ', nx, ' x ', ny, ' x ', nz, &
        & '   elements = ', ntot
    write (*, '(a,i0)')     'outer repeats      : ', nrep
    write (*, '(a,f10.4)')  'total kernel time s: ', secs
    write (*, '(a,f10.4)')  'ns per element     : ', ns_per_elem
    write (*, '(a,es16.8)') 'checksum (corr.chk): ', checksum
    write (*, '(a)')        '======================================================================'

    deallocate (field, ina, inb, inc)

contains

    !-------------------------------------------------------------------------
    ! One register-heavy sweep. The kernel directive differs only in the
    ! firstprivate carriage of the small viscous datum (A/B/C). Everything
    ! else - the ~90 private scalars, the small private arrays, and the long
    ! dependent arithmetic body that consumes the viscous trip count - is
    ! byte-identical across variants.
    !-------------------------------------------------------------------------
    subroutine run_sweep(field, ina, inb, inc, ntot, re, re1, re2, variant_id)

        integer(int32), intent(in)    :: ntot, variant_id
        real(real64),   intent(inout) :: field(ntot)
        real(real64),   intent(in)    :: ina(ntot), inb(ntot), inc(ntot)
        integer(int32), intent(in)    :: re(2)
        integer(int32), intent(in)    :: re1, re2

        integer(int32) :: e, i, q, trip
        integer(int32) :: repriv(2)

        ! ---- ~90 private real scalar temporaries (HLLC-style). --------------
        real(real64) :: vel_L_rms, vel_R_rms, vel_avg_rms, vel_L_tmp, vel_R_tmp
        real(real64) :: rho_L, rho_R, pres_L, pres_R, E_L, E_R, H_L, H_R
        real(real64) :: gamma_L, gamma_R, pi_inf_L, pi_inf_R, qv_L, qv_R, qv_avg
        real(real64) :: alpha_L_sum, alpha_R_sum, c_L, c_R, c_avg, G_L, G_R
        real(real64) :: rho_avg, H_avg, gamma_avg, ptilde_L, ptilde_R
        real(real64) :: Ms_L, Ms_R, pres_SL, pres_SR
        real(real64) :: rho_Star, E_Star, p_Star, p_K_Star, vel_K_Star
        real(real64) :: s_L, s_R, s_M, s_P, s_S
        real(real64) :: xi_M, xi_P, xi_L, xi_R, xi_L_m1, xi_R_m1, xi_MP, xi_PP
        real(real64) :: zcoef, pcorr, flux_ene_e, eps, c_sum
        real(real64) :: Cp_avg, Cv_avg, T_avg, T_L, T_R, MW_L, MW_R
        real(real64) :: R_gas_L, R_gas_R, Cp_L, Cp_R, Cv_L, Cv_R
        real(real64) :: Gamm_L, Gamm_R, qv_diff, h_avg_2, Phi_avg, Yi_avg
        real(real64) :: PbwR3Lbar, PbwR3Rbar, R3Lbar, R3Rbar, R3V2Lbar, R3V2Rbar
        real(real64) :: nbub_L, nbub_R, acc, accv, t

        ! ---- A few small private arrays (HLLC-style). -----------------------
        real(real64) :: vel_L(3), vel_R(3), alpha_L(3), alpha_R(3)
        real(real64) :: Re_L(2), Re_R(2), tau_e_L(6), tau_e_R(6)
        real(real64) :: Ys_L(3), Ys_R(3)

#if defined(VARIANT_A_BASELINE)
        !$omp target teams distribute parallel do &
        !$omp private(e, i, q, trip, vel_L_rms, vel_R_rms, vel_avg_rms, vel_L_tmp, vel_R_tmp, &
        !$omp         rho_L, rho_R, pres_L, pres_R, E_L, E_R, H_L, H_R, gamma_L, gamma_R, &
        !$omp         pi_inf_L, pi_inf_R, qv_L, qv_R, qv_avg, alpha_L_sum, alpha_R_sum, &
        !$omp         c_L, c_R, c_avg, G_L, G_R, rho_avg, H_avg, gamma_avg, ptilde_L, ptilde_R, &
        !$omp         Ms_L, Ms_R, pres_SL, pres_SR, rho_Star, E_Star, p_Star, p_K_Star, vel_K_Star, &
        !$omp         s_L, s_R, s_M, s_P, s_S, xi_M, xi_P, xi_L, xi_R, xi_L_m1, xi_R_m1, xi_MP, xi_PP, &
        !$omp         zcoef, pcorr, flux_ene_e, eps, c_sum, Cp_avg, Cv_avg, T_avg, T_L, T_R, MW_L, MW_R, &
        !$omp         R_gas_L, R_gas_R, Cp_L, Cp_R, Cv_L, Cv_R, Gamm_L, Gamm_R, qv_diff, h_avg_2, &
        !$omp         Phi_avg, Yi_avg, PbwR3Lbar, PbwR3Rbar, R3Lbar, R3Rbar, R3V2Lbar, R3V2Rbar, &
        !$omp         nbub_L, nbub_R, acc, accv, t, vel_L, vel_R, alpha_L, alpha_R, Re_L, Re_R, &
        !$omp         tau_e_L, tau_e_R, Ys_L, Ys_R)
#elif defined(VARIANT_B_FP_ARRAY) || defined(VARIANT_D_FP_ARRAY_CONST)
        !$omp target teams distribute parallel do &
        !$omp private(e, i, q, trip, vel_L_rms, vel_R_rms, vel_avg_rms, vel_L_tmp, vel_R_tmp, &
        !$omp         rho_L, rho_R, pres_L, pres_R, E_L, E_R, H_L, H_R, gamma_L, gamma_R, &
        !$omp         pi_inf_L, pi_inf_R, qv_L, qv_R, qv_avg, alpha_L_sum, alpha_R_sum, &
        !$omp         c_L, c_R, c_avg, G_L, G_R, rho_avg, H_avg, gamma_avg, ptilde_L, ptilde_R, &
        !$omp         Ms_L, Ms_R, pres_SL, pres_SR, rho_Star, E_Star, p_Star, p_K_Star, vel_K_Star, &
        !$omp         s_L, s_R, s_M, s_P, s_S, xi_M, xi_P, xi_L, xi_R, xi_L_m1, xi_R_m1, xi_MP, xi_PP, &
        !$omp         zcoef, pcorr, flux_ene_e, eps, c_sum, Cp_avg, Cv_avg, T_avg, T_L, T_R, MW_L, MW_R, &
        !$omp         R_gas_L, R_gas_R, Cp_L, Cp_R, Cv_L, Cv_R, Gamm_L, Gamm_R, qv_diff, h_avg_2, &
        !$omp         Phi_avg, Yi_avg, PbwR3Lbar, PbwR3Rbar, R3Lbar, R3Rbar, R3V2Lbar, R3V2Rbar, &
        !$omp         nbub_L, nbub_R, acc, accv, t, vel_L, vel_R, alpha_L, alpha_R, Re_L, Re_R, &
        !$omp         tau_e_L, tau_e_R, Ys_L, Ys_R) firstprivate(re)
#elif defined(VARIANT_C_FP_SCALARS)
        !$omp target teams distribute parallel do &
        !$omp private(e, i, q, trip, vel_L_rms, vel_R_rms, vel_avg_rms, vel_L_tmp, vel_R_tmp, &
        !$omp         rho_L, rho_R, pres_L, pres_R, E_L, E_R, H_L, H_R, gamma_L, gamma_R, &
        !$omp         pi_inf_L, pi_inf_R, qv_L, qv_R, qv_avg, alpha_L_sum, alpha_R_sum, &
        !$omp         c_L, c_R, c_avg, G_L, G_R, rho_avg, H_avg, gamma_avg, ptilde_L, ptilde_R, &
        !$omp         Ms_L, Ms_R, pres_SL, pres_SR, rho_Star, E_Star, p_Star, p_K_Star, vel_K_Star, &
        !$omp         s_L, s_R, s_M, s_P, s_S, xi_M, xi_P, xi_L, xi_R, xi_L_m1, xi_R_m1, xi_MP, xi_PP, &
        !$omp         zcoef, pcorr, flux_ene_e, eps, c_sum, Cp_avg, Cv_avg, T_avg, T_L, T_R, MW_L, MW_R, &
        !$omp         R_gas_L, R_gas_R, Cp_L, Cp_R, Cv_L, Cv_R, Gamm_L, Gamm_R, qv_diff, h_avg_2, &
        !$omp         Phi_avg, Yi_avg, PbwR3Lbar, PbwR3Rbar, R3Lbar, R3Rbar, R3V2Lbar, R3V2Rbar, &
        !$omp         nbub_L, nbub_R, acc, accv, t, vel_L, vel_R, alpha_L, alpha_R, Re_L, Re_R, &
        !$omp         tau_e_L, tau_e_R, Ys_L, Ys_R) firstprivate(re1, re2)
#elif defined(VARIANT_E_PRIV_ARRAY_DYN)
        !$omp target teams distribute parallel do &
        !$omp private(e, i, q, trip, vel_L_rms, vel_R_rms, vel_avg_rms, vel_L_tmp, vel_R_tmp, &
        !$omp         rho_L, rho_R, pres_L, pres_R, E_L, E_R, H_L, H_R, gamma_L, gamma_R, &
        !$omp         pi_inf_L, pi_inf_R, qv_L, qv_R, qv_avg, alpha_L_sum, alpha_R_sum, &
        !$omp         c_L, c_R, c_avg, G_L, G_R, rho_avg, H_avg, gamma_avg, ptilde_L, ptilde_R, &
        !$omp         Ms_L, Ms_R, pres_SL, pres_SR, rho_Star, E_Star, p_Star, p_K_Star, vel_K_Star, &
        !$omp         s_L, s_R, s_M, s_P, s_S, xi_M, xi_P, xi_L, xi_R, xi_L_m1, xi_R_m1, xi_MP, xi_PP, &
        !$omp         zcoef, pcorr, flux_ene_e, eps, c_sum, Cp_avg, Cv_avg, T_avg, T_L, T_R, MW_L, MW_R, &
        !$omp         R_gas_L, R_gas_R, Cp_L, Cp_R, Cv_L, Cv_R, Gamm_L, Gamm_R, qv_diff, h_avg_2, &
        !$omp         Phi_avg, Yi_avg, PbwR3Lbar, PbwR3Rbar, R3Lbar, R3Rbar, R3V2Lbar, R3V2Rbar, &
        !$omp         nbub_L, nbub_R, acc, accv, t, vel_L, vel_R, alpha_L, alpha_R, Re_L, Re_R, &
        !$omp         tau_e_L, tau_e_R, Ys_L, Ys_R, repriv) firstprivate(re1, re2)
#endif
        do e = 1, ntot

            ! ---- Seed the left/right primitive state from inputs. -----------
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
                Ys_L(i) = 0.33d0*real(i, real64)
                Ys_R(i) = 0.31d0*real(i, real64)
            end do

            alpha_L_sum = alpha_L(1) + alpha_L(2) + alpha_L(3)
            alpha_R_sum = alpha_R(1) + alpha_R(2) + alpha_R(3)

            ! ---- VISCOUS BRANCH: trip count comes from the small datum. -----
            ! Mirrors HLLC: do i=1,2 ; do q=1,Re_size_loc(i). re=[1,0].
            Re_L(1) = 0.0d0; Re_L(2) = 0.0d0
            Re_R(1) = 0.0d0; Re_R(2) = 0.0d0
#if defined(VARIANT_E_PRIV_ARRAY_DYN)
            repriv(1) = re1; repriv(2) = re2   ! private array reconstructed from firstprivate scalars
#endif
            do i = 1, 2
#if defined(VARIANT_A_BASELINE)
                ! Baseline still does the viscous read, but from a host-known
                ! literal so timing reflects the SAME body without the datum
                ! being firstprivate. re=[1,0] is the production value.
                trip = merge(1, 0, i == 1)
#elif defined(VARIANT_B_FP_ARRAY)
                trip = re(i)
#elif defined(VARIANT_C_FP_SCALARS)
                trip = merge(re1, re2, i == 1)
#elif defined(VARIANT_D_FP_ARRAY_CONST)
                trip = merge(re(1), re(2), i == 1)
#elif defined(VARIANT_E_PRIV_ARRAY_DYN)
                trip = repriv(i)
#endif
                if (trip > 0) then
                    accv = 0.0d0
                    do q = 1, trip
                        accv = accv + (pres_L + real(q, real64))/(rho_L + 1.0d-16)
                    end do
                    Re_L(i) = 1.0d0/max(accv, 1.0d-16)
                    Re_R(i) = 1.0d0/max(accv*0.97d0 + 1.0d-3, 1.0d-16)
                end if
            end do

            ! ---- Energy / enthalpy. -----------------------------------------
            E_L = gamma_L*pres_L + pi_inf_L + 0.5d0*rho_L*vel_L_rms + qv_L
            E_R = gamma_R*pres_R + pi_inf_R + 0.5d0*rho_R*vel_R_rms + qv_R
            H_L = (E_L + pres_L)/rho_L
            H_R = (E_R + pres_R)/rho_R

            ! ---- Roe / arithmetic averages. ---------------------------------
            rho_avg = sqrt(rho_L*rho_R)
            H_avg = (H_L*sqrt(rho_L) + H_R*sqrt(rho_R))/(sqrt(rho_L) + sqrt(rho_R))
            gamma_avg = 0.5d0*(gamma_L + gamma_R)
            qv_avg = 0.5d0*(qv_L + qv_R)
            vel_avg_rms = 0.5d0*(vel_L_rms + vel_R_rms)

            ! ---- Speeds of sound (mimics s_compute_speed_of_sound). ---------
            c_L = sqrt(((H_L - 0.5d0*vel_L_rms)/gamma_L) * (1.0d0 + 1.0d0/gamma_L) + 1.0d-12)
            c_R = sqrt(((H_R - 0.5d0*vel_R_rms)/gamma_R) * (1.0d0 + 1.0d0/gamma_R) + 1.0d-12)
            c_avg = sqrt(((H_avg - 0.5d0*vel_avg_rms)/gamma_avg) * (1.0d0 + 1.0d0/gamma_avg) + 1.0d-12)

            ! Add the viscous-mixing term so Re_L/Re_R cannot be optimized away.
            c_avg = c_avg + 1.0d-6*(Re_L(1) + Re_R(1) + Re_L(2) + Re_R(2))

            ! ---- Mixture shear modulus (elastic-style). ---------------------
            G_L = alpha_L(1)*0.2d0 + alpha_L(2)*0.3d0 + alpha_L(3)*0.5d0
            G_R = alpha_R(1)*0.2d0 + alpha_R(2)*0.3d0 + alpha_R(3)*0.5d0
            do i = 1, 6
                tau_e_L(i) = 0.01d0*real(i, real64)*pres_L
                tau_e_R(i) = 0.01d0*real(i, real64)*pres_R
                E_L = E_L + (tau_e_L(i)*tau_e_L(i))/(4.0d0*G_L + 1.0d-9)
                E_R = E_R + (tau_e_R(i)*tau_e_R(i))/(4.0d0*G_R + 1.0d-9)
            end do

            ! ---- Pressure-based wave speeds (Thornber low-Mach). ------------
            pres_SL = 0.5d0*(pres_L + pres_R + rho_avg*c_avg*(vel_L(1) - vel_R(1)))
            pres_SR = pres_SL
            Ms_L = max(1.0d0, sqrt(1.0d0 + ((0.5d0 + gamma_L)/(1.0d0 + gamma_L)) &
                   *(pres_SL/pres_L - 1.0d0)*pres_L/(pres_L + pi_inf_L/(1.0d0 + gamma_L))))
            Ms_R = max(1.0d0, sqrt(1.0d0 + ((0.5d0 + gamma_R)/(1.0d0 + gamma_R)) &
                   *(pres_SR/pres_R - 1.0d0)*pres_R/(pres_R + pi_inf_R/(1.0d0 + gamma_R))))

            s_L = vel_L(1) - c_L*Ms_L
            s_R = vel_R(1) + c_R*Ms_R
            s_S = 0.5d0*((vel_L(1) + vel_R(1)) + (pres_L - pres_R)/(rho_avg*c_avg))

            s_M = min(0.0d0, s_L); s_P = max(0.0d0, s_R)

            ! ---- Star-state xi factors. -------------------------------------
            xi_L = (s_L - vel_L(1))/min(s_L - s_S, -1.0d-16)
            xi_R = (s_R - vel_R(1))/max(s_R - s_S, 1.0d-16)
            xi_L_m1 = (s_S - vel_L(1))/min(s_L - s_S, -1.0d-16)
            xi_R_m1 = (s_S - vel_R(1))/max(s_R - s_S, 1.0d-16)
            xi_M = 0.5d0 + sign(0.5d0, s_S)
            xi_P = 0.5d0 - sign(0.5d0, s_S)
            xi_MP = -min(0.0d0, sign(1.0d0, s_L))
            xi_PP = max(0.0d0, sign(1.0d0, s_R))

            ! ---- Star states. ----------------------------------------------
            E_Star = xi_M*(E_L + xi_MP*(xi_L*(E_L + (s_S - vel_L(1))*(rho_L*s_S + pres_L/(s_L - vel_L(1)))) - E_L)) &
                     + xi_P*(E_R + xi_PP*(xi_R*(E_R + (s_S - vel_R(1))*(rho_R*s_S + pres_R/(s_R - vel_R(1)))) - E_R))
            p_Star = xi_M*(pres_L + xi_MP*(rho_L*(s_L - vel_L(1))*(s_S - vel_L(1)))) &
                     + xi_P*(pres_R + xi_PP*(rho_R*(s_R - vel_R(1))*(s_S - vel_R(1))))
            rho_Star = xi_M*(rho_L*(xi_MP*xi_L + 1.0d0 - xi_MP)) + xi_P*(rho_R*(xi_PP*xi_R + 1.0d0 - xi_PP))
            vel_K_Star = vel_L(1)*(1.0d0 - xi_MP) + xi_MP*vel_R(1) + xi_MP*xi_PP*(s_S - vel_R(1))

            ! ---- Fluxes (a long dependent accumulation). --------------------
            pcorr = 0.0d0
            acc = 0.0d0
            do i = 1, 3
                acc = acc + rho_Star*vel_K_Star*(vel_L(i)*xi_M + vel_R(i)*xi_P) &
                      + p_Star*xi_M - xi_P*tau_e_L(i) - xi_M*tau_e_R(i)
            end do
            acc = acc + (E_Star + p_Star)*vel_K_Star + (s_M/s_L)*(s_P/s_R)*pcorr*s_S
            acc = acc + c_L + c_R + c_avg + Ms_L + Ms_R + xi_L + xi_R + xi_L_m1 + xi_R_m1

            ! Fold in the viscous result so the branch is observable.
            field(e) = field(e) + acc + Re_L(1) + Re_R(1) + Re_L(2) + Re_R(2)

        end do
        !$omp end target teams distribute parallel do

    end subroutine run_sweep

end program firstprivate_array
