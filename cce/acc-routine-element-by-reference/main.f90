program repro
  use m_rhs
  use openacc
  implicit none
  integer, parameter :: n = 299
  type(vector_field) :: q
  integer :: i, k
  real(wp) :: ref(0:n), rho, gamma, pi_inf, dpi
  allocate(gam(2), pinf(2), rho0(2), c0(2), s(2), eos(2))
  !$acc enter data create(gam, pinf, rho0, c0, s, eos)
  gam = 2.5_wp; pinf = 0.0_wp; rho0 = 1.0_wp; c0 = 1.0_wp; s = 1.5_wp; eos = 1
  state_dependent = .true.   ! take the deep branch, as an MG case does
  !$acc update device(eqn, gam, pinf, rho0, c0, s, eos, state_dependent)
  allocate(q%vf(3))
  do i = 1, 3
    allocate(q%vf(i)%sf(0:n, 0:0, 0:0))
    q%vf(i)%sf(:, 0, 0) = [(0.9_wp + 0.1_wp*i + 1.0e-3_wp*k, k = 0, n)]
  end do
  !$acc enter data copyin(q)
  !$acc enter data copyin(q%vf)
  do i = 1, 3
    !$acc enter data copyin(q%vf(i))
    !$acc enter data copyin(q%vf(i)%sf)
  end do
  allocate(blkmod(0:n, 0:0, 0:0))
  !$acc enter data create(blkmod)
  do k = 0, n
    call bulk_modulus(q%vf(1)%sf(k, 0, 0), q%vf(2)%sf(k, 0, 0), q%vf(3)%sf(k, 0, 0), 1, ref(k))
  end do

  print '(a,i3)', 'devices: ', acc_get_num_devices(acc_get_device_type())
  blkmod = -1.0_wp
  !$acc update device(blkmod)
  !$acc parallel loop
  do k = 0, n
    blkmod(k, 0, 0) = real(k, wp)
  end do
  !$acc update host(blkmod)
  print '(a,i5,a,i5)', 'sanity store:      bad ', count(abs(blkmod(:, 0, 0) - [(real(k, wp), k = 0, n)]) > 0.0_wp), ' of ', n + 1

  call run(by_element_idx,   'element, type index: ')
  call run(by_element_const, 'element, const index:')
  call run(elements_in_scalar_out, 'elements in, scalar out:')
  call run(scalars_in_element_out, 'scalars in, element out:')
  call run(by_scalar,        'scalar:              ')
contains
  subroutine run(kernel, label)
    interface
      subroutine kernel(q, n)
        import :: vector_field
        type(vector_field), intent(in) :: q
        integer, intent(in) :: n
      end subroutine
    end interface
    character(*), intent(in) :: label
    blkmod = 0.0_wp
    !$acc update device(blkmod)
    call kernel(q, n)
    !$acc update host(blkmod)
    print '(a,a,i5,a,i5,2es14.6)', label, ' bad ', count(.not. (abs(blkmod(:, 0, 0) - ref) <= 1e-12_wp*abs(ref))), ' of ', n + 1, blkmod(0, 0, 0), ref(0)
  end subroutine
end program
