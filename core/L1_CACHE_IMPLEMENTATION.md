# LSU实现说明

## 概述

实现了L1数据缓存，用于LSU模块测试。该缓存具有以下特性：

1. **简单的内存架构**：1K个32位存储位置
2. **递增初始化**：每个地址存储其自身的地址值作为初值
3. **基于LFSR的随机命中**：使用线性反馈移位寄存器生成伪随机的命中/未命中信号
4. **读写支持**：支持字节、半字和字的读写操作，带写掩码

---

## 核心模块

### 1. L1_cache.v

**功能**：实现具有LFSR随机命中的简单数据缓存

#### 端口定义

| 端口名 | 方向 | 宽度 | 说明 |
|--------|------|------|------|
| clk | IN | 1 | 时钟信号 |
| rst | IN | 1 | 复位信号（高电平有效） |
| valid | IN | 1 | 有效请求信号 |
| wen | IN | 1 | 写使能信号 |
| addr | IN | 32 | 内存地址（使用低12位） |
| wdata | IN | 32 | 写入数据 |
| wmask | IN | 4 | 写掩码（按字节：bit0=byte0, bit1=byte1, ...） |
| size | IN | 2 | 数据大小：00=字节，01=半字，10=字 |
| rdata | OUT | 32 | 读出数据（组合逻辑输出） |
| hit | OUT | 1 | 命中信号（组合逻辑，hit = cache_hit & valid） |

#### 工作原理

##### 内存初始化
```verilog
for (i = 0; i < MEM_SIZE; i = i + 1) begin
    memory[i] = i;  // 每个32位单元存储其地址值
end
```

内存采用32位字粒度，共1K个单元。地址结构：
- addr[11:2] - 字地址，索引1K个32位单元
- addr[1:0] - 字节偏移，用于字节寻址

##### LFSR随机数生成器

使用Fibonacci型LFSR，反馈多项式为 $x^{32} + x^{31} + x^{29} + x^{27} + 1$

```verilog
assign lfsr_out = lfsr[31] ^ lfsr[30] ^ lfsr[28] ^ lfsr[26];
wire cache_hit = (lfsr[31:26] < LFSR_HIT_THRESHOLD);
assign hit = cache_hit & valid;  // Hit为组合逻辑，仅在valid=1时有效
```

- **LFSR_HIT_THRESHOLD = 20**：对应约62.5%的命中率
- LFSR在每个时钟周期更新为 lfsr <= {lfsr[30:0], lfsr_out}
- 使用LFSR的最高6位与阈值比较，获得更好的随机性
- **hit是组合逻辑信号**，实时反映当前周期的缓存命中状态

#### 数据读取（组合逻辑）

根据size和地址[1:0]提取相应字节：

```verilog
always @(*) begin
    case (size)
        2'b00: rdata = memory[mem_addr[9:2]] >> (mem_addr[1:0] * 8);   // 字节
        2'b01: rdata = memory[mem_addr[9:2]] >> (mem_addr[1] * 16);    // 半字
        2'b10: rdata = memory[mem_addr[9:2]];                           // 字
        default: rdata = memory[mem_addr[9:2]];
    endcase
end
```

- **字节读取**：根据addr[1:0]的值（0-3）右移8位的倍数（0/8/16/24）
- **半字读取**：根据addr[1]的值（0-1）右移0或16位
- **字读取**：直接返回整个32位单元

#### 数据写入（时序逻辑）

根据wmask将数据写入到相应的字节位置：

```verilog
always @(posedge clk) begin
    if (rst) begin
        lfsr <= 32'hACE1;
    end else begin
        lfsr <= {lfsr[30:0], lfsr_out};
        if (hit & wen) begin
            // Write hit - update memory with write mask
            if (wmask[0]) memory[mem_addr[11:2]][7:0]   <= wdata[7:0];
            if (wmask[1]) memory[mem_addr[11:2]][15:8]  <= wdata[15:8];
            if (wmask[2]) memory[mem_addr[11:2]][23:16] <= wdata[23:16];
            if (wmask[3]) memory[mem_addr[11:2]][31:24] <= wdata[31:24];
        end
    end
end
```

