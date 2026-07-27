module m_callee                       ! stands in for m_mpi_common (-Oipa0)
    use m_state
    implicit none
contains
    subroutine sendrecv_grid(cell_boundaries, cell_centers, cell_widths, num_cells, offset)
        integer, intent(in)                 :: num_cells
        type(bounds), intent(in)            :: offset
        real(8), intent(inout)              :: cell_boundaries(-1 - offset%beg:)
        real(8), intent(inout)              :: cell_centers(-buff_size:)
        real(8), contiguous, intent(inout)  :: cell_widths(-buff_size:)
        integer :: i
        ! stand-in for the MPI receive into the high ghost layer
        do i = 1, buff_size
            cell_widths(num_cells + i) = cell_widths(num_cells - buff_size + i)
        end do
        do i = 1, offset%end
            cell_boundaries(num_cells + i) = cell_boundaries(num_cells + i - 1) + cell_widths(num_cells + i)
        end do
        do i = 1, buff_size
            cell_centers(num_cells + i) = cell_centers(num_cells + i - 1) &
                                          + (cell_widths(num_cells + i - 1) + cell_widths(num_cells + i))/2.d0
        end do
    end subroutine sendrecv_grid
end module m_callee
