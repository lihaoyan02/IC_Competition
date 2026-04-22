`timescale 1ns/1ps

module Regfile_tb;
    parameter WIDTH = 32;
    parameter ADDR_WIDTH = 5;

    // Clock and reset
    logic clk;
    logic rst;

    // Read ports
    logic [ADDR_WIDTH-1:0] read_addr1, read_addr2;
    logic [WIDTH-1:0] read_data1, read_data2;

    // Write port
    logic [ADDR_WIDTH-1:0] write_addr;
    logic [WIDTH-1:0] write_data;
    logic write_en;

    // Instantiate DUT
    Regfile dut (
        .clk(clk),
        .rst(rst),
        .rs1_addr(read_addr1),
        .rs2_addr(read_addr2),
        .rs1_data(read_data1),
        .rs2_data(read_data2),
        .rd_addr(write_addr),
        .rd_data(write_data),
        .we(write_en)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Waveform dumping
    initial begin
        $dumpfile("build/waveform.vcd");   // 指定波形文件名
        $dumpvars(0, Regfile_tb);     // 转储所有层级信号（0 表示所有层级）
    end

    // Test sequence
    initial begin
        rst = 1;
        write_en = 0;
        read_addr1 = 0;
        read_addr2 = 0;
        write_addr = 0;
        write_data = 0;

        #10 rst = 0;

        // Test 1: Write to register x1
        #10 write_addr = 5'd1;
        write_data = 32'hDEADBEEF;
        write_en = 1;

        // Test 2: Read from x1 via port1
        #10 read_addr1 = 5'd1;
        #5 assert(read_data1 == 32'hDEADBEEF) else $error("Read x1 failed");

        // Test 3: Write to register x5, read from x1 and x5
        #10 write_addr = 5'd5;
        write_data = 32'hCAFEBABE;
        #10 read_addr1 = 5'd5;
        read_addr2 = 5'd1;
        #5 assert(read_data1 == 32'hCAFEBABE) else $error("Read x5 failed");
        assert(read_data2 == 32'hDEADBEEF) else $error("Read x1 via port2 failed");

        // Test 4: x0 should always be 0
        #10 read_addr1 = 5'd0;
        #5 assert(read_data1 == 32'h0) else $error("x0 is not 0");

        // Test 5: Disable write, verify no change
        #10 write_en = 0;
        write_addr = 5'd1;
        write_data = 32'hFFFFFFFF;
        #10 read_addr1 = 5'd1;
        #5 assert(read_data1 == 32'hDEADBEEF) else $error("Write should be disabled");

        $display("All tests passed!");
        #10 $finish;
    end

endmodule