- wmask[i]为1时，更新memory的对应字节
- LSU负责根据size和addr[1:0]生成正确的wmask
- 写操作在缓存命中(hit=1)且wen=1时执行

#### 读写操作简述

**读操作（wen = 0 且 valid = 1）**：
- 命中时：rdata立即返回读取数据，hit = 1
- 未命中时：rdata返回该地址的原值，hit = 0（LSU停止流水线）

**写操作（wen = 1 且 valid = 1）**：
- 命中时：根据wmask更新内存，hit = 1
- 未命中时：不执行写操作，hit = 0（LSU停止流水线）

**无操作或无效请求**：
- valid = 0时：hit = 0，rdata返回原值
---

## LSU集成

LSU模块与L1_cache的交互实现了流水线的动态停止功能。

### LSU控制协议

```
lsu_ex_ready 握手信号说明：
- lsu_ex_ready = 1：执行阶段可以发送下一条指令
- lsu_ex_ready = 0：内存访问未命中，执行阶段需要等待
```

### 缓存命中流程（零延迟）
```
周期N：
  EXU发送请求 (ex_lsu_valid=1, ex_lsu_ctrl!=0)
              ↓
  LSU组合逻辑计算缓存命中
  cache_lsu_hit = cache_lsu_hit & ex_lsu_valid  (组合逻辑)
              ↓
  LSU立即生成 lsu_ex_ready = 1
              ↓
  握手成功，EXU可以继续下一条指令

周期N+1：
  LSU返回数据 lsu_wbu_valid = 1, lsu_wbu_data = cache_data
  数据流向WBU回写
```

### 缓存未命中流程（停止流水线）
```
周期N：
  EXU发送请求 (ex_lsu_valid=1, ex_lsu_ctrl!=0)
              ↓
  LSU检查缓存命中：cache_hit = 0
              ↓
  lsu_ex_ready = 0（停止握手） ⚠️
  LSU进入WAITING状态
  保存请求：pending_addr, pending_wdata, pending_wmask, etc.
              ↓
  EXU阻塞（不能发送新指令）

周期N+1到N+M：
  LSU持续向缓存发送WAITING状态的请求
  等待缓存随机命中

周期N+M（缓存命中）
  cache_hit = 1
  lsu_ex_ready = 1（恢复握手）
  LSU返回数据并回到IDLE状态
              ↓
  EXU继续执行

总流水线延迟 = M个周期
```

### 写操作流程

- **命中**：数据同周期写入，hit=1，流水线继续
- **未命中**：数据不写入，hit=0，流水线停止

### LSU的pending request机制

当缓存未命中时，LSU保存用户请求的各个字段：

```verilog
// 保存请求
pending_addr <= ex_lsu_addr;
pending_wdata <= wdata;      // LSU计算的对齐数据
pending_wmask <= wmask;      // LSU计算的写掩码
pending_size <= ex_lsu_size;
pending_rd <= ex_lsu_wb_rd;
pending_cache_wen <= cache_wen;  // 标记是读还是写

// 在WAITING状态，持续使用这些pending值
assign lsu_cache_addr = (lsu_state == WAITING) ? pending_addr : ex_lsu_addr;
assign lsu_cache_wdata = (lsu_state == WAITING) ? pending_wdata : wdata;
assign lsu_cache_wmask = (lsu_state == WAITING) ? pending_wmask : wmask;
```

---

## 参数配置

### 可调参数

**L1_cache中的命中率控制**
```verilog
localparam LFSR_HIT_THRESHOLD = 20;  // 范围0-32（6位，因为使用lfsr[31:26]）
```

**命中率计算**：

LFSR[31:26]是6位的值，范围为0-63。根据阈值，命中率约为：
$$\text{Hit Rate} = \frac{\text{LFSR\_HIT\_THRESHOLD}}{64}$$

| 阈值 | 命中率 | 用途 |
|------|--------|------|
| 0 | 0% | 测试完全未命中 |
| 8 | 12.5% | 高缓存未命中率 |
| 16 | 25% | 中高缓存未命中率 |
| 20 | 31.25% | **默认配置**（62.5%命中率） |
| 32 | 50% | 中等缓存未命中率 |
| 64 | 100% | 始终命中（实际最大值为63） |

