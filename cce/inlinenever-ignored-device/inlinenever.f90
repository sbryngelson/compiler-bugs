! !DIR$ INLINENEVER is accepted on a device routine but the emitted LLVM IR
! carries alwaysinline, so LTO inlines the routine anyway.
module m_kernel
    implicit none
contains

    subroutine s_leaf(a, b, c)
!$acc routine seq
!DIR$ INLINENEVER s_leaf
        real(8), intent(in)  :: a, b
        real(8), intent(out) :: c
        c = a*b + a/b
    end subroutine s_leaf

    subroutine s_driver(x, y, n)
        real(8), intent(inout) :: x(:), y(:)
        integer, intent(in)    :: n
        real(8) :: t
        integer :: i
!$acc parallel loop gang vector present(x, y) private(t)
        do i = 1, n
            call s_leaf(x(i), y(i), t)
            x(i) = t
        end do
    end subroutine s_driver

end module m_kernel

program p
    use m_kernel
    implicit none
    integer, parameter :: n = 1024
    real(8) :: x(n), y(n)
    x = 2.0d0; y = 3.0d0
!$acc data copy(x, y)
    call s_driver(x, y, n)
!$acc end data
    print *, 'x(1) =', x(1)
end program p
