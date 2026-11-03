AFAR_ROOT ?= /path/to/therock-afar-24.3.0-multiarch-10.1.0-592954c
CC        = $(AFAR_ROOT)/bin/amdclang
FC        = $(AFAR_ROOT)/bin/amdflang
FLAGS     = -fopenmp --offload-arch=gfx942 -O2
RUN_ENV   = LD_LIBRARY_PATH=$(AFAR_ROOT)/lib:$(AFAR_ROOT)/lib/llvm/lib:$$LD_LIBRARY_PATH HSA_XNACK=1 OMP_TARGET_OFFLOAD=MANDATORY

.PHONY: all run clean

all: repro_c repro_f

repro_c: repro.c
	$(CC) $(FLAGS) -o $@ $<

repro_f: repro.f90
	$(FC) $(FLAGS) -o $@ $<

# MI300A only. Unpatched: `bad` is nonzero in nearly every launch (hundreds to thousands of 20M);
# the Fortran program prints nonzero bad records / duplicated cells / missing cells in most launches.
# Run each program in a fresh process; one trial per process is the C program's design.
run: all
	@for i in 1 2 3; do $(RUN_ENV) ./repro_c 20000000; done
	@$(RUN_ENV) ./repro_f

clean:
	rm -f repro_c repro_f *.mod *.o
