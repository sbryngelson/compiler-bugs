!>
!! @file
!! @brief Contains module m_weno_coefficients

#:include 'case.fpp'
#:include 'macros.fpp'

!> @brief WENO coefficient tables (poly/beta/ideal-weights) computed once at init on the host. Split out of m_weno so it can be
!! compiled at a lower optimization level: amdflang (AFAR drop-23.2.0) miscompiles s_compute_weno_coefficients_impl under
!! loop-unroll-full at -O2/-O3 (wrong coefficients -> O(1e-4) error at shock fronts). See cmake/MFCTargets.cmake.
module m_weno_coefficients

    use m_derived_types
    use m_global_parameters

    implicit none

    private; public :: s_compute_weno_coefficients_impl

contains

    subroutine s_compute_weno_coefficients_impl(weno_dir, is, poly_coef_cbL, poly_coef_cbR, beta_coef, d_cbL, d_cbR, uniform_grid)

        ! Compute WENO coefficients for a given coordinate direction. Shu (1997)
        integer, intent(in) :: weno_dir
        type(int_bounds_info), intent(in) :: is
        real(wp), dimension(is%beg + weno_polyn:,0:,0:), intent(inout) :: poly_coef_cbL
        real(wp), dimension(is%beg + weno_polyn:,0:,0:), intent(inout) :: poly_coef_cbR
        real(wp), dimension(is%beg + weno_polyn:,0:,0:), intent(inout) :: beta_coef
        real(wp), dimension(0:,is%beg + weno_polyn:), intent(inout) :: d_cbL
        real(wp), dimension(0:,is%beg + weno_polyn:), intent(inout) :: d_cbR
        logical, dimension(:), intent(inout) :: uniform_grid
        integer :: s
        real(wp), pointer, dimension(:) :: s_cb => null()  !< Cell-boundary locations in the s-direction
        type(int_bounds_info) :: bc_s                      !< Boundary conditions (BC) in the s-direction
        integer :: i                                       !< Generic loop iterator
        real(wp) :: w(1:8)                                 !< Intermediate var for ideal weights: s_cb across overall stencil
        real(wp) :: y(1:4)                                 !< Intermediate var for poly & beta: diff(s_cb) across sub-stencil
        real(wp) :: h0                                     !< Reference spacing for uniform-grid detection

        ! Determine cell count, boundary locations, and BCs for selected WENO direction

        if (weno_dir == 1) then
            s = m; s_cb => x_cb; bc_s = bc_x
        else if (weno_dir == 2) then
            s = n; s_cb => y_cb; bc_s = bc_y
        else
            s = p; s_cb => z_cb; bc_s = bc_z
        end if

        ! Computing WENO3 Coefficients
        if (weno_order == 3) then
            do i = is%beg - 1 + weno_polyn, is%end - 1 - weno_polyn
                ! Polynomial reconstruction coefficients
                poly_coef_cbR (i + 1, 0, 0) = (s_cb(i) - s_cb(i + 1))/(s_cb(i) - s_cb(i + 2))
                poly_coef_cbR (i + 1, 1, 0) = (s_cb(i) - s_cb(i + 1))/(s_cb(i - 1) - s_cb(i + 1))

                poly_coef_cbL (i + 1, 0, 0) = -poly_coef_cbR (i + 1, 0, 0)
                poly_coef_cbL (i + 1, 1, 0) = -poly_coef_cbR (i + 1, 1, 0)

                ! Ideal (linear) weights
                d_cbR (0, i + 1) = (s_cb(i - 1) - s_cb(i + 1))/(s_cb(i - 1) - s_cb(i + 2))
                d_cbL (0, i + 1) = (s_cb(i - 1) - s_cb(i))/(s_cb(i - 1) - s_cb(i + 2))

                d_cbR (1, i + 1) = 1._wp - d_cbR (0, i + 1)
                d_cbL (1, i + 1) = 1._wp - d_cbL (0, i + 1)

                ! Smoothness indicator coefficients
                beta_coef (i + 1, 0, 0) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp/(s_cb(i) - s_cb(i + 2))**2._wp
                beta_coef (i + 1, 1, 0) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp/(s_cb(i - 1) - s_cb(i + 1))**2._wp
            end do

            ! Modifying the ideal weights coefficients in the neighborhood of beginning and end Riemann state extrapolation
            ! BC to avoid any contributions from outside of the physical domain during the WENO reconstruction
            if (null_weights) then
                if (bc_s%beg == BC_RIEMANN_EXTRAP) then
                    d_cbR (1, 0) = 0._wp; d_cbR (0, 0) = 1._wp
                    d_cbL (1, 0) = 0._wp; d_cbL (0, 0) = 1._wp
                end if

                if (bc_s%end == BC_RIEMANN_EXTRAP) then
                    d_cbR (0, s) = 0._wp; d_cbR (1, s) = 1._wp
                    d_cbL (0, s) = 0._wp; d_cbL (1, s) = 1._wp
                end if
            end if
            ! END: Computing WENO3 Coefficients

            ! Computing WENO5 Coefficients
        else if (weno_order == 5) then
            do i = is%beg - 1 + weno_polyn, is%end - 1 - weno_polyn
                ! Polynomial reconstruction coefficients
                poly_coef_cbR (i + 1, 0, &
                               & 0) = ((s_cb(i) - s_cb(i + 1))*(s_cb(i + 1) - s_cb(i + 2)))/((s_cb(i) - s_cb(i + 3))*(s_cb(i + 3) &
                               & - s_cb(i + 1)))
                poly_coef_cbR (i + 1, 1, &
                               & 0) = ((s_cb(i - 1) - s_cb(i + 1))*(s_cb(i + 1) - s_cb(i)))/((s_cb(i - 1) - s_cb(i + 2))*(s_cb(i &
                               & + 2) - s_cb(i)))
                poly_coef_cbR (i + 1, 1, &
                               & 1) = ((s_cb(i) - s_cb(i + 1))*(s_cb(i + 1) - s_cb(i + 2)))/((s_cb(i - 1) - s_cb(i + 1))*(s_cb(i &
                               & - 1) - s_cb(i + 2)))
                poly_coef_cbR (i + 1, 2, &
                               & 1) = ((s_cb(i) - s_cb(i + 1))*(s_cb(i + 1) - s_cb(i - 1)))/((s_cb(i - 2) - s_cb(i))*(s_cb(i - 2) &
                               & - s_cb(i + 1)))
                poly_coef_cbL (i + 1, 0, &
                               & 0) = ((s_cb(i + 1) - s_cb(i))*(s_cb(i) - s_cb(i + 2)))/((s_cb(i) - s_cb(i + 3))*(s_cb(i + 3) &
                               & - s_cb(i + 1)))
                poly_coef_cbL (i + 1, 1, &
                               & 0) = ((s_cb(i) - s_cb(i - 1))*(s_cb(i) - s_cb(i + 1)))/((s_cb(i - 1) - s_cb(i + 2))*(s_cb(i) &
                               & - s_cb(i + 2)))
                poly_coef_cbL (i + 1, 1, &
                               & 1) = ((s_cb(i + 1) - s_cb(i))*(s_cb(i) - s_cb(i + 2)))/((s_cb(i - 1) - s_cb(i + 1))*(s_cb(i - 1) &
                               & - s_cb(i + 2)))
                poly_coef_cbL (i + 1, 2, &
                               & 1) = ((s_cb(i - 1) - s_cb(i))*(s_cb(i) - s_cb(i + 1)))/((s_cb(i - 2) - s_cb(i))*(s_cb(i - 2) &
                               & - s_cb(i + 1)))

                poly_coef_cbR (i + 1, 0, &
                               & 1) = ((s_cb(i) - s_cb(i + 2)) + (s_cb(i + 1) - s_cb(i + 3)))/((s_cb(i) - s_cb(i + 2))*(s_cb(i) &
                               & - s_cb(i + 3)))*((s_cb(i) - s_cb(i + 1)))
                poly_coef_cbR (i + 1, 2, &
                               & 0) = ((s_cb(i - 2) - s_cb(i + 1)) + (s_cb(i - 1) - s_cb(i + 1)))/((s_cb(i - 1) - s_cb(i + 1)) &
                               & *(s_cb(i + 1) - s_cb(i - 2)))*((s_cb(i + 1) - s_cb(i)))
                poly_coef_cbL (i + 1, 0, &
                               & 1) = ((s_cb(i) - s_cb(i + 2)) + (s_cb(i) - s_cb(i + 3)))/((s_cb(i) - s_cb(i + 2))*(s_cb(i) &
                               & - s_cb(i + 3)))*((s_cb(i + 1) - s_cb(i)))
                poly_coef_cbL (i + 1, 2, &
                               & 0) = ((s_cb(i - 2) - s_cb(i)) + (s_cb(i - 1) - s_cb(i + 1)))/((s_cb(i - 2) - s_cb(i + 1)) &
                               & *(s_cb(i + 1) - s_cb(i - 1)))*((s_cb(i) - s_cb(i + 1)))

                ! Ideal (linear) weights
                d_cbR (0, &
                       & i + 1) = ((s_cb(i - 2) - s_cb(i + 1))*(s_cb(i + 1) - s_cb(i - 1)))/((s_cb(i - 2) - s_cb(i + 3))*(s_cb(i &
                       & + 3) - s_cb(i - 1)))
                d_cbR (2, &
                       & i + 1) = ((s_cb(i + 1) - s_cb(i + 2))*(s_cb(i + 1) - s_cb(i + 3)))/((s_cb(i - 2) - s_cb(i + 2))*(s_cb(i &
                       & - 2) - s_cb(i + 3)))
                d_cbL (0, &
                       & i + 1) = ((s_cb(i - 2) - s_cb(i))*(s_cb(i) - s_cb(i - 1)))/((s_cb(i - 2) - s_cb(i + 3))*(s_cb(i + 3) &
                       & - s_cb(i - 1)))
                d_cbL (2, &
                       & i + 1) = ((s_cb(i) - s_cb(i + 2))*(s_cb(i) - s_cb(i + 3)))/((s_cb(i - 2) - s_cb(i + 2))*(s_cb(i - 2) &
                       & - s_cb(i + 3)))

                d_cbR (1, i + 1) = 1._wp - d_cbR (0, i + 1) - d_cbR (2, i + 1)
                d_cbL (1, i + 1) = 1._wp - d_cbL (0, i + 1) - d_cbL (2, i + 1)

                ! Smoothness indicator coefficients
                beta_coef (i + 1, 0, &
                           & 0) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(10._wp*(s_cb(i + 1) - s_cb(i))**2._wp + (s_cb(i + 1) &
                           & - s_cb(i))*(s_cb(i + 2) - s_cb(i + 1)) + (s_cb(i + 2) - s_cb(i + 1))**2._wp)/((s_cb(i) - s_cb(i + 3)) &
                           & **2._wp*(s_cb(i + 1) - s_cb(i + 3))**2._wp)

                beta_coef (i + 1, 0, &
                           & 1) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(19._wp*(s_cb(i + 1) - s_cb(i))**2._wp - (s_cb(i + 1) &
                           & - s_cb(i))*(s_cb(i + 3) - s_cb(i + 1)) + 2._wp*(s_cb(i + 2) - s_cb(i))*((s_cb(i + 2) - s_cb(i)) &
                           & + (s_cb(i + 3) - s_cb(i + 1))))/((s_cb(i) - s_cb(i + 2))*(s_cb(i) - s_cb(i + 3))**2._wp*(s_cb(i + 3) &
                           & - s_cb(i + 1)))

                beta_coef (i + 1, 0, &
                           & 2) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(10._wp*(s_cb(i + 1) - s_cb(i))**2._wp + (s_cb(i + 1) &
                           & - s_cb(i))*((s_cb(i + 2) - s_cb(i)) + (s_cb(i + 3) - s_cb(i + 1))) + ((s_cb(i + 2) - s_cb(i)) &
                           & + (s_cb(i + 3) - s_cb(i + 1)))**2._wp)/((s_cb(i) - s_cb(i + 2))**2._wp*(s_cb(i) - s_cb(i + 3))**2._wp)

                beta_coef (i + 1, 1, &
                           & 0) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(10._wp*(s_cb(i + 1) - s_cb(i))**2._wp + (s_cb(i) - s_cb(i &
                           & - 1))**2._wp + (s_cb(i) - s_cb(i - 1))*(s_cb(i + 1) - s_cb(i)))/((s_cb(i - 1) - s_cb(i + 2)) &
                           & **2._wp*(s_cb(i) - s_cb(i + 2))**2._wp)

                beta_coef (i + 1, 1, &
                           & 1) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*((s_cb(i) - s_cb(i + 1))*((s_cb(i) - s_cb(i - 1)) &
                           & + 20._wp*(s_cb(i + 1) - s_cb(i))) + (2._wp*(s_cb(i) - s_cb(i - 1)) + (s_cb(i + 1) - s_cb(i))) &
                           & *(s_cb(i + 2) - s_cb(i)))/((s_cb(i + 1) - s_cb(i - 1))*(s_cb(i - 1) - s_cb(i + 2))**2._wp*(s_cb(i &
                           & + 2) - s_cb(i)))

                beta_coef (i + 1, 1, &
                           & 2) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(10._wp*(s_cb(i + 1) - s_cb(i))**2._wp + (s_cb(i + 1) &
                           & - s_cb(i))*(s_cb(i + 2) - s_cb(i + 1)) + (s_cb(i + 2) - s_cb(i + 1))**2._wp)/((s_cb(i - 1) - s_cb(i &
                           & + 1))**2._wp*(s_cb(i - 1) - s_cb(i + 2))**2._wp)

                beta_coef (i + 1, 2, &
                           & 0) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(12._wp*(s_cb(i + 1) - s_cb(i))**2._wp + ((s_cb(i) &
                           & - s_cb(i - 2)) + (s_cb(i) - s_cb(i - 1)))**2._wp + 3._wp*((s_cb(i) - s_cb(i - 2)) + (s_cb(i) &
                           & - s_cb(i - 1)))*(s_cb(i + 1) - s_cb(i)))/((s_cb(i - 2) - s_cb(i + 1))**2._wp*(s_cb(i - 1) - s_cb(i &
                           & + 1))**2._wp)

                beta_coef (i + 1, 2, &
                           & 1) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(19._wp*(s_cb(i + 1) - s_cb(i))**2._wp + ((s_cb(i) &
                           & - s_cb(i - 2))*(s_cb(i) - s_cb(i + 1))) + 2._wp*(s_cb(i + 1) - s_cb(i - 1))*((s_cb(i) - s_cb(i - 2)) &
                           & + (s_cb(i + 1) - s_cb(i - 1))))/((s_cb(i - 2) - s_cb(i))*(s_cb(i - 2) - s_cb(i + 1))**2._wp*(s_cb(i &
                           & + 1) - s_cb(i - 1)))

                beta_coef (i + 1, 2, &
                           & 2) = 4._wp*(s_cb(i) - s_cb(i + 1))**2._wp*(10._wp*(s_cb(i + 1) - s_cb(i))**2._wp + (s_cb(i) - s_cb(i &
                           & - 1))**2._wp + (s_cb(i) - s_cb(i - 1))*(s_cb(i + 1) - s_cb(i)))/((s_cb(i - 2) - s_cb(i)) &
                           & **2._wp*(s_cb(i - 2) - s_cb(i + 1))**2._wp)
            end do

            ! Modifying the ideal weights coefficients in the neighborhood of beginning and end Riemann state extrapolation
            ! BC to avoid any contributions from outside of the physical domain during the WENO reconstruction
            if (null_weights) then
                if (bc_s%beg == BC_RIEMANN_EXTRAP) then
                    d_cbR (1:2,0) = 0._wp; d_cbR (0, 0) = 1._wp
                    d_cbL (1:2,0) = 0._wp; d_cbL (0, 0) = 1._wp
                    d_cbR (2, 1) = 0._wp; d_cbR (:,1) = d_cbR (:,1)/sum(d_cbR (:,1))
                    d_cbL (2, 1) = 0._wp; d_cbL (:,1) = d_cbL (:,1)/sum(d_cbL (:,1))
                end if

                if (bc_s%end == BC_RIEMANN_EXTRAP) then
                    d_cbR (0, s - 1) = 0._wp; d_cbR (:,s - 1) = d_cbR (:,s - 1)/sum(d_cbR (:,s - 1))
                    d_cbL (0, s - 1) = 0._wp; d_cbL (:,s - 1) = d_cbL (:,s - 1)/sum(d_cbL (:,s - 1))
                    d_cbR (0:1,s) = 0._wp; d_cbR (2, s) = 1._wp
                    d_cbL (0:1,s) = 0._wp; d_cbL (2, s) = 1._wp
                end if
            end if
        else
            if (.not. teno) then
                do i = is%beg - 1 + weno_polyn, is%end - 1 - weno_polyn
                    ! Reference: Shu (1997) "Essentially Non-Oscillatory and Weighted Essentially Non-Oscillatory Schemes
                    ! for Hyperbolic Conservation Laws" Equation 2.20: Polynomial Coefficients (poly_coef_cb) Equation 2.61:
                    ! Smoothness Indicators (beta_coef) To reduce computational cost, we leverage the fact that all
                    ! polynomial coefficients in a stencil sum to 1 and compute the polynomial coefficients (poly_coef_cb)
                    ! for the cell value differences (dvd) instead of the values themselves. The computation of coefficients
                    ! is further simplified by using grid spacing (y or w) rather than the grid locations (s_cb) directly.
                    ! Ideal weights (d_cb) are obtained by comparing the grid location coefficients of the polynomial
                    ! coefficients. The smoothness indicators (beta_coef) are calculated through numerical differentiation
                    ! and integration of each cross term of the polynomial coefficients, using the cell value differences
                    ! (dvd) instead of the values themselves. While the polynomial coefficients sum to 1, the derivative of
                    ! 1 is 0, which means it does not create additional cross terms in the smoothness indicators.

                    w = s_cb(i - 3:i + 4) - s_cb(i)  ! Offset using s_cb(i) to reduce floating point error
                    d_cbR (0, i + 1) = ((w(5) - w(6))*(w(5) - w(7))*(w(5) - w(8)))/((w(1) - w(6))*(w(1) - w(7))*(w(1) - w(8)))
                    d_cbR (1, &
                           & i + 1) = ((w(1) - w(5))*(w(5) - w(7))*(w(5) - w(8))*(w(1)*w(2) - w(1)*w(6) - w(1)*w(7) - w(2)*w(6) &
                           & - w(1)*w(8) - w(2)*w(7) - w(2)*w(8) + w(6)*w(7) + w(6)*w(8) + w(7)*w(8) + w(1)**2 + w(2)**2))/((w(1) &
                           & - w(6))*(w(1) - w(7))*(w(1) - w(8))*(w(2) - w(7))*(w(2) - w(8)))
                    d_cbR (2, &
                           & i + 1) = ((w(1) - w(5))*(w(2) - w(5))*(w(5) - w(8))*(w(1)*w(2) + w(1)*w(3) + w(2)*w(3) - w(1)*w(7) &
                           & - w(1)*w(8) - w(2)*w(7) - w(2)*w(8) - w(3)*w(7) - w(3)*w(8) + w(7)*w(8) + w(7)**2 + w(8)**2))/((w(1) &
                           & - w(7))*(w(1) - w(8))*(w(2) - w(7))*(w(2) - w(8))*(w(3) - w(8)))
                    d_cbR (3, i + 1) = ((w(1) - w(5))*(w(2) - w(5))*(w(3) - w(5)))/((w(1) - w(8))*(w(2) - w(8))*(w(3) - w(8)))

                    w = s_cb(i + 4:i - 3:-1) - s_cb(i)
                    d_cbL (0, i + 1) = ((w(1) - w(5))*(w(2) - w(5))*(w(3) - w(5)))/((w(1) - w(8))*(w(2) - w(8))*(w(3) - w(8)))
                    d_cbL (1, &
                           & i + 1) = ((w(1) - w(5))*(w(2) - w(5))*(w(5) - w(8))*(w(1)*w(2) + w(1)*w(3) + w(2)*w(3) - w(1)*w(7) &
                           & - w(1)*w(8) - w(2)*w(7) - w(2)*w(8) - w(3)*w(7) - w(3)*w(8) + w(7)*w(8) + w(7)**2 + w(8)**2))/((w(1) &
                           & - w(7))*(w(1) - w(8))*(w(2) - w(7))*(w(2) - w(8))*(w(3) - w(8)))
                    d_cbL (2, &
                           & i + 1) = ((w(1) - w(5))*(w(5) - w(7))*(w(5) - w(8))*(w(1)*w(2) - w(1)*w(6) - w(1)*w(7) - w(2)*w(6) &
                           & - w(1)*w(8) - w(2)*w(7) - w(2)*w(8) + w(6)*w(7) + w(6)*w(8) + w(7)*w(8) + w(1)**2 + w(2)**2))/((w(1) &
                           & - w(6))*(w(1) - w(7))*(w(1) - w(8))*(w(2) - w(7))*(w(2) - w(8)))
                    d_cbL (3, i + 1) = ((w(5) - w(6))*(w(5) - w(7))*(w(5) - w(8)))/((w(1) - w(6))*(w(1) - w(7))*(w(1) - w(8)))
                    ! Note: Left has the reversed order of both points and coefficients compared to the right

                    y = s_cb(i + 1:i + 4) - s_cb(i:i + 3)
                    poly_coef_cbR (i + 1, 0, &
                                   & 0) = (y(1)*y(2)*(y(2) + y(3)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbR (i + 1, 0, &
                                   & 1) = -(y(1)*y(2)*(3*y(2)**2 + 6*y(2)*y(3) + 3*y(2)*y(4) + 2*y(1)*y(2) + 3*y(3)**2 + 3*y(3) &
                                   & *y(4) + 2*y(1)*y(3) + y(4)**2 + y(1)*y(4)))/((y(2) + y(3))*(y(1) + y(2) + y(3))*(y(2) + y(3) &
                                   & + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbR (i + 1, 0, &
                                   & 2) = (y(1)*(y(1)**2 + 3*y(1)*y(2) + 2*y(1)*y(3) + y(4)*y(1) + 3*y(2)**2 + 4*y(2)*y(3) &
                                   & + 2*y(4)*y(2) + y(3)**2 + y(4)*y(3)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) &
                                   & + y(4)))

                    y = s_cb(i:i + 3) - s_cb(i - 1:i + 2)
                    poly_coef_cbR (i + 1, 1, &
                                   & 0) = -(y(2)*y(3)*(y(1) + y(2)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) &
                                   & + y(4)))
                    poly_coef_cbR (i + 1, 1, &
                                   & 1) = (y(2)*(y(1) + y(2))*(y(2)**2 + 4*y(2)*y(3) + 2*y(2)*y(4) + y(1)*y(2) + 3*y(3)**2 &
                                   & + 3*y(3)*y(4) + 2*y(1)*y(3) + y(4)**2 + y(1)*y(4)))/((y(2) + y(3))*(y(1) + y(2) + y(3))*(y(2) &
                                   & + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbR (i + 1, 1, &
                                   & 2) = (y(2)*y(3)*(y(3) + y(4)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) + y(4)))

                    y = s_cb(i - 1:i + 2) - s_cb(i - 2:i + 1)
                    poly_coef_cbR (i + 1, 2, &
                                   & 0) = (y(3)*(y(2) + y(3))*(y(1) + y(2) + y(3)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) &
                                   & + y(2) + y(3) + y(4)))
                    poly_coef_cbR (i + 1, 2, &
                                   & 1) = (y(3)*y(4)*(y(1)**2 + 3*y(1)*y(2) + 3*y(1)*y(3) + y(4)*y(1) + 3*y(2)**2 + 6*y(2)*y(3) &
                                   & + 2*y(4)*y(2) + 3*y(3)**2 + 2*y(4)*y(3)))/((y(2) + y(3))*(y(1) + y(2) + y(3))*(y(2) + y(3) &
                                   & + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbR (i + 1, 2, &
                                   & 2) = -(y(3)*y(4)*(y(2) + y(3)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) &
                                   & + y(4)))

                    y = s_cb(i - 2:i + 1) - s_cb(i - 3:i)
                    poly_coef_cbR (i + 1, 3, &
                                   & 0) = (y(4)*(y(2)**2 + 4*y(2)*y(3) + 4*y(2)*y(4) + y(1)*y(2) + 3*y(3)**2 + 6*y(3)*y(4) &
                                   & + 2*y(1)*y(3) + 3*y(4)**2 + 2*y(1)*y(4)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) + y(2) &
                                   & + y(3) + y(4)))
                    poly_coef_cbR (i + 1, 3, &
                                   & 1) = -(y(4)*(y(3) + y(4))*(y(1)**2 + 3*y(1)*y(2) + 3*y(1)*y(3) + 2*y(1)*y(4) + 3*y(2)**2 &
                                   & + 6*y(2)*y(3) + 4*y(2)*y(4) + 3*y(3)**2 + 4*y(3)*y(4) + y(4)**2))/((y(2) + y(3))*(y(1) + y(2) &
                                   & + y(3))*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbR (i + 1, 3, &
                                   & 2) = (y(4)*(y(3) + y(4))*(y(2) + y(3) + y(4)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) &
                                   & + y(2) + y(3) + y(4)))

                    y = s_cb(i + 1:i - 2:-1) - s_cb(i:i - 3:-1)
                    poly_coef_cbL (i + 1, 3, &
                                   & 2) = (y(1)*y(2)*(y(2) + y(3)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbL (i + 1, 3, &
                                   & 1) = -(y(1)*y(2)*(3*y(2)**2 + 6*y(2)*y(3) + 3*y(2)*y(4) + 2*y(1)*y(2) + 3*y(3)**2 + 3*y(3) &
                                   & *y(4) + 2*y(1)*y(3) + y(4)**2 + y(1)*y(4)))/((y(2) + y(3))*(y(1) + y(2) + y(3))*(y(2) + y(3) &
                                   & + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbL (i + 1, 3, &
                                   & 0) = (y(1)*(y(1)**2 + 3*y(1)*y(2) + 2*y(1)*y(3) + y(4)*y(1) + 3*y(2)**2 + 4*y(2)*y(3) &
                                   & + 2*y(4)*y(2) + y(3)**2 + y(4)*y(3)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) &
                                   & + y(4)))

                    y = s_cb(i + 2:i - 1:-1) - s_cb(i + 1:i - 2:-1)
                    poly_coef_cbL (i + 1, 2, &
                                   & 2) = -(y(2)*y(3)*(y(1) + y(2)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) &
                                   & + y(4)))
                    poly_coef_cbL (i + 1, 2, &
                                   & 1) = (y(2)*(y(1) + y(2))*(y(2)**2 + 4*y(2)*y(3) + 2*y(2)*y(4) + y(1)*y(2) + 3*y(3)**2 &
                                   & + 3*y(3)*y(4) + 2*y(1)*y(3) + y(4)**2 + y(1)*y(4)))/((y(2) + y(3))*(y(1) + y(2) + y(3))*(y(2) &
                                   & + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbL (i + 1, 2, &
                                   & 0) = (y(2)*y(3)*(y(3) + y(4)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) + y(4)))

                    y = s_cb(i + 3:i:-1) - s_cb(i + 2:i - 1:-1)
                    poly_coef_cbL (i + 1, 1, &
                                   & 2) = (y(3)*(y(2) + y(3))*(y(1) + y(2) + y(3)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) &
                                   & + y(2) + y(3) + y(4)))
                    poly_coef_cbL (i + 1, 1, &
                                   & 1) = (y(3)*y(4)*(y(1)**2 + 3*y(1)*y(2) + 3*y(1)*y(3) + y(4)*y(1) + 3*y(2)**2 + 6*y(2)*y(3) &
                                   & + 2*y(4)*y(2) + 3*y(3)**2 + 2*y(4)*y(3)))/((y(2) + y(3))*(y(1) + y(2) + y(3))*(y(2) + y(3) &
                                   & + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbL (i + 1, 1, &
                                   & 0) = -(y(3)*y(4)*(y(2) + y(3)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) &
                                   & + y(4)))

                    y = s_cb(i + 4:i + 1:-1) - s_cb(i + 3:i:-1)
                    poly_coef_cbL (i + 1, 0, &
                                   & 2) = (y(4)*(y(2)**2 + 4*y(2)*y(3) + 4*y(2)*y(4) + y(1)*y(2) + 3*y(3)**2 + 6*y(3)*y(4) &
                                   & + 2*y(1)*y(3) + 3*y(4)**2 + 2*y(1)*y(4)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) + y(2) &
                                   & + y(3) + y(4)))
                    poly_coef_cbL (i + 1, 0, &
                                   & 1) = -(y(4)*(y(3) + y(4))*(y(1)**2 + 3*y(1)*y(2) + 3*y(1)*y(3) + 2*y(1)*y(4) + 3*y(2)**2 &
                                   & + 6*y(2)*y(3) + 4*y(2)*y(4) + 3*y(3)**2 + 4*y(3)*y(4) + y(4)**2))/((y(2) + y(3))*(y(1) + y(2) &
                                   & + y(3))*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4)))
                    poly_coef_cbL (i + 1, 0, &
                                   & 0) = (y(4)*(y(3) + y(4))*(y(2) + y(3) + y(4)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) &
                                   & + y(2) + y(3) + y(4)))

                    poly_coef_cbL (i + 1,:,:) = -poly_coef_cbL (i + 1,:,:)
                    ! Note: negative sign as the direction of taking the difference (dvd) is reversed

                    y = s_cb(i - 2:i + 1) - s_cb(i - 3:i)
                    beta_coef (i + 1, 3, &
                               & 0) = (4*y(4)**2*(5*y(1)**2*y(2)**2 + 20*y(1)**2*y(2)*y(3) + 15*y(1)**2*y(2)*y(4) + 20*y(1) &
                               & **2*y(3)**2 + 30*y(1)**2*y(3)*y(4) + 60*y(1)**2*y(4)**2 + 10*y(1)*y(2)**3 + 60*y(1)*y(2)**2*y(3) &
                               & + 45*y(1)*y(2)**2*y(4) + 110*y(1)*y(2)*y(3)**2 + 165*y(1)*y(2)*y(3)*y(4) + 260*y(1)*y(2)*y(4)**2 &
                               & + 60*y(1)*y(3)**3 + 135*y(1)*y(3)**2*y(4) + 400*y(1)*y(3)*y(4)**2 + 225*y(1)*y(4)**3 + 5*y(2)**4 &
                               & + 40*y(2)**3*y(3) + 30*y(2)**3*y(4) + 110*y(2)**2*y(3)**2 + 165*y(2)**2*y(3)*y(4) + 260*y(2) &
                               & **2*y(4)**2 + 120*y(2)*y(3)**3 + 270*y(2)*y(3)**2*y(4) + 800*y(2)*y(3)*y(4)**2 + 450*y(2)*y(4) &
                               & **3 + 45*y(3)**4 + 135*y(3)**3*y(4) + 600*y(3)**2*y(4)**2 + 675*y(3)*y(4)**3 + 996*y(4)**4)) &
                               & /(5*(y(3) + y(4))**2*(y(2) + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 3, &
                               & 1) = -(4*y(4)**2*(10*y(1)**3*y(2)*y(3) + 5*y(1)**3*y(2)*y(4) + 20*y(1)**3*y(3)**2 + 25*y(1) &
                               & **3*y(3)*y(4) + 105*y(1)**3*y(4)**2 + 40*y(1)**2*y(2)**2*y(3) + 20*y(1)**2*y(2)**2*y(4) &
                               & + 130*y(1)**2*y(2)*y(3)**2 + 155*y(1)**2*y(2)*y(3)*y(4) + 535*y(1)**2*y(2)*y(4)**2 + 90*y(1) &
                               & **2*y(3)**3 + 165*y(1)**2*y(3)**2*y(4) + 790*y(1)**2*y(3)*y(4)**2 + 415*y(1)**2*y(4)**3 + 60*y(1) &
                               & *y(2)**3*y(3) + 30*y(1)*y(2)**3*y(4) + 270*y(1)*y(2)**2*y(3)**2 + 315*y(1)*y(2)**2*y(3)*y(4) &
                               & + 975*y(1)*y(2)**2*y(4)**2 + 360*y(1)*y(2)*y(3)**3 + 645*y(1)*y(2)*y(3)**2*y(4) + 2850*y(1)*y(2) &
                               & *y(3)*y(4)**2 + 1460*y(1)*y(2)*y(4)**3 + 150*y(1)*y(3)**4 + 360*y(1)*y(3)**3*y(4) + 2000*y(1) &
                               & *y(3)**2*y(4)**2 + 2005*y(1)*y(3)*y(4)**3 + 2077*y(1)*y(4)**4 + 30*y(2)**4*y(3) + 15*y(2)**4*y(4) &
                               & + 180*y(2)**3*y(3)**2 + 210*y(2)**3*y(3)*y(4) + 650*y(2)**3*y(4)**2 + 360*y(2)**2*y(3)**3 &
                               & + 645*y(2)**2*y(3)**2*y(4) + 2850*y(2)**2*y(3)*y(4)**2 + 1460*y(2)**2*y(4)**3 + 300*y(2)*y(3)**4 &
                               & + 720*y(2)*y(3)**3*y(4) + 4000*y(2)*y(3)**2*y(4)**2 + 4010*y(2)*y(3)*y(4)**3 + 4154*y(2)*y(4)**4 &
                               & + 90*y(3)**5 + 270*y(3)**4*y(4) + 1800*y(3)**3*y(4)**2 + 2655*y(3)**2*y(4)**3 + 4464*y(3)*y(4) &
                               & **4 + 1767*y(4)**5))/(5*(y(2) + y(3))*(y(3) + y(4))*(y(1) + y(2) + y(3))*(y(2) + y(3) + y(4)) &
                               & **2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 3, &
                               & 2) = (4*y(4)**2*(10*y(2)**3*y(3) + 5*y(2)**3*y(4) + 50*y(2)**2*y(3)**2 + 60*y(2)**2*y(3)*y(4) &
                               & + 10*y(1)*y(2)**2*y(3) + 215*y(2)**2*y(4)**2 + 5*y(1)*y(2)**2*y(4) + 70*y(2)*y(3)**3 + 130*y(2) &
                               & *y(3)**2*y(4) + 30*y(1)*y(2)*y(3)**2 + 775*y(2)*y(3)*y(4)**2 + 35*y(1)*y(2)*y(3)*y(4) + 415*y(2) &
                               & *y(4)**3 + 110*y(1)*y(2)*y(4)**2 + 30*y(3)**4 + 75*y(3)**3*y(4) + 20*y(1)*y(3)**3 + 665*y(3) &
                               & **2*y(4)**2 + 35*y(1)*y(3)**2*y(4) + 725*y(3)*y(4)**3 + 220*y(1)*y(3)*y(4)**2 + 1767*y(4)**4 &
                               & + 105*y(1)*y(4)**3))/(5*(y(1) + y(2))*(y(3) + y(4))*(y(1) + y(2) + y(3))*(y(2) + y(3) + y(4)) &
                               & *(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 3, &
                               & 3) = (4*y(4)**2*(5*y(1)**4*y(3)**2 + 5*y(1)**4*y(3)*y(4) + 50*y(1)**4*y(4)**2 + 30*y(1)**3*y(2) &
                               & *y(3)**2 + 30*y(1)**3*y(2)*y(3)*y(4) + 300*y(1)**3*y(2)*y(4)**2 + 30*y(1)**3*y(3)**3 + 45*y(1) &
                               & **3*y(3)**2*y(4) + 415*y(1)**3*y(3)*y(4)**2 + 200*y(1)**3*y(4)**3 + 75*y(1)**2*y(2)**2*y(3)**2 &
                               & + 75*y(1)**2*y(2)**2*y(3)*y(4) + 750*y(1)**2*y(2)**2*y(4)**2 + 150*y(1)**2*y(2)*y(3)**3 &
                               & + 225*y(1)**2*y(2)*y(3)**2*y(4) + 2075*y(1)**2*y(2)*y(3)*y(4)**2 + 1000*y(1)**2*y(2)*y(4)**3 &
                               & + 75*y(1)**2*y(3)**4 + 150*y(1)**2*y(3)**3*y(4) + 1390*y(1)**2*y(3)**2*y(4)**2 + 1315*y(1) &
                               & **2*y(3)*y(4)**3 + 1081*y(1)**2*y(4)**4 + 90*y(1)*y(2)**3*y(3)**2 + 90*y(1)*y(2)**3*y(3)*y(4) &
                               & + 900*y(1)*y(2)**3*y(4)**2 + 270*y(1)*y(2)**2*y(3)**3 + 405*y(1)*y(2)**2*y(3)**2*y(4) + 3735*y(1) &
                               & *y(2)**2*y(3)*y(4)**2 + 1800*y(1)*y(2)**2*y(4)**3 + 270*y(1)*y(2)*y(3)**4 + 540*y(1)*y(2)*y(3) &
                               & **3*y(4) + 5025*y(1)*y(2)*y(3)**2*y(4)**2 + 4755*y(1)*y(2)*y(3)*y(4)**3 + 4224*y(1)*y(2)*y(4)**4 &
                               & + 90*y(1)*y(3)**5 + 225*y(1)*y(3)**4*y(4) + 2190*y(1)*y(3)**3*y(4)**2 + 3060*y(1)*y(3)**2*y(4) &
                               & **3 + 4529*y(1)*y(3)*y(4)**4 + 1762*y(1)*y(4)**5 + 45*y(2)**4*y(3)**2 + 45*y(2)**4*y(3)*y(4) &
                               & + 450*y(2)**4*y(4)**2 + 180*y(2)**3*y(3)**3 + 270*y(2)**3*y(3)**2*y(4) + 2490*y(2)**3*y(3)*y(4) &
                               & **2 + 1200*y(2)**3*y(4)**3 + 270*y(2)**2*y(3)**4 + 540*y(2)**2*y(3)**3*y(4) + 5025*y(2)**2*y(3) &
                               & **2*y(4)**2 + 4755*y(2)**2*y(3)*y(4)**3 + 4224*y(2)**2*y(4)**4 + 180*y(2)*y(3)**5 + 450*y(2)*y(3) &
                               & **4*y(4) + 4380*y(2)*y(3)**3*y(4)**2 + 6120*y(2)*y(3)**2*y(4)**3 + 9058*y(2)*y(3)*y(4)**4 &
                               & + 3524*y(2)*y(4)**5 + 45*y(3)**6 + 135*y(3)**5*y(4) + 1395*y(3)**4*y(4)**2 + 2565*y(3)**3*y(4) &
                               & **3 + 4884*y(3)**2*y(4)**4 + 3624*y(3)*y(4)**5 + 831*y(4)**6))/(5*(y(2) + y(3))**2*(y(1) + y(2) &
                               & + y(3))**2*(y(2) + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 3, &
                               & 4) = -(4*y(4)**2*(10*y(1)**2*y(2)*y(3)**2 + 10*y(1)**2*y(2)*y(3)*y(4) + 100*y(1)**2*y(2)*y(4)**2 &
                               & + 10*y(1)**2*y(3)**3 + 15*y(1)**2*y(3)**2*y(4) + 205*y(1)**2*y(3)*y(4)**2 + 100*y(1)**2*y(4)**3 &
                               & + 30*y(1)*y(2)**2*y(3)**2 + 30*y(1)*y(2)**2*y(3)*y(4) + 300*y(1)*y(2)**2*y(4)**2 + 60*y(1)*y(2) &
                               & *y(3)**3 + 90*y(1)*y(2)*y(3)**2*y(4) + 1030*y(1)*y(2)*y(3)*y(4)**2 + 500*y(1)*y(2)*y(4)**3 &
                               & + 30*y(1)*y(3)**4 + 60*y(1)*y(3)**3*y(4) + 835*y(1)*y(3)**2*y(4)**2 + 805*y(1)*y(3)*y(4)**3 &
                               & + 1762*y(1)*y(4)**4 + 30*y(2)**3*y(3)**2 + 30*y(2)**3*y(3)*y(4) + 300*y(2)**3*y(4)**2 + 90*y(2) &
                               & **2*y(3)**3 + 135*y(2)**2*y(3)**2*y(4) + 1445*y(2)**2*y(3)*y(4)**2 + 700*y(2)**2*y(4)**3 &
                               & + 90*y(2)*y(3)**4 + 180*y(2)*y(3)**3*y(4) + 2205*y(2)*y(3)**2*y(4)**2 + 2115*y(2)*y(3)*y(4)**3 &
                               & + 3624*y(2)*y(4)**4 + 30*y(3)**5 + 75*y(3)**4*y(4) + 1060*y(3)**3*y(4)**2 + 1515*y(3)**2*y(4)**3 &
                               & + 3824*y(3)*y(4)**4 + 1662*y(4)**5))/(5*(y(1) + y(2))*(y(2) + y(3))*(y(1) + y(2) + y(3))**2*(y(2) &
                               & + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 3, &
                               & 5) = (4*y(4)**2*(5*y(2)**2*y(3)**2 + 5*y(2)**2*y(3)*y(4) + 50*y(2)**2*y(4)**2 + 10*y(2)*y(3)**3 &
                               & + 15*y(2)*y(3)**2*y(4) + 205*y(2)*y(3)*y(4)**2 + 100*y(2)*y(4)**3 + 5*y(3)**4 + 10*y(3)**3*y(4) &
                               & + 205*y(3)**2*y(4)**2 + 200*y(3)*y(4)**3 + 831*y(4)**4))/(5*(y(1) + y(2))**2*(y(1) + y(2) + y(3)) &
                               & **2*(y(1) + y(2) + y(3) + y(4))**2)

                    y = s_cb(i - 1:i + 2) - s_cb(i - 2:i + 1)
                    beta_coef (i + 1, 2, &
                               & 0) = (4*y(3)**2*(5*y(1)**2*y(2)**2 + 5*y(1)**2*y(2)*y(3) + 50*y(1)**2*y(3)**2 + 10*y(1)*y(2)**3 &
                               & + 15*y(1)*y(2)**2*y(3) + 205*y(1)*y(2)*y(3)**2 + 100*y(1)*y(3)**3 + 5*y(2)**4 + 10*y(2)**3*y(3) &
                               & + 205*y(2)**2*y(3)**2 + 200*y(2)*y(3)**3 + 831*y(3)**4))/(5*(y(3) + y(4))**2*(y(2) + y(3) + y(4)) &
                               & **2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 2, &
                               & 1) = (4*y(3)**2*(5*y(1)**3*y(2)*y(3) + 10*y(1)**3*y(2)*y(4) - 95*y(1)**3*y(3)**2 + 5*y(1)**3*y(3) &
                               & *y(4) + 20*y(1)**2*y(2)**2*y(3) + 40*y(1)**2*y(2)**2*y(4) - 465*y(1)**2*y(2)*y(3)**2 + 55*y(1) &
                               & **2*y(2)*y(3)*y(4) + 10*y(1)**2*y(2)*y(4)**2 - 285*y(1)**2*y(3)**3 + 20*y(1)**2*y(3)**2*y(4) &
                               & + 5*y(1)**2*y(3)*y(4)**2 + 30*y(1)*y(2)**3*y(3) + 60*y(1)*y(2)**3*y(4) - 825*y(1)*y(2)**2*y(3) &
                               & **2 + 135*y(1)*y(2)**2*y(3)*y(4) + 30*y(1)*y(2)**2*y(4)**2 - 1040*y(1)*y(2)*y(3)**3 + 100*y(1) &
                               & *y(2)*y(3)**2*y(4) + 35*y(1)*y(2)*y(3)*y(4)**2 - 1847*y(1)*y(3)**4 + 125*y(1)*y(3)**3*y(4) &
                               & + 110*y(1)*y(3)**2*y(4)**2 + 15*y(2)**4*y(3) + 30*y(2)**4*y(4) - 550*y(2)**3*y(3)**2 + 90*y(2) &
                               & **3*y(3)*y(4) + 20*y(2)**3*y(4)**2 - 1040*y(2)**2*y(3)**3 + 100*y(2)**2*y(3)**2*y(4) + 35*y(2) &
                               & **2*y(3)*y(4)**2 - 3694*y(2)*y(3)**4 + 250*y(2)*y(3)**3*y(4) + 220*y(2)*y(3)**2*y(4)**2 &
                               & - 3219*y(3)**5 - 1452*y(3)**4*y(4) + 105*y(3)**3*y(4)**2))/(5*(y(2) + y(3))*(y(3) + y(4))*(y(1) &
                               & + y(2) + y(3))*(y(2) + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 2, &
                               & 2) = -(4*y(3)**2*(5*y(2)**3*y(3) - 95*y(2)*y(3)**3 - 190*y(2)**2*y(3)**2 + 10*y(2)**3*y(4) &
                               & + 100*y(3)**3*y(4) - 1562*y(3)**4 - 95*y(1)*y(2)*y(3)**2 + 5*y(1)*y(2)**2*y(3) + 10*y(1)*y(2) &
                               & **2*y(4) + 100*y(1)*y(3)**2*y(4) + 205*y(2)*y(3)**2*y(4) + 15*y(2)**2*y(3)*y(4) + 10*y(1)*y(2) &
                               & *y(3)*y(4)))/(5*(y(1) + y(2))*(y(3) + y(4))*(y(1) + y(2) + y(3))*(y(2) + y(3) + y(4))*(y(1) &
                               & + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 2, &
                               & 3) = (4*y(3)**2*(50*y(1)**4*y(3)**2 + 5*y(1)**4*y(3)*y(4) + 5*y(1)**4*y(4)**2 + 300*y(1)**3*y(2) &
                               & *y(3)**2 + 30*y(1)**3*y(2)*y(3)*y(4) + 30*y(1)**3*y(2)*y(4)**2 + 200*y(1)**3*y(3)**3 + 25*y(1) &
                               & **3*y(3)**2*y(4) + 35*y(1)**3*y(3)*y(4)**2 + 10*y(1)**3*y(4)**3 + 750*y(1)**2*y(2)**2*y(3)**2 &
                               & + 75*y(1)**2*y(2)**2*y(3)*y(4) + 75*y(1)**2*y(2)**2*y(4)**2 + 1000*y(1)**2*y(2)*y(3)**3 &
                               & + 125*y(1)**2*y(2)*y(3)**2*y(4) + 175*y(1)**2*y(2)*y(3)*y(4)**2 + 50*y(1)**2*y(2)*y(4)**3 &
                               & + 1081*y(1)**2*y(3)**4 - 50*y(1)**2*y(3)**3*y(4) - 10*y(1)**2*y(3)**2*y(4)**2 + 45*y(1)**2*y(3) &
                               & *y(4)**3 + 5*y(1)**2*y(4)**4 + 900*y(1)*y(2)**3*y(3)**2 + 90*y(1)*y(2)**3*y(3)*y(4) + 90*y(1) &
                               & *y(2)**3*y(4)**2 + 1800*y(1)*y(2)**2*y(3)**3 + 225*y(1)*y(2)**2*y(3)**2*y(4) + 315*y(1)*y(2) &
                               & **2*y(3)*y(4)**2 + 90*y(1)*y(2)**2*y(4)**3 + 4224*y(1)*y(2)*y(3)**4 - 120*y(1)*y(2)*y(3)**3*y(4) &
                               & + 25*y(1)*y(2)*y(3)**2*y(4)**2 + 165*y(1)*y(2)*y(3)*y(4)**3 + 20*y(1)*y(2)*y(4)**4 + 3324*y(1) &
                               & *y(3)**5 + 1407*y(1)*y(3)**4*y(4) - 100*y(1)*y(3)**3*y(4)**2 + 70*y(1)*y(3)**2*y(4)**3 + 15*y(1) &
                               & *y(3)*y(4)**4 + 450*y(2)**4*y(3)**2 + 45*y(2)**4*y(3)*y(4) + 45*y(2)**4*y(4)**2 + 1200*y(2) &
                               & **3*y(3)**3 + 150*y(2)**3*y(3)**2*y(4) + 210*y(2)**3*y(3)*y(4)**2 + 60*y(2)**3*y(4)**3 &
                               & + 4224*y(2)**2*y(3)**4 - 120*y(2)**2*y(3)**3*y(4) + 25*y(2)**2*y(3)**2*y(4)**2 + 165*y(2)**2*y(3) &
                               & *y(4)**3 + 20*y(2)**2*y(4)**4 + 6648*y(2)*y(3)**5 + 2814*y(2)*y(3)**4*y(4) - 200*y(2)*y(3) &
                               & **3*y(4)**2 + 140*y(2)*y(3)**2*y(4)**3 + 30*y(2)*y(3)*y(4)**4 + 3174*y(3)**6 + 3039*y(3)**5*y(4) &
                               & + 771*y(3)**4*y(4)**2 + 135*y(3)**3*y(4)**3 + 60*y(3)**2*y(4)**4))/(5*(y(2) + y(3))**2*(y(1) &
                               & + y(2) + y(3))**2*(y(2) + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 2, &
                               & 4) = -(4*y(3)**2*(100*y(1)**2*y(2)*y(3)**2 + 10*y(1)**2*y(2)*y(3)*y(4) + 10*y(1)**2*y(2)*y(4)**2 &
                               & - 95*y(1)**2*y(3)**2*y(4) + 5*y(1)**2*y(3)*y(4)**2 + 300*y(1)*y(2)**2*y(3)**2 + 30*y(1)*y(2) &
                               & **2*y(3)*y(4) + 30*y(1)*y(2)**2*y(4)**2 + 200*y(1)*y(2)*y(3)**3 - 260*y(1)*y(2)*y(3)**2*y(4) &
                               & + 50*y(1)*y(2)*y(3)*y(4)**2 + 10*y(1)*y(2)*y(4)**3 + 1562*y(1)*y(3)**4 - 190*y(1)*y(3)**3*y(4) &
                               & + 15*y(1)*y(3)**2*y(4)**2 + 5*y(1)*y(3)*y(4)**3 + 300*y(2)**3*y(3)**2 + 30*y(2)**3*y(3)*y(4) &
                               & + 30*y(2)**3*y(4)**2 + 400*y(2)**2*y(3)**3 - 235*y(2)**2*y(3)**2*y(4) + 85*y(2)**2*y(3)*y(4)**2 &
                               & + 20*y(2)**2*y(4)**3 + 3224*y(2)*y(3)**4 - 460*y(2)*y(3)**3*y(4) - 35*y(2)*y(3)**2*y(4)**2 &
                               & + 25*y(2)*y(3)*y(4)**3 + 3124*y(3)**5 + 1467*y(3)**4*y(4) + 110*y(3)**3*y(4)**2 + 105*y(3) &
                               & **2*y(4)**3))/(5*(y(1) + y(2))*(y(2) + y(3))*(y(1) + y(2) + y(3))**2*(y(2) + y(3) + y(4))*(y(1) &
                               & + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 2, &
                               & 5) = (4*y(3)**2*(50*y(2)**2*y(3)**2 + 5*y(2)**2*y(3)*y(4) + 5*y(2)**2*y(4)**2 - 95*y(2)*y(3) &
                               & **2*y(4) + 5*y(2)*y(3)*y(4)**2 + 781*y(3)**4 + 50*y(3)**2*y(4)**2))/(5*(y(1) + y(2))**2*(y(1) &
                               & + y(2) + y(3))**2*(y(1) + y(2) + y(3) + y(4))**2)

                    y = s_cb(i:i + 3) - s_cb(i - 1:i + 2)
                    beta_coef (i + 1, 1, &
                               & 0) = (4*y(2)**2*(50*y(1)**2*y(2)**2 + 5*y(1)**2*y(2)*y(3) + 5*y(1)**2*y(3)**2 - 95*y(1)*y(2) &
                               & **2*y(3) + 5*y(1)*y(2)*y(3)**2 + 781*y(2)**4 + 50*y(2)**2*y(3)**2))/(5*(y(3) + y(4))**2*(y(2) &
                               & + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 1, &
                               & 1) = -(4*y(2)**2*(105*y(1)**3*y(2)**2 + 25*y(1)**3*y(2)*y(3) + 5*y(1)**3*y(2)*y(4) + 20*y(1) &
                               & **3*y(3)**2 + 10*y(1)**3*y(3)*y(4) + 110*y(1)**2*y(2)**3 - 35*y(1)**2*y(2)**2*y(3) + 15*y(1) &
                               & **2*y(2)**2*y(4) + 85*y(1)**2*y(2)*y(3)**2 + 50*y(1)**2*y(2)*y(3)*y(4) + 5*y(1)**2*y(2)*y(4)**2 &
                               & + 30*y(1)**2*y(3)**3 + 30*y(1)**2*y(3)**2*y(4) + 10*y(1)**2*y(3)*y(4)**2 + 1467*y(1)*y(2)**4 &
                               & - 460*y(1)*y(2)**3*y(3) - 190*y(1)*y(2)**3*y(4) - 235*y(1)*y(2)**2*y(3)**2 - 260*y(1)*y(2) &
                               & **2*y(3)*y(4) - 95*y(1)*y(2)**2*y(4)**2 + 30*y(1)*y(2)*y(3)**3 + 30*y(1)*y(2)*y(3)**2*y(4) &
                               & + 10*y(1)*y(2)*y(3)*y(4)**2 + 3124*y(2)**5 + 3224*y(2)**4*y(3) + 1562*y(2)**4*y(4) + 400*y(2) &
                               & **3*y(3)**2 + 200*y(2)**3*y(3)*y(4) + 300*y(2)**2*y(3)**3 + 300*y(2)**2*y(3)**2*y(4) + 100*y(2) &
                               & **2*y(3)*y(4)**2))/(5*(y(2) + y(3))*(y(3) + y(4))*(y(1) + y(2) + y(3))*(y(2) + y(3) + y(4)) &
                               & **2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 1, &
                               & 2) = -(4*y(2)**2*(100*y(1)*y(2)**3 - 190*y(2)**2*y(3)**2 + 10*y(1)*y(3)**3 + 5*y(2)*y(3)**3 &
                               & - 95*y(2)**3*y(3) - 1562*y(2)**4 + 15*y(1)*y(2)*y(3)**2 + 205*y(1)*y(2)**2*y(3) + 100*y(1)*y(2) &
                               & **2*y(4) + 10*y(1)*y(3)**2*y(4) + 5*y(2)*y(3)**2*y(4) - 95*y(2)**2*y(3)*y(4) + 10*y(1)*y(2)*y(3) &
                               & *y(4)))/(5*(y(1) + y(2))*(y(3) + y(4))*(y(1) + y(2) + y(3))*(y(2) + y(3) + y(4))*(y(1) + y(2) &
                               & + y(3) + y(4))**2)
                    beta_coef (i + 1, 1, &
                               & 3) = (4*y(2)**2*(60*y(1)**4*y(2)**2 + 30*y(1)**4*y(2)*y(3) + 15*y(1)**4*y(2)*y(4) + 20*y(1) &
                               & **4*y(3)**2 + 20*y(1)**4*y(3)*y(4) + 5*y(1)**4*y(4)**2 + 135*y(1)**3*y(2)**3 + 140*y(1)**3*y(2) &
                               & **2*y(3) + 70*y(1)**3*y(2)**2*y(4) + 165*y(1)**3*y(2)*y(3)**2 + 165*y(1)**3*y(2)*y(3)*y(4) &
                               & + 45*y(1)**3*y(2)*y(4)**2 + 60*y(1)**3*y(3)**3 + 90*y(1)**3*y(3)**2*y(4) + 50*y(1)**3*y(3)*y(4) &
                               & **2 + 10*y(1)**3*y(4)**3 + 771*y(1)**2*y(2)**4 - 200*y(1)**2*y(2)**3*y(3) - 100*y(1)**2*y(2) &
                               & **3*y(4) + 25*y(1)**2*y(2)**2*y(3)**2 + 25*y(1)**2*y(2)**2*y(3)*y(4) - 10*y(1)**2*y(2)**2*y(4) &
                               & **2 + 210*y(1)**2*y(2)*y(3)**3 + 315*y(1)**2*y(2)*y(3)**2*y(4) + 175*y(1)**2*y(2)*y(3)*y(4)**2 &
                               & + 35*y(1)**2*y(2)*y(4)**3 + 45*y(1)**2*y(3)**4 + 90*y(1)**2*y(3)**3*y(4) + 75*y(1)**2*y(3) &
                               & **2*y(4)**2 + 30*y(1)**2*y(3)*y(4)**3 + 5*y(1)**2*y(4)**4 + 3039*y(1)*y(2)**5 + 2814*y(1)*y(2) &
                               & **4*y(3) + 1407*y(1)*y(2)**4*y(4) - 120*y(1)*y(2)**3*y(3)**2 - 120*y(1)*y(2)**3*y(3)*y(4) &
                               & - 50*y(1)*y(2)**3*y(4)**2 + 150*y(1)*y(2)**2*y(3)**3 + 225*y(1)*y(2)**2*y(3)**2*y(4) + 125*y(1) &
                               & *y(2)**2*y(3)*y(4)**2 + 25*y(1)*y(2)**2*y(4)**3 + 45*y(1)*y(2)*y(3)**4 + 90*y(1)*y(2)*y(3) &
                               & **3*y(4) + 75*y(1)*y(2)*y(3)**2*y(4)**2 + 30*y(1)*y(2)*y(3)*y(4)**3 + 5*y(1)*y(2)*y(4)**4 &
                               & + 3174*y(2)**6 + 6648*y(2)**5*y(3) + 3324*y(2)**5*y(4) + 4224*y(2)**4*y(3)**2 + 4224*y(2)**4*y(3) &
                               & *y(4) + 1081*y(2)**4*y(4)**2 + 1200*y(2)**3*y(3)**3 + 1800*y(2)**3*y(3)**2*y(4) + 1000*y(2) &
                               & **3*y(3)*y(4)**2 + 200*y(2)**3*y(4)**3 + 450*y(2)**2*y(3)**4 + 900*y(2)**2*y(3)**3*y(4) &
                               & + 750*y(2)**2*y(3)**2*y(4)**2 + 300*y(2)**2*y(3)*y(4)**3 + 50*y(2)**2*y(4)**4))/(5*(y(2) + y(3)) &
                               & **2*(y(1) + y(2) + y(3))**2*(y(2) + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 1, &
                               & 4) = (4*y(2)**2*(105*y(1)**2*y(2)**3 + 220*y(1)**2*y(2)**2*y(3) + 110*y(1)**2*y(2)**2*y(4) &
                               & + 35*y(1)**2*y(2)*y(3)**2 + 35*y(1)**2*y(2)*y(3)*y(4) + 5*y(1)**2*y(2)*y(4)**2 + 20*y(1)**2*y(3) &
                               & **3 + 30*y(1)**2*y(3)**2*y(4) + 10*y(1)**2*y(3)*y(4)**2 - 1452*y(1)*y(2)**4 + 250*y(1)*y(2) &
                               & **3*y(3) + 125*y(1)*y(2)**3*y(4) + 100*y(1)*y(2)**2*y(3)**2 + 100*y(1)*y(2)**2*y(3)*y(4) &
                               & + 20*y(1)*y(2)**2*y(4)**2 + 90*y(1)*y(2)*y(3)**3 + 135*y(1)*y(2)*y(3)**2*y(4) + 55*y(1)*y(2)*y(3) &
                               & *y(4)**2 + 5*y(1)*y(2)*y(4)**3 + 30*y(1)*y(3)**4 + 60*y(1)*y(3)**3*y(4) + 40*y(1)*y(3)**2*y(4) &
                               & **2 + 10*y(1)*y(3)*y(4)**3 - 3219*y(2)**5 - 3694*y(2)**4*y(3) - 1847*y(2)**4*y(4) - 1040*y(2) &
                               & **3*y(3)**2 - 1040*y(2)**3*y(3)*y(4) - 285*y(2)**3*y(4)**2 - 550*y(2)**2*y(3)**3 - 825*y(2) &
                               & **2*y(3)**2*y(4) - 465*y(2)**2*y(3)*y(4)**2 - 95*y(2)**2*y(4)**3 + 15*y(2)*y(3)**4 + 30*y(2)*y(3) &
                               & **3*y(4) + 20*y(2)*y(3)**2*y(4)**2 + 5*y(2)*y(3)*y(4)**3))/(5*(y(1) + y(2))*(y(2) + y(3))*(y(1) &
                               & + y(2) + y(3))**2*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 1, &
                               & 5) = (4*y(2)**2*(831*y(2)**4 + 200*y(2)**3*y(3) + 100*y(2)**3*y(4) + 205*y(2)**2*y(3)**2 &
                               & + 205*y(2)**2*y(3)*y(4) + 50*y(2)**2*y(4)**2 + 10*y(2)*y(3)**3 + 15*y(2)*y(3)**2*y(4) + 5*y(2) &
                               & *y(3)*y(4)**2 + 5*y(3)**4 + 10*y(3)**3*y(4) + 5*y(3)**2*y(4)**2))/(5*(y(1) + y(2))**2*(y(1) &
                               & + y(2) + y(3))**2*(y(1) + y(2) + y(3) + y(4))**2)

                    y = s_cb(i + 1:i + 4) - s_cb(i:i + 3)
                    beta_coef (i + 1, 0, &
                               & 0) = (4*y(1)**2*(831*y(1)**4 + 200*y(1)**3*y(2) + 100*y(1)**3*y(3) + 205*y(1)**2*y(2)**2 &
                               & + 205*y(1)**2*y(2)*y(3) + 50*y(1)**2*y(3)**2 + 10*y(1)*y(2)**3 + 15*y(1)*y(2)**2*y(3) + 5*y(1) &
                               & *y(2)*y(3)**2 + 5*y(2)**4 + 10*y(2)**3*y(3) + 5*y(2)**2*y(3)**2))/(5*(y(3) + y(4))**2*(y(2) &
                               & + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 0, &
                               & 1) = -(4*y(1)**2*(1662*y(1)**5 + 3824*y(1)**4*y(2) + 3624*y(1)**4*y(3) + 1762*y(1)**4*y(4) &
                               & + 1515*y(1)**3*y(2)**2 + 2115*y(1)**3*y(2)*y(3) + 805*y(1)**3*y(2)*y(4) + 700*y(1)**3*y(3)**2 &
                               & + 500*y(1)**3*y(3)*y(4) + 100*y(1)**3*y(4)**2 + 1060*y(1)**2*y(2)**3 + 2205*y(1)**2*y(2)**2*y(3) &
                               & + 835*y(1)**2*y(2)**2*y(4) + 1445*y(1)**2*y(2)*y(3)**2 + 1030*y(1)**2*y(2)*y(3)*y(4) + 205*y(1) &
                               & **2*y(2)*y(4)**2 + 300*y(1)**2*y(3)**3 + 300*y(1)**2*y(3)**2*y(4) + 100*y(1)**2*y(3)*y(4)**2 &
                               & + 75*y(1)*y(2)**4 + 180*y(1)*y(2)**3*y(3) + 60*y(1)*y(2)**3*y(4) + 135*y(1)*y(2)**2*y(3)**2 &
                               & + 90*y(1)*y(2)**2*y(3)*y(4) + 15*y(1)*y(2)**2*y(4)**2 + 30*y(1)*y(2)*y(3)**3 + 30*y(1)*y(2)*y(3) &
                               & **2*y(4) + 10*y(1)*y(2)*y(3)*y(4)**2 + 30*y(2)**5 + 90*y(2)**4*y(3) + 30*y(2)**4*y(4) + 90*y(2) &
                               & **3*y(3)**2 + 60*y(2)**3*y(3)*y(4) + 10*y(2)**3*y(4)**2 + 30*y(2)**2*y(3)**3 + 30*y(2)**2*y(3) &
                               & **2*y(4) + 10*y(2)**2*y(3)*y(4)**2))/(5*(y(2) + y(3))*(y(3) + y(4))*(y(1) + y(2) + y(3))*(y(2) &
                               & + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 0, &
                               & 2) = (4*y(1)**2*(1767*y(1)**4 + 725*y(1)**3*y(2) + 415*y(1)**3*y(3) + 105*y(4)*y(1)**3 + 665*y(1) &
                               & **2*y(2)**2 + 775*y(1)**2*y(2)*y(3) + 220*y(4)*y(1)**2*y(2) + 215*y(1)**2*y(3)**2 + 110*y(4)*y(1) &
                               & **2*y(3) + 75*y(1)*y(2)**3 + 130*y(1)*y(2)**2*y(3) + 35*y(4)*y(1)*y(2)**2 + 60*y(1)*y(2)*y(3)**2 &
                               & + 35*y(4)*y(1)*y(2)*y(3) + 5*y(1)*y(3)**3 + 5*y(4)*y(1)*y(3)**2 + 30*y(2)**4 + 70*y(2)**3*y(3) &
                               & + 20*y(4)*y(2)**3 + 50*y(2)**2*y(3)**2 + 30*y(4)*y(2)**2*y(3) + 10*y(2)*y(3)**3 + 10*y(4)*y(2) &
                               & *y(3)**2))/(5*(y(1) + y(2))*(y(3) + y(4))*(y(1) + y(2) + y(3))*(y(2) + y(3) + y(4))*(y(1) + y(2) &
                               & + y(3) + y(4))**2)
                    beta_coef (i + 1, 0, &
                               & 3) = (4*y(1)**2*(831*y(1)**6 + 3624*y(1)**5*y(2) + 3524*y(1)**5*y(3) + 1762*y(1)**5*y(4) &
                               & + 4884*y(1)**4*y(2)**2 + 9058*y(1)**4*y(2)*y(3) + 4529*y(1)**4*y(2)*y(4) + 4224*y(1)**4*y(3)**2 &
                               & + 4224*y(1)**4*y(3)*y(4) + 1081*y(1)**4*y(4)**2 + 2565*y(1)**3*y(2)**3 + 6120*y(1)**3*y(2) &
                               & **2*y(3) + 3060*y(1)**3*y(2)**2*y(4) + 4755*y(1)**3*y(2)*y(3)**2 + 4755*y(1)**3*y(2)*y(3)*y(4) &
                               & + 1315*y(1)**3*y(2)*y(4)**2 + 1200*y(1)**3*y(3)**3 + 1800*y(1)**3*y(3)**2*y(4) + 1000*y(1) &
                               & **3*y(3)*y(4)**2 + 200*y(1)**3*y(4)**3 + 1395*y(1)**2*y(2)**4 + 4380*y(1)**2*y(2)**3*y(3) &
                               & + 2190*y(1)**2*y(2)**3*y(4) + 5025*y(1)**2*y(2)**2*y(3)**2 + 5025*y(1)**2*y(2)**2*y(3)*y(4) &
                               & + 1390*y(1)**2*y(2)**2*y(4)**2 + 2490*y(1)**2*y(2)*y(3)**3 + 3735*y(1)**2*y(2)*y(3)**2*y(4) &
                               & + 2075*y(1)**2*y(2)*y(3)*y(4)**2 + 415*y(1)**2*y(2)*y(4)**3 + 450*y(1)**2*y(3)**4 + 900*y(1) &
                               & **2*y(3)**3*y(4) + 750*y(1)**2*y(3)**2*y(4)**2 + 300*y(1)**2*y(3)*y(4)**3 + 50*y(1)**2*y(4)**4 &
                               & + 135*y(1)*y(2)**5 + 450*y(1)*y(2)**4*y(3) + 225*y(1)*y(2)**4*y(4) + 540*y(1)*y(2)**3*y(3)**2 &
                               & + 540*y(1)*y(2)**3*y(3)*y(4) + 150*y(1)*y(2)**3*y(4)**2 + 270*y(1)*y(2)**2*y(3)**3 + 405*y(1) &
                               & *y(2)**2*y(3)**2*y(4) + 225*y(1)*y(2)**2*y(3)*y(4)**2 + 45*y(1)*y(2)**2*y(4)**3 + 45*y(1)*y(2) &
                               & *y(3)**4 + 90*y(1)*y(2)*y(3)**3*y(4) + 75*y(1)*y(2)*y(3)**2*y(4)**2 + 30*y(1)*y(2)*y(3)*y(4)**3 &
                               & + 5*y(1)*y(2)*y(4)**4 + 45*y(2)**6 + 180*y(2)**5*y(3) + 90*y(2)**5*y(4) + 270*y(2)**4*y(3)**2 &
                               & + 270*y(2)**4*y(3)*y(4) + 75*y(2)**4*y(4)**2 + 180*y(2)**3*y(3)**3 + 270*y(2)**3*y(3)**2*y(4) &
                               & + 150*y(2)**3*y(3)*y(4)**2 + 30*y(2)**3*y(4)**3 + 45*y(2)**2*y(3)**4 + 90*y(2)**2*y(3)**3*y(4) &
                               & + 75*y(2)**2*y(3)**2*y(4)**2 + 30*y(2)**2*y(3)*y(4)**3 + 5*y(2)**2*y(4)**4))/(5*(y(2) + y(3)) &
                               & **2*(y(1) + y(2) + y(3))**2*(y(2) + y(3) + y(4))**2*(y(1) + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 0, &
                               & 4) = -(4*y(1)**2*(1767*y(1)**5 + 4464*y(1)**4*y(2) + 4154*y(1)**4*y(3) + 2077*y(1)**4*y(4) &
                               & + 2655*y(1)**3*y(2)**2 + 4010*y(1)**3*y(2)*y(3) + 2005*y(1)**3*y(2)*y(4) + 1460*y(1)**3*y(3)**2 &
                               & + 1460*y(1)**3*y(3)*y(4) + 415*y(1)**3*y(4)**2 + 1800*y(1)**2*y(2)**3 + 4000*y(1)**2*y(2)**2*y(3) &
                               & + 2000*y(1)**2*y(2)**2*y(4) + 2850*y(1)**2*y(2)*y(3)**2 + 2850*y(1)**2*y(2)*y(3)*y(4) + 790*y(1) &
                               & **2*y(2)*y(4)**2 + 650*y(1)**2*y(3)**3 + 975*y(1)**2*y(3)**2*y(4) + 535*y(1)**2*y(3)*y(4)**2 &
                               & + 105*y(1)**2*y(4)**3 + 270*y(1)*y(2)**4 + 720*y(1)*y(2)**3*y(3) + 360*y(1)*y(2)**3*y(4) &
                               & + 645*y(1)*y(2)**2*y(3)**2 + 645*y(1)*y(2)**2*y(3)*y(4) + 165*y(1)*y(2)**2*y(4)**2 + 210*y(1) &
                               & *y(2)*y(3)**3 + 315*y(1)*y(2)*y(3)**2*y(4) + 155*y(1)*y(2)*y(3)*y(4)**2 + 25*y(1)*y(2)*y(4)**3 &
                               & + 15*y(1)*y(3)**4 + 30*y(1)*y(3)**3*y(4) + 20*y(1)*y(3)**2*y(4)**2 + 5*y(1)*y(3)*y(4)**3 &
                               & + 90*y(2)**5 + 300*y(2)**4*y(3) + 150*y(2)**4*y(4) + 360*y(2)**3*y(3)**2 + 360*y(2)**3*y(3)*y(4) &
                               & + 90*y(2)**3*y(4)**2 + 180*y(2)**2*y(3)**3 + 270*y(2)**2*y(3)**2*y(4) + 130*y(2)**2*y(3)*y(4)**2 &
                               & + 20*y(2)**2*y(4)**3 + 30*y(2)*y(3)**4 + 60*y(2)*y(3)**3*y(4) + 40*y(2)*y(3)**2*y(4)**2 + 10*y(2) &
                               & *y(3)*y(4)**3))/(5*(y(1) + y(2))*(y(2) + y(3))*(y(1) + y(2) + y(3))**2*(y(2) + y(3) + y(4))*(y(1) &
                               & + y(2) + y(3) + y(4))**2)
                    beta_coef (i + 1, 0, &
                               & 5) = (4*y(1)**2*(996*y(1)**4 + 675*y(1)**3*y(2) + 450*y(1)**3*y(3) + 225*y(1)**3*y(4) + 600*y(1) &
                               & **2*y(2)**2 + 800*y(1)**2*y(2)*y(3) + 400*y(1)**2*y(2)*y(4) + 260*y(1)**2*y(3)**2 + 260*y(1) &
                               & **2*y(3)*y(4) + 60*y(1)**2*y(4)**2 + 135*y(1)*y(2)**3 + 270*y(1)*y(2)**2*y(3) + 135*y(1)*y(2) &
                               & **2*y(4) + 165*y(1)*y(2)*y(3)**2 + 165*y(1)*y(2)*y(3)*y(4) + 30*y(1)*y(2)*y(4)**2 + 30*y(1)*y(3) &
                               & **3 + 45*y(1)*y(3)**2*y(4) + 15*y(1)*y(3)*y(4)**2 + 45*y(2)**4 + 120*y(2)**3*y(3) + 60*y(2) &
                               & **3*y(4) + 110*y(2)**2*y(3)**2 + 110*y(2)**2*y(3)*y(4) + 20*y(2)**2*y(4)**2 + 40*y(2)*y(3)**3 &
                               & + 60*y(2)*y(3)**2*y(4) + 20*y(2)*y(3)*y(4)**2 + 5*y(3)**4 + 10*y(3)**3*y(4) + 5*y(3)**2*y(4)**2)) &
                               & /(5*(y(1) + y(2))**2*(y(1) + y(2) + y(3))**2*(y(1) + y(2) + y(3) + y(4))**2)
                end do
            else
                ! (Fu, et al., 2016) Table 2 (for right flux)
                d_cbL (0,:) = 18._wp/35._wp
                d_cbL (1,:) = 3._wp/35._wp
                d_cbL (2,:) = 9._wp/35._wp
                d_cbL (3,:) = 1._wp/35._wp
                d_cbL (4,:) = 4._wp/35._wp

                d_cbR (0,:) = 18._wp/35._wp
                d_cbR (1,:) = 9._wp/35._wp
                d_cbR (2,:) = 3._wp/35._wp
                d_cbR (3,:) = 4._wp/35._wp
                d_cbR (4,:) = 1._wp/35._wp
            end if
        end if

        ! Detect whether grid spacing is uniform (enables cancellation-free sum-of-squares beta). Tolerance uses sqrt(epsilon) so it
        ! works in both double and single precision: ~1.5e-8 relative in double, ~3.5e-4 in single - above FP noise, below real
        ! stretching.
        uniform_grid(weno_dir) = .true.
        h0 = (s_cb(s) - s_cb(0))/real(s, wp)
        do i = 0, s - 1
            if (abs((s_cb(i + 1) - s_cb(i)) - h0) > sqrt(epsilon(h0))*abs(h0)) then
                uniform_grid(weno_dir) = .false.
                exit
            end if
        end do

        ! Nullifying WENO coefficients and cell-boundary locations pointers

        nullify (s_cb)

    end subroutine s_compute_weno_coefficients_impl

end module m_weno_coefficients
