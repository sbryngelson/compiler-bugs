! TU 2: set the three variables on the host, push them to the device, call the kernel in
! repro_mod (a separate TU). The update reaches only this TU's device copy of the static
! variables, so the kernel reads its own still-zero copies; the allocatable is correct.
program repro_main
   use repro_mod
   implicit none
   integer :: out(3)
   allocate (a_ar(1))
   s_sc = 2
   s_ar = 2
   a_ar = 2
   !$omp target enter data map(to: s_sc, s_ar, a_ar)
   call kernel(out)
   print '(a,i0,a)', 'static SCALAR s_sc   = ', out(1), merge(' ok ', ' BUG', out(1) == 2)
   print '(a,i0,a)', 'static ARRAY  s_ar(1)= ', out(2), merge(' ok ', ' BUG', out(2) == 2)
   print '(a,i0,a)', 'alloc  ARRAY  a_ar(1)= ', out(3), merge(' ok ', ' BUG', out(3) == 2)
   if (out(1) /= 2 .or. out(2) /= 2) then
      print '(a)', '*** BUG: static declare-target stale across TU; make it allocatable ***'
      error stop 1
   end if
end program repro_main
