! High register pressure: 8 live arrays of 32 doubles in a seq device routine,
! fully unrolled. On gfx90a the VGPR/AGPR register file is unified, so this is the
! shape of kernel where -mattr=-mai-insts removes half the budget and forces spills.
module m_rp
    implicit none
contains
    subroutine s_solve(a, b, c, n)
!$acc routine seq
        real(8), intent(inout) :: a(32), b(32), c(32)
        integer, intent(in)    :: n
        real(8) :: t(32), u(32), v(32), w(32), x(32), y(32), z(32), q(32)
        integer :: i, k
        !DIR$ UNROLL
        do i = 1, 32
            t(i) = a(i)*1.0d0 + b(i)/(1.0d0) + c(i)
            u(i) = a(i)*2.0d0 + b(i)/(2.0d0) + c(i)
            v(i) = a(i)*3.0d0 + b(i)/(3.0d0) + c(i)
            w(i) = a(i)*4.0d0 + b(i)/(4.0d0) + c(i)
            x(i) = a(i)*5.0d0 + b(i)/(5.0d0) + c(i)
            y(i) = a(i)*6.0d0 + b(i)/(6.0d0) + c(i)
            z(i) = a(i)*7.0d0 + b(i)/(7.0d0) + c(i)
            q(i) = a(i)*8.0d0 + b(i)/(8.0d0) + c(i)
        end do
        do k = 1, n
            !DIR$ UNROLL
            do i = 1, 32
                t(i) = t(i) + u(i)*v(i) - w(i)
                u(i) = u(i) + v(i)*w(i) - x(i)
                v(i) = v(i) + w(i)*x(i) - y(i)
                w(i) = w(i) + x(i)*y(i) - z(i)
                x(i) = x(i) + y(i)*z(i) - q(i)
                y(i) = y(i) + z(i)*q(i) - t(i)
                z(i) = z(i) + q(i)*t(i) - u(i)
                q(i) = q(i) + t(i)*u(i) - v(i)
            end do
        end do
        do i = 1, 32
            a(i) = t(i)+u(i)+v(i)+w(i)+x(i)+y(i)+z(i)+q(i)
        end do
    end subroutine
end module

program p
    use m_rp
    implicit none
    integer, parameter :: np = 2048
    real(8) :: A(32, np), B(32, np), C(32, np)
    integer :: j
    A = 1.0d0; B = 2.0d0; C = 3.0d0
!$acc data copy(A, B, C)
!$acc parallel loop gang vector
    do j = 1, np
        call s_solve(A(:, j), B(:, j), C(:, j), 3)
    end do
!$acc end data
    print *, 'A(1,1) =', A(1, 1)
end program
