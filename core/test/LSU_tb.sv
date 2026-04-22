`include "macro.v"
`timescale 1ns/1ns
module LSU_tb;
    reg clk;
    reg rst;
    
    // EXU signals
    reg ex_lsu_valid;
    wire lsu_ex_ready;
    reg [`XLEN-1:0] ex_lsu_addr;
    reg [`XLEN-1:0] ex_lsu_data;
    reg [1:0] ex_lsu_ctrl;
    reg [1:0] ex_lsu_size;
    reg [`XLEN-1:0] ex_lsu_wb_data;
    reg [4:0] ex_lsu_wb_rd;
    reg ex_lsu_wb_wen;
    
    // WBU signals
    wire lsu_wbu_valid;
    wire [`XLEN-1:0] lsu_wbu_data;
    wire [4:0] lsu_wbu_rd;
    wire lsu_wbu_wen;
    
    // Cache signals
    wire lsu_cache_valid;
    wire lsu_cache_wen;
    wire [3:0] lsu_cache_wmask;
    wire [`XLEN-1:0] lsu_cache_addr;
    wire [`XLEN-1:0] lsu_cache_wdata;
    wire [1:0] lsu_cache_size;
    wire [`XLEN-1:0] cache_lsu_rdata;
    wire cache_lsu_hit;
    
    // Test counters
    integer test_num = 0;
    integer cycle_count = 0;
    
    L1_cache cache_inst (
        .clk(clk),
        .rst(rst),
        .valid(lsu_cache_valid),
        .wen(lsu_cache_wen),
        .addr(lsu_cache_addr),
        .wdata(lsu_cache_wdata),
        .wmask(lsu_cache_wmask),
        .size(lsu_cache_size),
        .rdata(cache_lsu_rdata),
        .hit(cache_lsu_hit)
    );
    
    // Instantiate LSU
    LSU lsu_inst (
        .clk(clk),
        .rst(rst),

        .ex_lsu_valid(ex_lsu_valid),
        .lsu_ex_ready(lsu_ex_ready),
        .ex_lsu_addr(ex_lsu_addr),
        .ex_lsu_data(ex_lsu_data),
        .ex_lsu_ctrl(ex_lsu_ctrl),
        .ex_lsu_size(ex_lsu_size),

        .ex_lsu_wb_data(ex_lsu_wb_data),
        .ex_lsu_wb_rd(ex_lsu_wb_rd),
        .ex_lsu_wb_wen(ex_lsu_wb_wen),

        .lsu_wbu_valid(lsu_wbu_valid),
        .lsu_wbu_data(lsu_wbu_data),
        .lsu_wbu_rd(lsu_wbu_rd),
        .lsu_wbu_wen(lsu_wbu_wen),

        .lsu_cache_valid(lsu_cache_valid),
        .lsu_cache_wen(lsu_cache_wen),
        .lsu_cache_addr(lsu_cache_addr),
        .lsu_cache_wdata(lsu_cache_wdata),
        .lsu_cache_wmask(lsu_cache_wmask),
        .lsu_cache_size(lsu_cache_size),
        .cache_lsu_rdata(cache_lsu_rdata),
        .cache_lsu_hit(cache_lsu_hit)
    );
    
    // Clock generation - 10ns period
    always begin
        #5 clk = ~clk;
    end
    
    // Task: Send a memory request and wait for handshake
    // Parameters:
    //   - addr: memory address
    //   - data: data to write (for write operations)
    //   - ctrl: control signal (00=no-op, 01=read, 10=write)
    //   - size: data size (00=byte, 01=half-word, 10=word)
    //   - wb_rd: destination register
    //   - wb_wen: write enable for destination register
    //   - wb_data: ALU result to pass through
    task send_memory_request(
        input [`XLEN-1:0] addr,
        input [`XLEN-1:0] data,
        input [1:0] ctrl,
        input [1:0] size,
        input [4:0] wb_rd,
        input wb_wen,
        input [`XLEN-1:0] wb_data,
        input is_consecutive = 0
    );
    begin
        
        test_num = test_num + 1;
        #1
        ex_lsu_valid = 1'b1;
        ex_lsu_addr = addr;
        ex_lsu_data = data;
        ex_lsu_ctrl = ctrl;
        ex_lsu_size = size;
        ex_lsu_wb_rd = wb_rd;
        ex_lsu_wb_wen = wb_wen;
        ex_lsu_wb_data = wb_data;
        
        // Wait for handshake: lsu_ex_ready must be 1
        @(posedge clk);
        cycle_count = cycle_count + 1;
        while (!lsu_ex_ready) begin       
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        $display("[Test %0d] Memory request sent at cycle %0d: addr=0x%08x, ctrl=%b, size=%b", 
                test_num, cycle_count, addr, ctrl, size);
        #1
        if (!is_consecutive) begin
            ex_lsu_valid = 1'b0;
        end
    end
    endtask
    
    // Task: Wait for WBU response
    task wait_wbu_response();
    begin
        while (!lsu_wbu_valid) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        $display("[WBU Response] at cycle %0d: data=0x%08x, rd=%0d, wen=%b", 
                 cycle_count, lsu_wbu_data, lsu_wbu_rd, lsu_wbu_wen);
    end
    endtask
    
    // Task: Wait for N cycles
    task wait_cycles(input integer n);
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
    end
    endtask
    
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        ex_lsu_valid = 0;
        ex_lsu_addr = 0;
        ex_lsu_data = 0;
        ex_lsu_ctrl = 2'b00;
        ex_lsu_size = 2'b00;
        ex_lsu_wb_rd = 0;
        ex_lsu_wb_wen = 0;
        ex_lsu_wb_data = 0;
        
        // Reset
        #10 rst = 0;
        wait_cycles(2);
        
        $display("\n========== LSU Test Suite ==========");
        $display("Testing LSU with byte, half-word, and word operations");
        
        // ========== Test Group 1: BYTE operations ==========
        $display("\n[Group 1] BYTE READ/WRITE tests");
        
        // Test 1: Write byte at address offset 0
        send_memory_request(32'h00000000, 32'h000000AA, 2'b10, 2'b00, 5'd1, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 2: Read byte at address offset 1
        send_memory_request(32'h00000001, 32'h0, 2'b01, 2'b00, 5'd2, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        // Test 3: Write byte at address offset 2
        send_memory_request(32'h00000002, 32'h000000BB, 2'b10, 2'b00, 5'd3, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 4: Read byte at address offset 3
        send_memory_request(32'h00000003, 32'h0, 2'b01, 2'b00, 5'd4, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        // ========== Test Group 2: HALF-WORD operations ==========
        $display("\n[Group 2] HALF-WORD READ/WRITE tests");
        
        // Test 5: Write half-word at address offset 0
        send_memory_request(32'h00000010, 32'h0000CCDD, 2'b10, 2'b01, 5'd5, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 6: Read half-word at address offset 0
        send_memory_request(32'h00000010, 32'h0, 2'b01, 2'b01, 5'd6, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        // Test 7: Write half-word at address offset 2
        send_memory_request(32'h00000012, 32'h0000EEFF, 2'b10, 2'b01, 5'd7, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 8: Read half-word at address offset 2
        send_memory_request(32'h00000012, 32'h0, 2'b01, 2'b01, 5'd8, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        // ========== Test Group 3: WORD operations ==========
        $display("\n[Group 3] WORD READ/WRITE tests");
        
        // Test 9: Write word at address 0x100
        send_memory_request(32'h00000100, 32'h11223344, 2'b10, 2'b10, 5'd9, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 10: Read word at address 0x100
        send_memory_request(32'h00000100, 32'h0, 2'b01, 2'b10, 5'd10, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        // Test 11: Write word at address 0x200
        send_memory_request(32'h00000200, 32'h55667788, 2'b10, 2'b10, 5'd11, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 12: Read word at address 0x300 (different address)
        send_memory_request(32'h00000300, 32'h0, 2'b01, 2'b10, 5'd12, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        // ========== Test Group 4: Mixed operations with cache misses ==========
        $display("\n[Group 4] MIXED operations with potential cache misses");
        
        // Test 13: Write at address 0x400
        send_memory_request(32'h00000400, 32'hDEADBEEF, 2'b10, 2'b10, 5'd13, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 14: Read from same address (may hit)
        send_memory_request(32'h00000400, 32'h0, 2'b01, 2'b10, 5'd14, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(2);
        
        // Test 15: Write half-word at 0x500
        send_memory_request(32'h00000500, 32'h0000CAFE, 2'b10, 2'b01, 5'd15, 1'b0, 32'h0);
        wait_cycles(1);
        
        // Test 16: Read byte from 0x500
        send_memory_request(32'h00000500, 32'h0, 2'b01, 2'b00, 5'd16, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(2);
        
        // ========== Test Group 5: Stress test with sequential accesses ==========
        $display("\n[Group 5] STRESS TEST: Sequential accesses");
        
        // Test 17-24: Sequential writes and reads
        send_memory_request(32'h00001000, 32'h11111111, 2'b10, 2'b10, 5'd17, 1'b0, 32'h0, 1'b1);
        
        send_memory_request(32'h00001004, 32'h22222222, 2'b10, 2'b10, 5'd18, 1'b0, 32'h0, 1'b1);
        
        send_memory_request(32'h00001008, 32'h33333333, 2'b10, 2'b10, 5'd19, 1'b0, 32'h0, 1'b1);
        
        send_memory_request(32'h0000100C, 32'h44444444, 2'b10, 2'b10, 5'd20, 1'b0, 32'h0, 1'b0);
        wait_cycles(1);
        
        // Now read them back
        send_memory_request(32'h00001000, 32'h0, 2'b01, 2'b10, 5'd21, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        send_memory_request(32'h00001004, 32'h0, 2'b01, 2'b10, 5'd22, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        send_memory_request(32'h00001008, 32'h0, 2'b01, 2'b10, 5'd23, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(1);
        
        send_memory_request(32'h0000100C, 32'h0, 2'b01, 2'b10, 5'd24, 1'b1, 32'h0);
        wait_wbu_response();
        wait_cycles(2);
        
        // ========== Test Group 6: No-operation mode ==========
        $display("\n[Group 6] NO-OPERATION tests");
        
        // Test 25: No memory operation (ctrl=00)
        send_memory_request(32'h00000000, 32'h0, 2'b00, 2'b10, 5'd25, 1'b1, 32'hABCDEF00);
        wait_wbu_response();
        wait_cycles(1);
        
        // ========== Test complete ==========
        wait_cycles(5);
        $display("\n========== Test Complete ==========\n");
        $display("Total tests executed: %0d", test_num);
        $display("Total cycles: %0d", cycle_count);
        #10 $finish;
    end
    
    initial begin
        $dumpfile("build/waveform.vcd");
        $dumpvars(0, LSU_tb);
    end

endmodule

