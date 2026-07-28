program v_write
    implicit none
    integer, parameter :: n = 64
    integer :: j, nd, nbad
    integer :: idx(3)
    integer :: out(1:n)
    nd = command_argument_count() + 1     ! nd = 1
    out = -1
    !$acc data copyin(nd) copyout(out)
    !$acc parallel loop gang vector private(idx)
    do j = 1, n
        idx(1) = 0; idx(2) = 0; idx(3) = 0
        idx(nd) = 5*j                     ! dynamic WRITE to element 1
        out(j) = idx(1)                   ! expect 5*j
    end do
    !$acc end parallel loop
    !$acc end data
    nbad = 0
    do j = 1, n
        if (out(j) /= 5*j) nbad = nbad + 1
    end do
    write (*, '(a,i0,a,i0,a)') 'v_write nbad=', nbad, ' of ', n, merge('  PASS', '  FAIL', nbad == 0)
    if (nbad > 0) write (*, '(a,i0,a,i0)') '   e.g. j=1 got ', out(1), ' expected ', 5
end program
