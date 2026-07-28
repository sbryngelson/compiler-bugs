! MFC's counting pass: copy= (map tofrom) + atomic update, no defaultmap clause.
program atomupd
    implicit none
    integer, parameter :: n = 4096
    integer :: i, count
    count = 0
    !$acc parallel loop gang vector copy(count)
    do i = 1, n
        !$acc atomic update
        count = count + 1
    end do
    write (*, '(a,i0,a,i0,a)') 'acc copy+update    : count=', count, ' of ', n, &
        merge('   PASS', '   FAIL', count == n)
end program atomupd
