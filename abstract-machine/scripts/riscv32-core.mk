include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/core.mk
COMMON_CFLAGS += -march=rv32i_zicsr -mabi=ilp32  # overwrite
LDFLAGS       += -melf32lriscv                    # overwrite

AM_SRCS += riscv/core/libgcc/div.S \
           riscv/core/libgcc/muldi3.S \
           riscv/core/libgcc/multi3.c \
           riscv/core/libgcc/ashldi3.c \
           riscv/core/libgcc/unused.c
