AFAR_ROOT = /work1/spencerbryngelson/sbryngelson/software/therock-afar-24.3.0-multiarch-10.1.0-592954c
FC        = $(AFAR_ROOT)/bin/amdflang
FFLAGS    = -fopenmp --offload-arch=gfx90a -O2
RUN_ENV   = LD_LIBRARY_PATH=$(AFAR_ROOT)/lib:$(AFAR_ROOT)/lib/llvm/lib:$$LD_LIBRARY_PATH OMP_TARGET_OFFLOAD=MANDATORY

BINS = repro repro_mfc_shape repro_present

.PHONY: all run clean

all: $(BINS)

%: %.f90
	$(FC) $(FFLAGS) -o $@ $<

# 23.2.1: the first two print "sum = 100.", the third faults.
# 24.3.0: all three fail before the kernel launches ("Failure to allocate device memory").
run: all
	@for b in $(BINS); do echo "--- $$b"; $(RUN_ENV) ./$$b 2>&1 | head -2; done

clean:
	rm -f $(BINS) *.mod *.o
