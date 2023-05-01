## CCE15.0.1 Fortran + OpenACC Compiler Bugs

A set of cases that test the use of `!$acc declare XXXX` for module-scope global arrays and derived types.
Compile and run scripts are included as `compile.sh` for each case.
As of CCE15.0.1 some of these cases work and some do not.
These are associated with, or in close association with, bug report __OLCFDEV-1416, CAST-31898__.
