module mod_b
  use mod_a
  implicit none
contains
  ! two writes: one a literal constant, one the module variable
  subroutine probe(konst, fromvar)
    !$omp declare target
    integer, intent(out) :: konst, fromvar
    konst = 12345
    fromvar = nsz
  end subroutine probe
end module mod_b
