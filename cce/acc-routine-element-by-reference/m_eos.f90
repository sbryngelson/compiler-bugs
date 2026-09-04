module m_eos
  implicit none
  integer, parameter :: wp = kind(1.0d0)
  type scalar_field
    real(wp), pointer :: sf(:, :, :) => null()
  end type
  type vector_field
    type(scalar_field), allocatable :: vf(:)
  end type
  type idx_t
    integer :: e = 1, adv = 2, cont = 3
  end type
  type(idx_t) :: eqn
  real(wp), allocatable :: gam(:), pinf(:), rho0(:), c0(:), s(:)
  integer, allocatable :: eos(:)
  logical :: state_dependent = .false.
  !$acc declare create(eqn, gam, pinf, rho0, c0, s, eos, state_dependent)
contains
  subroutine reference_curve(rho, i, p_ref, e_ref, dp, de)
    !$acc routine seq
    real(wp), intent(in)  :: rho
    integer,  intent(in)  :: i
    real(wp), intent(out) :: p_ref, e_ref, dp, de
    real(wp) :: mu, d, up, us, dus
    integer :: it
    mu = rho/rho0(i) - 1.0_wp
    select case (eos(i))
    case (1)
      if (mu < 0.0_wp) then
        p_ref = rho0(i)*c0(i)**2*mu; dp = rho0(i)*c0(i)**2
      else
        up = c0(i)*mu/(1.0_wp - (s(i) - 1.0_wp)*mu)
        !$acc loop seq
        do it = 1, 8
          us = c0(i) + s(i)*up; dus = s(i)
          up = up - (us*mu - up*(1.0_wp + mu))/(dus*mu - (1.0_wp + mu))
        end do
        p_ref = rho0(i)*(c0(i) + s(i)*up)*up; dp = rho0(i)*c0(i)**2*exp(mu)
      end if
      e_ref = p_ref*mu/(2.0_wp*rho0(i)*(1.0_wp + mu)); de = dp*mu/rho0(i)
    case default
      p_ref = 0.0_wp; e_ref = 0.0_wp; dp = 0.0_wp; de = 0.0_wp
    end select
  end subroutine
  subroutine coefficients(alpha_rho, alpha, i, rho, gamma, pi_inf, dpi)
    !$acc routine seq
    real(wp), intent(in)  :: alpha_rho, alpha
    integer,  intent(in)  :: i
    real(wp), intent(out) :: rho, gamma, pi_inf, dpi
    real(wp) :: p_ref, e_ref, dp, de
    rho = max(alpha_rho, 1.0e-16_wp)/max(alpha, 1.0e-16_wp)
    if (state_dependent) then
      call reference_curve(rho, i, p_ref, e_ref, dp, de)
      gamma = 1.0_wp/0.4_wp; pi_inf = rho*e_ref - p_ref/0.4_wp; dpi = e_ref + rho*de - dp/0.4_wp
    else
      gamma = gam(i); pi_inf = pinf(i); dpi = 0.0_wp
    end if
  end subroutine
  subroutine bulk_modulus(pres, alpha, alpha_rho, i, blkmod)
    !$acc routine seq
    real(wp), intent(in)  :: pres, alpha, alpha_rho
    integer,  intent(in)  :: i
    real(wp), intent(out) :: blkmod
    real(wp) :: rho, gamma, pi_inf, dpi
    call coefficients(alpha_rho, alpha, i, rho, gamma, pi_inf, dpi)
    blkmod = ((gamma + 1.0_wp)*pres + pi_inf)/gamma - rho*dpi/gamma
  end subroutine
end module
