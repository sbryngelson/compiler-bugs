! A small local array, explicitly listed in the private clause of a target loop.
! Nothing about it is resident and nothing should look for it in the present table.
program privtest
    implicit none
    integer, parameter :: wp = selected_real_kind(15, 307), n = 256
    real(wp) :: out(n)
    real(wp) :: length(3)
    integer :: i, nbad
    out = -1
    !$omp target teams distribute parallel do map(from: out) private(length)
    do i = 1, n
        length(1) = real(i, wp)
        length(2) = 2*real(i, wp)
        length(3) = 3*real(i, wp)
        out(i) = length(1) + length(2) + length(3)
    end do
    nbad = 0
    do i = 1, n
        if (abs(out(i) - 6*real(i, wp)) > 1.0e-12_wp) nbad = nbad + 1
    end do
    write (*, '(a,i0,a,i0,a)') 'private-array  wrong=', nbad, ' of ', n, &
        merge('   PASS', '   FAIL', nbad == 0)
end program privtest
