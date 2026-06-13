program minimal_whole_array_ops
    implicit none
    integer, parameter :: N = 64, M = 2
    integer :: A(N, M), out(N, M), i, k, nerr

    do i = 1, N
        do k = 1, M
            A(i, k) = i * k
        end do
    end do

    !$omp target teams distribute parallel do map(to:A) map(from:out)
    do i = 1, N
        out(i, :) = 2 * A(i, :)
    end do
    !$omp end target teams distribute parallel do

    nerr = 0
    do i = 1, N
        do k = 1, M
            if (out(i,k) /= 2*A(i,k)) nerr = nerr + 1
        end do
    end do

    if (nerr == 0) then
        print *, "PASS"
    else
        print *, "FAIL:", nerr, "of", N*M
        print *, "  out(1,1) =", out(1,1), " expected", 2*A(1,1)
    end if
end program
