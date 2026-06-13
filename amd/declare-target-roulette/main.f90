program main
   use m_state; use m_push; use m_read
   implicit none
   integer :: o_map, o_upd
   call push()
   call read_both(o_map, o_upd)
   print '(a,i0,a)', 'array pushed via enter-data-map: ', o_map, merge('   STALE', '   ok   ', o_map /= 2)
   print '(a,i0,a)', 'array pushed via update-to     : ', o_upd, merge('   STALE', '   ok   ', o_upd /= 2)
   if (o_map /= o_upd) then
      print '(a)', '>>> SAME read, SAME kernel, two identical arrays DISAGREE -- correctness depends'
      print '(a)', '    only on an incidental, semantics-preserving choice (map vs update).'
      call exit(2)
   end if
end program main
