AM_SRCS := riscv/core/start.S \
           riscv/core/trm.c \
           riscv/core/ioe.c \
           riscv/core/timer.c \
           riscv/core/input.c \
           riscv/core/cte.c \
           riscv/core/trap.S

CFLAGS    += -fdata-sections -ffunction-sections
LDSCRIPTS += $(AM_HOME)/scripts/linker.ld
LDFLAGS   += --defsym=_pmem_start=0x80000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections -e _start

NPCFLAGS += -l $(shell dirname $(IMAGE).elf)/core-log.txt
NPCFLAGS += -e $(IMAGE).elf
NPCFLAGS += -b

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = the_insert-arg_rule_in_Makefile_will_insert_mainargs_here
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=$(MAINARGS_PLACEHOLDER)

insert-arg: image
	@python $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) $(MAINARGS_PLACEHOLDER) "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -S --set-section-flags .bss=alloc,contents -O binary $(IMAGE).elf $(IMAGE).bin

run: insert-arg
	$(MAKE) -C $(CORE_HOME) run ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(CORE_HOME) gdb ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin

.PHONY: insert-arg
