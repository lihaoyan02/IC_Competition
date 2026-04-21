# Makefile for RISC-V 32I IC Competition
CROSS_COMPILE ?= riscv64-linux-gnu-
# CROSS_COMPILE ?= riscv32-unknown-elf-
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

CFLAGS = -march=rv32i -mabi=ilp32 -Wall -O2 -nostdlib -ffreestanding -fno-builtin -I$(SRC_DIR)/include
LDFLAGS = -T script/link.ld -gc-sections -e _start -melf32lriscv

BUILD_DIR = build
TEST_DIR = test
SCRIPT_DIR = script
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

# ELF, BIN, and TXT files to generate
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

clean:
	rm -rf $(BUILD_DIR)