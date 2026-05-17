
ifeq ($(ALL),IFU)
	TEST_TOPNAME = IFU_tb
	DUT_SRC = src/IFU.v src/IMEM.v
else ifeq ($(ALL),LSU)
	TEST_TOPNAME = LSU_tb
	DUT_SRC = src/LSU.v src/L1_cache.v
else
	TEST_TOPNAME = top_tb
	DUT_SRC = $(VSRC)
endif

VSRC=$(wildcard src/*.v)
CSRC=$(wildcard csrc/*.c)
BUILD_DIR=build

$(shell mkdir -p $(BUILD_DIR))

VERILATOR = verilator

#----------------cpp test----------------
all: $(TEST_BIN)

TOPNAME = top #之后用于cpu测试
export CORE_HOME=$(shell pwd)

-include $(CORE_HOME)/include/config/auto.conf
-include $(CORE_HOME)/include/config/auto.conf.cmd

CORE_DIR := $(CORE_HOME)
INC_PATH = $(CORE_DIR)/include

VERILATOR_CFLAGS += -I./src/include
VERILATOR_CFLAGS += -MMD -cc --build \
				-O3 --x-assign fast --x-initial fast --autoflush
VERILATOR_CFLAGS += $(if $(CONFIG_TRACE_WAVE), --trace-vcd)
BUILD_DIR = $(CORE_DIR)/build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

LDFLAGS = -lreadline -lhistory
LDFLAGS += $(if $(CONFIG_HAS_VGA), -lSDL2,)

$(shell mkdir -p $(BUILD_DIR))

include $(CORE_HOME)/csrc/utils/filelist.mk
# project source
VSRCS = $(wildcard src/*.v)
CSRCS-y = $(shell find csrc -name "*.cpp" -type f)
CSRCS-y += $(shell find csrc -name "*.c" -type f)
CSRCS = $(filter-out $(SRCS-BLACKLIST-y),$(CSRCS-y))


# rules for verilator
INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += $(INCFLAGS)
CXXFLAGS += $(if $(CONFIG_CC_DEBUG),-g,)
CXXFLAGS += $(if $(CONFIG_CC_ASAN),-fsanitize=address,)

# Some convenient rules 
include $(CORE_HOME)/scripts/difftest.mk

override ARGS ?=
override ARGS += --log=$(BUILD_DIR)/core-log.txt
override ARGS += $(ARGS_DIFF)

# Command to execute CORE
IMG ?= ../build/pascal.bin
CORE_EXEC := $(BIN) $(ARGS) $(IMG)

all: run-env
	@echo "Building CORE"

$(BIN): $(VSRCS) $(CSRCS)
	@rm -rf $(OBJ_DIR)
	@$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) 

run-env: $(BIN)


# image file
run: run-env
	$(CORE_EXEC)

gdb: run-env
	gdb -s $(BIN) --args $(CORE_EXEC)

.PHONY: run gdb

# Include rules for menuconfig


#-----------------------------------------sv test--------------------------------------------
VERILATOR_TEST_FLAGS = --binary --build -O3 -sv --timing \
			--trace --trace-structs \
			--x-assign fast --x-initial fast --autoflush
TEST_OBJ_DIR = $(BUILD_DIR)/test_obj_dir
TEST_BIN = $(BUILD_DIR)/$(TEST_TOPNAME)
TB_SRC = test/$(TEST_TOPNAME).sv

INCLUDE_DIRS = ./src/include

$(TEST_BIN): $(TB_SRC) $(DUT_SRC)
	@echo "=========================================="
	@echo "Verilator 正在编译..."
	@echo "Testbench: $(TB_SRC)"
	@echo "=========================================="
	@$(VERILATOR) $(VERILATOR_TEST_FLAGS) \
			-I$(INCLUDE_DIRS) \
			-DIMG_PATH="\"../build/add.bin\"" \
			-DSV_TEST="y" \
			--top-module $(TEST_TOPNAME) $^ \
			--Mdir $(TEST_OBJ_DIR) -o $(abspath $(TEST_BIN))

test: $(TEST_BIN)
	@$(TEST_BIN)


wave: $(BUILD_DIR)/waveform.vcd
	@gtkwave $(BUILD_DIR)/waveform.vcd

clean:
	@rm -rf $(BUILD_DIR)

.PHONY: clean test wave
include $(CORE_HOME)/scripts/config.mk
