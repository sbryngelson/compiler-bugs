! TU2 (separate from the declaration) — host-set both to 2 and push to device, two ways.
module m_push
   use m_state
   implicit none
contains
   subroutine push()
      rs_map = 2
      rs_upd = 2
      !$omp target enter data map(to: rs_map)   ! push #1: enter-data map
      !$omp target update to(rs_upd)             ! push #2: update-to (what MFC's GPU_UPDATE does)
   end subroutine
end module m_push
