

ifdef CONFIG_DIFFTEST
DIFF_REF_SO = $(CORE_HOME)/tools/riscv32-spike-so

ARGS_DIFF = --diff=$(DIFF_REF_SO)


.PHONY: $(DIFF_REF_SO)
endif
