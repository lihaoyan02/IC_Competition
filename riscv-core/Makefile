TOPNAME = top
TEST_TOPNAME = Regfile_tb
DUT_SRC = src/Regfile.v

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
all: $(BIN)

$(BIN): $(VSRC) $(CSRC)
	@rm -rf $(OBJ_DIR)
	@$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

run: $(BIN)
	@$(BIN)

clean:
	@rm -rf $(BUILD_DIR)

#----------------sv test----------------
VERILATOR_TEST_FLAGS = -Wall --binary --build -O3 -sv --timing \
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
			--top-module $(TEST_TOPNAME) $^ \
			--Mdir $(TEST_OBJ_DIR) -o $(abspath $(TEST_BIN))

test: $(TEST_BIN)
	@$(TEST_BIN)

wave: test
	@gtkwave $(BUILD_DIR)/waveform.vcd

.PHONY: run clean test wave
