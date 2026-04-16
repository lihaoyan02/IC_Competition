
# RISC-V Core

## Build and Test

### Prerequisites
- Make
- RISC-V GCC toolchain
- Simulation tools (verilator)
- waveform (gtkwave)

### Testing

To run tests:
需要指定测试sv（模块名字和文件名字需一致）和待测模块文件
也可以直接在Makefile中修改指定参数
示例：
```bash
make test TEST_TOPNAME=Regfile_tb DUT_SRC=src/Regfile.v
```
### 查看波形
请在sv中将波形dump到build/waveform.vcd文件中
```bash
make wave
```
### Clean Build Files

Remove generated files:

```bash
make clean
```

