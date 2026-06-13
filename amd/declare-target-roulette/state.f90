! Two IDENTICAL static declare-target arrays. The ONLY difference is how each is pushed to
! the device (see push.f90). They are read by the SAME kernel with the SAME code.
module m_state
   implicit none
   integer :: rs_map(2)   ! pushed via `target enter data map(to:)`
   integer :: rs_upd(2)   ! pushed via `target update to`
   !$omp declare target(rs_map)
   !$omp declare target(rs_upd)
end module m_state
