.PHONY: run_all run $(ALL)

RESULT = .result
$(shell > $(RESULT))

COLOR_RED   = \033[1;31m
COLOR_GREEN = \033[1;32m
COLOR_NONE  = \033[0m

RISCV_TESTS_DIR = riscv-tests/isa
# ALL = $(basename $(notdir $(shell find $(RISCV_TESTS_DIR) -name "rv32ui-p-*.dump")))
ALL = rv32ui-p-addi

run_all: $(addprefix Makefile., $(ALL))
	@echo "test list [$(words $(ALL)) item(s)]:" $(ALL)

$(ALL): %: Makefile.%

Makefile.%: ./build/isa/%.bin
	@echo "NPCFLAGS = -b\nIMAGE = ../build/isa/$*.bin\nrun:" > $@
	@echo "\tmake -C ./core run ARGS=\$$(NPCFLAGS) IMG=\$$(IMAGE)" >> $@
	@if make -s -f $@; then \
		printf "[%14s] $(COLOR_GREEN)PASS$(COLOR_NONE)\n" $* >> $(RESULT); \
	else \
		printf "[%14s] $(COLOR_RED)***FAIL***$(COLOR_NONE)\n" $* >> $(RESULT); \
	fi
	-@rm -f Makefile.$*

run: run_all
	@cat $(RESULT)
	@rm $(RESULT)