> **注意**：LFSR[31:26]有6位，最大值为63（2^6-1=63），所以阈值范围实际为0-63。
> 当阈值为20时，cache_hit = (lfsr[31:26] < 20)，约62.5%的时间为真。

**调整命中率**：修改L1_cache.v中的LFSR_HIT_THRESHOLD值，重新编译即可。

---

## 测试方法

### 编译和运行

```bash
# 编译LSU_tb并生成波形
cd /home/lhy/IC_Competition/riscv-core
make TEST_TOPNAME=LSU_tb DUT_SRC="src/LSU.v src/L1_cache.v" test

# 查看波形（需要wave viewer）
make wave
# or
gtkwave build/waveform.vcd
```

### 测试场景覆盖

LSU_tb已包含25个测试用例，覆盖以下场景：

**Group 1-3：基本读写功能**
- 字节操作（byte）：addr[1:0]位置的单字节读写
- 半字操作（half-word）：16位数据对齐读写
- 字操作（word）：整个32位单元的读写

**Group 4：混合操作**
- 不同地址的读写组合
- 验证掩码生成正确性

**Group 5：压力测试**
- 顺序读写多个地址
- 验证LFSR的随机命中/未命中

**Group 6：特殊情况**
- 无操作（ctrl=00）的通过测试

### 握手协议验证点

1. **当选择lsu_ex_ready=1时**：
   - 请求被接收，EXU在当前周期末发出下一个请求
   - LSU在下一周期返回数据（lsu_wbu_valid=1）

2. **当hit=0时**：
   - lsu_ex_ready应该保持0
   - LSU进入WAITING状态，保存当前请求
   - EXU不能发送新请求

3. **波形观察重点**：
   - ex_lsu_valid, lsu_ex_ready的握手边界
   - lsu_wbu_valid, lsu_wbu_data的返回时序
   - 缓存未命中后lsu_cache_hit恢复为1的延迟

### 调试技巧

- **查看LFSR序列**：在TB中添加 $display("LFSR phase: %h, hit: %b", cache_inst.lfsr, lsu_cache_hit);
- **追踪pending寄存器**：监控LSU.v中的pending_*信号确保请求被正确保存
- **验证wmask**：检查lsu_cache_wmask确保字节位置正确
- **观察rdata延迟**：确认rdata在请求的同一周期可用

---

## 测试样例

### LSU_tb中的测试流程（摘要）

```systemverilog
// Task: 发送内存请求并等待握手完成
task send_memory_request(
    input [`XLEN-1:0] addr,
    input [`XLEN-1:0] data,
    input [1:0] ctrl,          // 00=no-op, 01=read, 10=write
    input [1:0] size,          // 00=byte, 01=half-word, 10=word
    input [4:0] wb_rd,
    input wb_wen,
    input [`XLEN-1:0] wb_data
);
begin
    #1 // 伪时序逻辑
    ex_lsu_valid = 1'b1;
    ex_lsu_addr = addr;
    ex_lsu_data = data;
    ex_lsu_ctrl = ctrl;
    ex_lsu_size = size;
    ex_lsu_wb_rd = wb_rd;
    ex_lsu_wb_wen = wb_wen;
    ex_lsu_wb_data = wb_data;
    
    // 关键：等待握手成功
    @(posedge clk);
    while (!lsu_ex_ready) @(posedge clk); // 若缓存未命中，这里会循环多次
    
    ex_lsu_valid = 1'b0;
end
endtask

// Task: 等待WBU返回数据
task wait_wbu_response();
begin
    while (!lsu_wbu_valid) @(posedge clk);
    // 此时 lsu_wbu_data 包含读取到的数据
