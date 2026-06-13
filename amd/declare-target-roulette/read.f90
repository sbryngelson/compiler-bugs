! TU3 (separate from decl + push) — ONE kernel reads both arrays with identical code.
module m_read
   use m_state
   implicit none
contains
   subroutine read_both(o_map, o_upd)
      integer, intent(out) :: o_map, o_upd
      !$omp target map(from: o_map, o_upd)
      o_map = rs_map(1)
      o_upd = rs_upd(1)
      !$omp end target
   end subroutine
end module m_read
