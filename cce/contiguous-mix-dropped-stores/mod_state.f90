module m_state
    implicit none
    type :: bounds
        integer :: beg, end
    end type bounds
    integer :: buff_size = 3
    real(8), allocatable :: dx(:), x_cc(:), x_cb(:)
    !$omp declare target(dx, x_cc, x_cb, buff_size)
end module m_state
