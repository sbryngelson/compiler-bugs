AFAR_ROOT = /work1/spencerbryngelson/sbryngelson/software/therock-afar-23.2.1-gfx90a-7.13.0-7357b5084b
FC        = $(AFAR_ROOT)/bin/amdflang
FFLAGS    = -cpp -fopenmp --offload-arch=gfx90a -O3
RUN_ENV   = LD_LIBRARY_PATH=$(AFAR_ROOT)/lib:$(AFAR_ROOT)/lib/llvm/lib:$$LD_LIBRARY_PATH

.PHONY: all run clean

all: hang fix

hang: repro.f90
	$(FC) $(FFLAGS) -o hang repro.f90

fix: repro.f90
	$(FC) $(FFLAGS) -DFIX -o fix repro.f90

run: all
	@echo "mapper symbol:  hang=$$(nm hang | grep -c omp_mapper)  fix=$$(nm fix | grep -c omp_mapper)"
	@echo "--- hang build (busy-loops; capped at 55s) ---"
	@$(RUN_ENV) OMP_TARGET_OFFLOAD=MANDATORY timeout 55 ./hang; echo "exit=$$? (124 = still spinning)"
	@echo "--- fix build (defaultmap present:allocatable) ---"
	@$(RUN_ENV) OMP_TARGET_OFFLOAD=MANDATORY ./fix

clean:
	rm -f hang fix *.mod *.o
