AFAR_ROOT = /work1/spencerbryngelson/sbryngelson/software/therock-afar-23.2.1-gfx90a-7.13.0-7357b5084b
FC        = $(AFAR_ROOT)/bin/amdflang
FFLAGS    = -fopenmp --offload-arch=gfx90a -fopenmp-target-fast \
            -fopenmp-assume-threads-oversubscription \
            -fopenmp-assume-teams-oversubscription
RUN_ENV   = LD_LIBRARY_PATH=$(AFAR_ROOT)/lib:$(AFAR_ROOT)/lib/llvm/lib:$$LD_LIBRARY_PATH

TESTS = minimal_whole_array_ops \
        minimal_array_constructor

.PHONY: all clean run

all: $(TESTS)

%: %.f90
	$(FC) $(FFLAGS) -o $@ $<

run: $(TESTS)
	@echo "=== Running minimal reproducers (amdflang 23.2.1 / gfx90a) ==="
	@for t in $(TESTS); do \
	    echo "--- $$t ---"; \
	    $(RUN_ENV) ./$$t; \
	done
	@echo "=== Done ==="

clean:
	rm -f $(TESTS) *.mod *.o