end
endtask
```

### 具体测试示例

```systemverilog
// Test: 字节读写
send_memory_request(32'h00000000, 32'h000000AA, 2'b10, 2'b00, 5'd1, 1'b0, 32'h0);
// 发送：在地址0写入单字节0xAA
// LSU自动计算：wmask=4'b0001, wdata=0x000000AA（无移位）
// 如果缓存命中，数据立即写入memory[0][7:0]
// 如果缓存未命中，task会在while循环中等待，直到缓存命中

wait_cycles(1);

send_memory_request(32'h00000001, 32'h0, 2'b01, 2'b00, 5'd2, 1'b1, 32'h0);
// 发送：在地址1读取单字节
// LSU请求缓存返回数据，cache_inst.rdata返回 memory[0] >> 8
// 获得byte[1]的值

wait_wbu_response();
// task会等待lsu_wbu_valid=1
// 然后可以检查 lsu_wbu_data 中的返回值
```

### 预期波形特征

**缓存命中周期**：
```
    clk  ___/‾‾‾\___/‾‾‾\___/‾‾‾\___
    
    ex_lsu_valid ___/‾‾‾‾‾‾‾\___________
    lsu_ex_ready ___/‾‾‾‾‾‾‾\___________  ← 立即应答（零延迟）
    
周期N：send_memory_request启动，ex_lsu_valid=1
周期N：lsu_ex_ready立即=1（组合逻辑）
周期N≥N+1：send_memory_request返回，ex_lsu_valid=0
周期N+1：lsu_wbu_valid=1，返回数据
```

**缓存未命中周期**：
```
    clk  ___/‾‾‾\___/‾‾‾\___/‾‾‾\___/‾‾‾\___
    
    ex_lsu_valid ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
    lsu_ex_ready ___________________  ← 保持0（等待缓存）
    
    lsu_cache_hit __________/‾‾‾  ← LFSR随机产生
周期N：发送请求
周期N-N+M：等待缓存命中，lsu_ex_ready=0不变
周期N+M：缓存命中后，lsu_ex_ready=1，完成握手
周期N+M+1：返回数据
```

---

## LFSR详细说明

### LFSR实现

本L1_cache使用Fibonacci配置的LFSR，反馈多项式为：
$$x^{32} + x^{31} + x^{29} + x^{27} + 1$$

```verilog
// LFSR输出反馈
assign lfsr_out = lfsr[31] ^ lfsr[30] ^ lfsr[28] ^ lfsr[26];

// 每周期移位更新LFSR
lfsr <= {lfsr[30:0], lfsr_out};

// 基于LFSR高6位判断命中
wire cache_hit = (lfsr[31:26] < LFSR_HIT_THRESHOLD);
```

### 工作流程

1. **初始化**：lfsr_init = 32'hACE1（非零值）
2. **每周期**：
   - 计算反馈：lfsr_out = lfsr[31] ⊕ lfsr[30] ⊕ lfsr[28] ⊕ lfsr[26]
   - 移位并输入反馈：lfsr ← {lfsr[30:0], lfsr_out}
   - 评估命中：cache_hit = (lfsr[31:26] < 20)
3. **下周期**：使用新的lfsr值进行判断

### 为什么使用LFSR

1. **硬件高效**：仅需4个异或门和移位逻辑，面积小
2. **周期长**：最大周期2^32-1 ≈ 43亿个周期，无需重新初始化
3. **伪随机性好**：通过选择适当的反馈点，生成近似均匀分布的随机序列
4. **确定性可复现**：相同的初值产生相同的序列，便于调试和验证
5. **可配置**：通过改变阈值轻松调整命中率，无需改变LFSR

### LFSR周期与初值

- **当前配置**：初值 0xACE1，周期接近2^32
- **足够长以覆盖**：各种缓存访问模式、多个测试用例、长序列压力测试
- **初值选择**：必须非零（全0时LFSR死锁），当前值0xACE1经验证可产生好的随机分布

---

## 地址和掩码处理

### LSU中的地址对齐和掩码计算

LSU负责根据size和addr[1:0]生成正确的写掩码和数据对齐：

```verilog
// 写掩码计算（组合逻辑）
always @(*) begin
    wmask = 4'b0000;
    wdata = ex_lsu_data;
    if (ex_lsu_valid && ex_lsu_ctrl == 2'b10) begin  // Write operation
        case (ex_lsu_size)
            2'b00: begin  // Byte
                wmask = (4'b0001 << ex_lsu_addr[1:0]);
                wdata = ex_lsu_data << (ex_lsu_addr[1:0] * 8);
            end
            2'b01: begin  // Half-word
                wmask = (4'b0011 << ex_lsu_addr[1:0]);
                wdata = ex_lsu_data << (ex_lsu_addr[1:0] * 8);
            end
            2'b10: begin  // Word
                wmask = 4'b1111;
                wdata = ex_lsu_data;
            end
        endcase
    end
end
```

**示例**：

对于字节写入addr=0x1002, data=0xAB，size=00：
- wmask计算：(4'b0001 << 2'b10) = 4'b0100（bit2）
- wdata计算：0xAB << (2×8) = 0xAB000000
- 缓存执行：memory[addr[9:2]][23:16] ← 0xAB

对于半字写入addr=0x1002, data=0xCDEF，size=01：
- wmask计算：(4'b0011 << 2'b10) = 4'b1100（bit3,2）
- wdata计算：0xCDEF << (2×8) = 0xCDEF0000
- 缓存执行：memory[addr[9:2]][31:16] ← 0xCDEF

### L1_cache中的数据提取

rdata组合逻辑根据size和addr[1:0]从32位单元中提取数据：

```verilog
always @(*) begin
    case (size)
        2'b00: rdata = memory[addr[9:2]] >> (addr[1:0] * 8);   // 提取1字节
        2'b01: rdata = memory[addr[9:2]] >> (addr[1] * 16);    // 提取2字节（半字）
        2'b10: rdata = memory[addr[9:2]];                       // 提取4字节（字）
    endcase
end
```

**示例**：

读取addr=0x1002（字节偏移为2），memory[addr[9:2]]=0x12345678
- 字节读（size=00）：右移16位 → 0x56（bits[7:0]）
- 半字读（size=01）：addr[1]=1，右移16位 → 0x5678（bits[15:0]）
- 字读（size=10）：不移位 → 0x12345678（bits[31:0]）

---

## 内存初始化示例

初始化后的内存内容：

| 地址 | 值 | 备注 |
|------|-----|------|
| 0x000 | 0x00000000 | 地址=值初始化 |
| 0x001 | 0x00000001 | |
| 0x002 | 0x00000002 | |
| ... | ... | |
| 0x0FF | 0x000000FF | |
| 0x100 | 0x00000100 | 支持1K地址空间 |

通过写操作可以修改这些值。

---

## 注意事项

1. **地址映射**
   - addr[9:2]：字地址，索引1K个32位内存单元（0-1023）
   - addr[1:0]：字节偏移（0-3），用于内存内的字节寻址

2. **hit信号特性**
   - hit是**组合逻辑**，not register
   - hit = cache_hit & valid（仅当有效请求时hit才为1）
   - 实时反映当前周期的缓存命中情况

3. **rdata特性**
   - rdata是**组合逻辑**输出（类似Regfile）
   - 零延迟读取：同周期内访问内存并提取数据
   - 根据size自动进行字节提取

4. **写掩码原理**
   - 按字节粒度控制，支持任意字节组合的写入
   - LSU根据addr[1:0]和size生成wmask
   - L1_cache根据wmask决定更新哪些字节

5. **LFSR初值**
   - 初值：0xACE1（非零值确保LFSR正常工作）
   - 不会出现死锁状态（周期2^32-1）

6. **流水线停止机制**
   - 当hit=0时，lsu_ex_ready应为0以停止流水线
   - LSU在WAITING状态持续向缓存发送上一个请求
   - 直到缓存命中（hit=1）才返回IDLE状态

7. **LSU与缓存的协议**
   - LSU计算wmask和wdata，缓存被动接收
   - 缓存提供hit信号组合逻辑，LSU采样并生成lsu_ex_ready
   - 数据路径：rdata为组合逻辑，读数据零延迟

8. **测试建议**
   - 修改LFSR_HIT_THRESHOLD=0来测试完全未命中场景
   - 修改LFSR_HIT_THRESHOLD=64来测试始终命中场景
   - TB应该验证握手协议和流水线停止

---

## 扩展建议

如果要扩展为真实的L1缓存实现，可以添加：

1. 缓存行结构（tag+valid+data）
2. 替换策略（LRU、FIFO等）
3. 多路缓存（direct-mapped, 2-way, 4-way）
4. 缓存一致性协议
5. 内存总线接口（用于缓存未命中时从主存加载）

当前的简单实现专注于测试LSU的流水线控制功能。
