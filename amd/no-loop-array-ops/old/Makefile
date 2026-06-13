AFAR_ROOT = /work1/spencerbryngelson/sbryngelson/software/therock-afar-23.2.1-gfx90a-7.13.0-7357b5084b
FC        = $(AFAR_ROOT)/bin/amdflang
FFLAGS    = -fopenmp --offload-arch=gfx90a -fopenmp-target-fast \
            -fopenmp-assume-threads-oversubscription \
            -fopenmp-assume-teams-oversubscription
RUN_ENV   = LD_LIBRARY_PATH=$(AFAR_ROOT)/lib:$(AFAR_ROOT)/lib/llvm/lib:$$LD_LIBRARY_PATH

TESTS = test01_dt_elem_access \
        test02_dt_array_constructor \
        test04_dt_zero_init \
        test05_device_routine_int_arg \
        test06_dt_member_as_array_arg \
        test07_module_param_array \
        test08_dt_private_array_elems \
        test09_dt_arr7_arithmetic \
        test10_hlld_flux \
        test11_hlld_full \
        test12_sum_in_gpu_routine \
        test13_sum_explicit_shape \
        test14_disc_fastmath \
        test14b_disc_extreme \
        test18_sum_private \
        test19_array_slicing

.PHONY: all clean run

all: $(TESTS)

%: %.f90
	$(FC) $(FFLAGS) -o $@ $<

run: $(TESTS)
	@echo "=== Archived passing tests (amdflang 23.2.1 / gfx90a) ==="
	@for t in $(TESTS); do \
	    echo "--- $$t ---"; \
	    $(RUN_ENV) ./$$t; \
	done
	@echo "=== Done ==="

clean:
	rm -f $(TESTS) *.mod *.o
