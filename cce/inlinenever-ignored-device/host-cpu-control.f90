module m
    implicit none
contains
    subroutine s_leaf(a, b, c)
!DIR$ INLINENEVER s_leaf
        real(8), intent(in)  :: a, b
        real(8), intent(out) :: c
        c = a*b + a/b
    end subroutine
    subroutine s_driver(x, y, n)
        real(8), intent(inout) :: x(:), y(:)
        integer, intent(in) :: n
        real(8) :: t
        integer :: i
        do i = 1, n
            call s_leaf(x(i), y(i), t); x(i) = t
        end do
    end subroutine
end module
program p
    use m
    real(8) :: x(64), y(64)
    x = 2.0d0; y = 3.0d0
    call s_driver(x, y, 64)
    print *, x(1)
end program
