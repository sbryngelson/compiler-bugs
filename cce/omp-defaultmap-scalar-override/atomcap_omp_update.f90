! MFC's counting pass: copy= (map tofrom) + atomic update, no defaultmap clause.
program atomupd
    implicit none
    integer, parameter :: n = 4096
    integer :: i, count
    count = 0
    !$omp target teams distribute parallel do map(tofrom:count)
    do i = 1, n
        !$omp atomic update
        count = count + 1
    end do
    write (*, '(a,i0,a,i0,a)') 'omp tofrom+update  : count=', count, ' of ', n, &
        merge('   PASS', '   FAIL', count == n)
end program atomupd
