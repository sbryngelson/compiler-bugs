! The attached derived-type field `q%vf(1)%sf(k)` that MFC actually uses, in place of
! the plain `declare create` module array of element_in.f90. Identical outcome: the
! derived type contributes nothing to this defect beyond the shape of the source.
!
module m_dt
  implicit none
  integer, parameter :: wp = kind(1.0d0)
  type sf_t
    real(wp), pointer :: sf(:) => null()
  end type
  type vf_t
    type(sf_t), allocatable :: vf(:)
  end type
  real(wp), allocatable :: b(:)
  !$acc declare create(b)
contains
  subroutine inner(x, y)
    !$acc routine seq
    real(wp), intent(in)  :: x
    real(wp), intent(out) :: y
    integer :: it
    y = x
    !$acc loop seq            ! <=== same trigger
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program derived_type_in
  use m_dt
  implicit none
  integer, parameter :: n = 299
  integer :: k, bad
  real(wp) :: t
  type(vf_t) :: q
  allocate(q%vf(1)); allocate(q%vf(1)%sf(0:n))
  q%vf(1)%sf = [(real(k, wp), k = 0, n)]
  allocate(b(0:n)); b = 0.0_wp
  !$acc update device(b)
  !$acc enter data copyin(q)
  !$acc enter data copyin(q%vf)
  !$acc enter data copyin(q%vf(1))
  !$acc enter data copyin(q%vf(1)%sf)
  !$acc parallel loop private(t)
  do k = 0, n
    call inner(q%vf(1)%sf(k), t)         ! attached derived-type field element, intent(in)
    b(k) = t                             ! scalar out -- this direction is fine
  end do
  !$acc update host(b)
  bad = count(b /= q%vf(1)%sf + 8.0_wp)
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'dtype in    : bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
  print '(a,i0)', 'BAD=', bad
end program
