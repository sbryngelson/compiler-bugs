! TU 1: owns a declare-target module variable and pushes it to the device.
module mod_a
  implicit none
  integer :: nsz = -999            ! host static initializer, distinct from 42
  !$omp declare target(nsz)
contains
  subroutine set_nsz(v)
    integer, intent(in) :: v
    nsz = v
    !$omp target update to(nsz)
  end subroutine set_nsz
end module mod_a
