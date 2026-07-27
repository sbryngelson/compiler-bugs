module m_caller                       ! stands in for m_boundary_common (full IPA)
    use m_state
    use m_callee
    implicit none
contains
    subroutine populate(x_cb_in, x_cc_in, dx_in, x_offset, m)
        integer, intent(in)      :: m
        type(bounds), intent(in) :: x_offset
        real(8), intent(inout)   :: x_cb_in(-1 - x_offset%beg:)
        real(8), intent(inout)   :: x_cc_in(-buff_size:), dx_in(-buff_size:)
        call bc_direction(x_cb_in, x_cc_in, dx_in, m, x_offset)
    end subroutine populate

    subroutine bc_direction(cell_boundaries, cell_centers, cell_widths, num_cells, offset)
        integer, intent(in)      :: num_cells
        type(bounds), intent(in) :: offset
        real(8), intent(inout)   :: cell_boundaries(-1 - offset%beg:)
        real(8), intent(inout)   :: cell_centers(-buff_size:), cell_widths(-buff_size:)
        call sendrecv_grid(cell_boundaries, cell_centers, cell_widths, num_cells, offset)
    end subroutine bc_direction
end module m_caller
