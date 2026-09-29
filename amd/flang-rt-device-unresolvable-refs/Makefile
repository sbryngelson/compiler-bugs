AFAR_ROOT = /work1/spencerbryngelson/sbryngelson/software/therock-afar-24.3.0-multiarch-10.1.0-592954c
FC        = $(AFAR_ROOT)/bin/amdflang
FFLAGS    = -fopenmp --offload-arch=gfx90a -O2
RUN_ENV   = LD_LIBRARY_PATH=$(AFAR_ROOT)/lib:$(AFAR_ROOT)/lib/llvm/lib:$$LD_LIBRARY_PATH

.PHONY: run clean

# Stock 24.3.0: the device link fails with 7 undefined references.
# With the patched runtime (see README): links and prints 4.
repro: repro.f90
	$(FC) $(FFLAGS) -o repro repro.f90

run: repro
	@$(RUN_ENV) OMP_TARGET_OFFLOAD=MANDATORY ./repro

clean:
	rm -f repro *.mod *.o
