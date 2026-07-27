program p
    use m_state
    use m_caller
    implicit none
    integer, parameter :: m = 149
    type(bounds) :: off
    integer :: i
    real(8) :: h, worst
    h = 1.d0/300.d0
    off%beg = buff_size; off%end = buff_size
    allocate (dx(-buff_size:m + buff_size), x_cc(-buff_size:m + buff_size), x_cb(-1 - buff_size:m + buff_size))
    dx = h
    do i = -1 - buff_size, m + buff_size
        x_cb(i) = (i + 1)*h
    end do
    do i = -buff_size, m + buff_size
        x_cc(i) = (i + 0.5d0)*h
    end do
    dx(m + 1:m + buff_size) = 0.d0        ! ghost layer to be filled by the callee
    x_cb(m + 1:m + buff_size) = 0.d0
    x_cc(m + 1:m + buff_size) = 0.d0
    call populate(x_cb, x_cc, dx, off, m)
    worst = 0.d0
    do i = m + 1, m + buff_size
        worst = max(worst, abs(dx(i) - h), abs(x_cb(i) - (i + 1)*h), abs(x_cc(i) - (i + 0.5d0)*h))
    end do
    print *, '  ghost dx   =', dx(m + 1:m + buff_size)
    print *, '  ghost x_cb =', x_cb(m + 1:m + buff_size)
    print *, '  ghost x_cc =', x_cc(m + 1:m + buff_size)
    print *, '  worst deviation =', worst
    if (worst < 1.d-14) then
        print *, '  RESULT: ghosts OK'
    else
        print *, '  RESULT: *** GHOSTS CORRUPTED ***'
    end if
end program p
