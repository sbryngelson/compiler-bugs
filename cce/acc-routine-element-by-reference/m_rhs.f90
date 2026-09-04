module m_rhs
  use m_eos
  implicit none
  real(wp), allocatable :: blkmod(:, :, :)
  !$acc declare create(blkmod)
contains
  subroutine by_element_idx(q, n)          ! MFC's form: field elements indexed through a device-resident type
    type(vector_field), intent(in) :: q
    integer, intent(in) :: n
    integer :: k, l, m
    !$acc parallel loop collapse(3) private(k, l, m)
    do m = 0, 0
      do l = 0, 0
        do k = 0, n
          call bulk_modulus(q%vf(eqn%e)%sf(k, l, m), q%vf(eqn%adv)%sf(k, l, m), q%vf(eqn%cont)%sf(k, l, m), 1, blkmod(k, l, m))
        end do
      end do
    end do
  end subroutine
  subroutine by_element_const(q, n)        ! same with literal indices
    type(vector_field), intent(in) :: q
    integer, intent(in) :: n
    integer :: k, l, m
    !$acc parallel loop collapse(3) private(k, l, m)
    do m = 0, 0
      do l = 0, 0
        do k = 0, n
          call bulk_modulus(q%vf(1)%sf(k, l, m), q%vf(2)%sf(k, l, m), q%vf(3)%sf(k, l, m), 1, blkmod(k, l, m))
        end do
      end do
    end do
  end subroutine
  subroutine elements_in_scalar_out(q, n)
    type(vector_field), intent(in) :: q
    integer, intent(in) :: n
    integer :: k, l, m
    real(wp) :: b
    !$acc parallel loop collapse(3) private(k, l, m, b)
    do m = 0, 0
      do l = 0, 0
        do k = 0, n
          call bulk_modulus(q%vf(1)%sf(k, l, m), q%vf(2)%sf(k, l, m), q%vf(3)%sf(k, l, m), 1, b)
          blkmod(k, l, m) = b
        end do
      end do
    end do
  end subroutine
  subroutine scalars_in_element_out(q, n)
    type(vector_field), intent(in) :: q
    integer, intent(in) :: n
    integer :: k, l, m
    real(wp) :: p, a, ar
    !$acc parallel loop collapse(3) private(k, l, m, p, a, ar)
    do m = 0, 0
      do l = 0, 0
        do k = 0, n
          p = q%vf(1)%sf(k, l, m)
          a = q%vf(2)%sf(k, l, m)
          ar = q%vf(3)%sf(k, l, m)
          call bulk_modulus(p, a, ar, 1, blkmod(k, l, m))
        end do
      end do
    end do
  end subroutine
  subroutine by_scalar(q, n)               ! the fix: scalars in, scalar out
    type(vector_field), intent(in) :: q
    integer, intent(in) :: n
    integer :: k, l, m
    real(wp) :: p, a, ar, b
    !$acc parallel loop collapse(3) private(k, l, m, p, a, ar, b)
    do m = 0, 0
      do l = 0, 0
        do k = 0, n
          p = q%vf(eqn%e)%sf(k, l, m)
          a = q%vf(eqn%adv)%sf(k, l, m)
          ar = q%vf(eqn%cont)%sf(k, l, m)
          call bulk_modulus(p, a, ar, 1, b)
          blkmod(k, l, m) = b
        end do
      end do
    end do
  end subroutine
end module
