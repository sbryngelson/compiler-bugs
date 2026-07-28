program v_lb0
    implicit none
    integer, parameter :: n = 64
    integer :: j, nd, nbad
    real(8) :: g(0:n + 1), out(1:n), ref(1:n)
    integer :: idx(0:2)          ! <-- lower bound 0
    g = 0.0d0; g(20) = -150.0d0; g(21) = -150.0d0
    nd = command_argument_count()          ! nd = 0 selects idx(0) == first element
    out = -huge(1.0d0)
    !$acc data copyin(g, nd) copyout(out)
    !$acc parallel loop gang vector private(idx)
    do j = 1, n
        idx(0) = j; idx(1) = 1; idx(2) = 1
        idx(nd) = idx(nd) + 1
        out(j) = 0.5d0*(g(j) + g(idx(0)))
    end do
    !$acc end parallel loop
    !$acc end data
    do j = 1, n
        ref(j) = 0.5d0*(g(j) + g(j + 1))
    end do
    nbad = 0
    do j = 1, n
        if (abs(out(j) - ref(j)) > 1.0d-14) nbad = nbad + 1
    end do
    write (*, '(a,i0,a,i0,a)') 'v_lb0 nbad=', nbad, ' of ', n, merge('  PASS', '  FAIL', nbad == 0)
end program
