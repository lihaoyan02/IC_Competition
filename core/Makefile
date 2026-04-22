TOPNAME = top #之后用于cpu测试

ifeq ($(ALL),IFU)
	TEST_TOPNAME = IFU_tb
	DUT_SRC = src/IFU.v src/IMEM.v
else ifeq ($(ALL),LSU)
	TEST_TOPNAME = LSU_tb
	DUT_SRC = src/LSU.v src/L1_cache.v
else
	TEST_TOPNAME = LSU_tb
	DUT_SRC = src/LSU.v src/L1_cache.v
endif

VSRC=$(wildcard src/*.v)
CSRC=$(wildcard csrc/*.c)
BUILD_DIR=build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

$(shell mkdir -p $(BUILD_DIR))

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD -cc --build \
				-O3 --x-assign fast --x-initial fast --autoflush

#----------------cpp test----------------
all: $(TEST_BIN)

# $(BIN): $(VSRC) $(CSRC)
# 	@rm -rf $(OBJ_DIR)
# 	@$(VERILATOR) $(VERILATOR_CFLAGS) \
# 		--top-module $(TOPNAME) $^ \
# 		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

# run: $(BIN)
# 	@$(BIN)

#----------------sv test----------------
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
			--top-module $(TEST_TOPNAME) $^ \
			--Mdir $(TEST_OBJ_DIR) -o $(abspath $(TEST_BIN))

test: $(TEST_BIN)
	@$(TEST_BIN)


wave: $(BUILD_DIR)/waveform.vcd
	@gtkwave $(BUILD_DIR)/waveform.vcd

clean:
	@rm -rf $(BUILD_DIR)

.PHONY: run clean test wave
