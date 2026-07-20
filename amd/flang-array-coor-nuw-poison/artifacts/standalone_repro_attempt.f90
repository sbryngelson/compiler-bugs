! Standalone extraction of the reversed-slice 4-wide difference vector + poly_coef
! formulas from the WENO7 branch of s_compute_weno_coefficients.
!
! NOTE: This does NOT reproduce the miscompile. Compiled by amdflang 23.1.0 and
! 23.2.0 at both -O1 and -O3, all four produce the identical checksum
! (1.89090500058878689E+02). This is the key evidence that the bug is
! CONTEXT-DEPENDENT: the same loop, pulled out of the ~420-line WENO7 block,
! is unrolled correctly. The trigger is the full routine's size / register
! pressure, not this loop in isolation. Included to document the reduction attempt.
program repro
    implicit none
    integer, parameter :: wp = kind(1.0d0)
    integer, parameter :: nc = 200
    real(wp) :: s_cb(-4:nc + 4)
    real(wp) :: pL(0:3, 0:2, 1:nc)
    real(wp) :: y(1:4)
    integer  :: i
    do i = -4, nc + 4
        s_cb(i) = real(i, wp) + 0.013_wp*real(i, wp)**2 - 0.002_wp*real(i, wp)**3
    end do
    pL = 0._wp
    do i = 4, nc - 4
        y = s_cb(i + 1:i - 2:-1) - s_cb(i:i - 3:-1)          ! reversed 4-wide slice
        pL(3, 2, i) = (y(1)*y(2)*(y(2) + y(3)))/((y(3) + y(4))*(y(2) + y(3) + y(4))*(y(1) + y(2) + y(3) + y(4)))
        pL(3, 0, i) = (y(1)*(y(1)**2 + 3*y(1)*y(2) + 2*y(1)*y(3) + y(4)*y(1) + 3*y(2)**2 + 4*y(2)*y(3) &
                     & + 2*y(4)*y(2) + y(3)**2 + y(4)*y(3)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) + y(4)))
        y = s_cb(i + 2:i - 1:-1) - s_cb(i + 1:i - 2:-1)      ! reversed 4-wide slice
        pL(2, 0, i) = (y(2)*y(3)*(y(3) + y(4)))/((y(1) + y(2))*(y(1) + y(2) + y(3))*(y(1) + y(2) + y(3) + y(4)))
    end do
    print '(A,ES24.17)', 'checksum = ', sum(pL)
end program
