# Makefile for RISC-V 32I IC Competition
#CROSS_COMPILE ?= riscv64-unknown-linux-gnu-  #For JJ
CROSS_COMPILE ?= riscv64-linux-gnu-
# CROSS_COMPILE ?= riscv32-unknown-elf-
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

CFLAGS = -march=rv32i -mabi=ilp32 -Wall -O2 -nostdlib -ffreestanding -fno-builtin -I$(SRC_DIR)/include
LDFLAGS = -T scripts/link.ld -gc-sections -e _start -melf32lriscv

BUILD_DIR = build
TEST_DIR = test
SCRIPT_DIR = scripts
SRC_DIR = src
$(shell mkdir -p $(BUILD_DIR))
# Source files
TEST_C_SOURCES = $(wildcard $(TEST_DIR)/*.c)
SRC_C_SOURCES = $(wildcard $(SRC_DIR)/*.c)
SRC_ASM_SOURCES = $(wildcard $(SRC_DIR)/*.S)

# If ALL is specified, compile only that test
ifdef ALL
  TESTS = $(ALL)
else
  # Default: compile all test files
  TESTS = $(basename $(notdir $(TEST_C_SOURCES)))
endif

# Compile src files (both .c and .S) into object files
SRC_OBJECTS = $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(SRC_C_SOURCES)) \
              $(patsubst $(SRC_DIR)/%.S,$(BUILD_DIR)/%.o,$(SRC_ASM_SOURCES))

# Test objects
TEST_OBJECTS = $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(TESTS)))

# ELF, BIN, HEX, and TXT files to generate
ELF_FILES = $(addprefix $(BUILD_DIR)/,$(addsuffix .elf,$(TESTS)))
BIN_FILES = $(addprefix $(BUILD_DIR)/,$(addsuffix .bin,$(TESTS)))
TXT_FILES = $(addprefix $(BUILD_DIR)/,$(addsuffix .txt,$(TESTS)))

.PHONY: all clean

all: $(ELF_FILES) $(BIN_FILES) $(TXT_FILES)

# Compile src/*.c files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Compile src/*.S files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	$(CC) $(CFLAGS) -c $< -o $@

# Compile test/*.c files
$(BUILD_DIR)/%.o: $(TEST_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link test files with src libraries
$(BUILD_DIR)/%.elf: $(BUILD_DIR)/%.o $(SRC_OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

# Generate binary files
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O binary $< $@

# Generate disassembly files
$(BUILD_DIR)/%.txt: $(BUILD_DIR)/%.elf
	$(OBJDUMP) -d -S $< > $@


.PHONY: run_all run $(ALL)

RESULT = .result
$(shell > $(RESULT))

COLOR_RED   = \033[1;31m
COLOR_GREEN = \033[1;32m
COLOR_NONE  = \033[0m

ALL = $(basename $(notdir $(shell find test/. -name "*.c")))

run_all: $(addprefix Makefile., $(ALL))
	@echo "test list [$(words $(ALL)) item(s)]:" $(ALL)

$(ALL): %: Makefile.%

Makefile.%: test/%.c
	@echo "NPCFLAGS = -b\nIMAGE = ../build/$*.bin\nrun:" > $@
	@echo "\tmake -C ./core run ARGS=\$$(NPCFLAGS) IMG=\$$(IMAGE)" >> $@
	@if make -s -f $@; then \
		printf "[%14s] $(COLOR_GREEN)PASS$(COLOR_NONE)\n" $* >> $(RESULT); \
	else \
		printf "[%14s] $(COLOR_RED)***FAIL***$(COLOR_NONE)\n" $* >> $(RESULT); \
	fi
	-@rm -f Makefile.$*

run: run_all all
	@cat $(RESULT)
	@rm $(RESULT)

clean:
	rm -rf $(BUILD_DIR)
