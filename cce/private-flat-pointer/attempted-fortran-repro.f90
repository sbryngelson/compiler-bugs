module m_pfp
    implicit none
contains
    subroutine s_fill(a, v)      ! forces 'a' to have an address
!$acc routine seq
        real(8), intent(inout) :: a(:)
        real(8), intent(in)    :: v
        integer :: k
        do k = 1, size(a)
            a(k) = v + real(k, 8)
        end do
    end subroutine
    subroutine s_work(out, j)
!$acc routine seq
        real(8), intent(out) :: out
        integer, intent(in)  :: j
        real(8) :: buf(4)        ! single local array; escapes via s_fill
        call s_fill(buf, real(j, 8))
        out = buf(1)
    end subroutine
end module
program p
    use m_pfp
    implicit none
    integer, parameter :: n = 256
    real(8) :: o(n); integer :: i, nbad
    o = -1.0d0
!$acc data copyout(o)
!$acc parallel loop gang vector
    do i = 1, n
        call s_work(o(i), i)
    end do
!$acc end data
    nbad = 0
    do i = 1, n
        if (o(i) /= real(i, 8) + 1.0d0) nbad = nbad + 1
    end do
    write (*, '(a,i0,a,i0,a)') 'pfp2 nbad=', nbad, ' of ', n, merge('  PASS', '  FAIL', nbad == 0)
end program
