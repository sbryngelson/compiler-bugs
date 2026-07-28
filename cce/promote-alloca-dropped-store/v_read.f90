program v_read
    implicit none
    integer, parameter :: n = 64
    integer :: j, nd, nbad, got
    integer :: idx(3)
    integer :: out(1:n)
    nd = command_argument_count() + 1     ! nd = 1
    out = -1
    !$acc data copyin(nd) copyout(out)
    !$acc parallel loop gang vector private(idx)
    do j = 1, n
        idx(1) = 10*j; idx(2) = 777; idx(3) = 888
        out(j) = idx(nd)                  ! dynamic READ at nd=1 -> expect 10*j
    end do
    !$acc end parallel loop
    !$acc end data
    nbad = 0
    do j = 1, n
        if (out(j) /= 10*j) nbad = nbad + 1
    end do
    write (*, '(a,i0,a,i0,a)') 'v_read nbad=', nbad, ' of ', n, merge('  PASS', '  FAIL', nbad == 0)
    if (nbad > 0) write (*, '(a,i0,a,i0)') '   e.g. j=1 got ', out(1), ' expected ', 10
end program
