`timescale 1ns / 1ns
`include "macro.v"
module IFU_tb();
    // Clock and reset signals
    logic clk;
    logic rst;
        
    logic [`XLEN-1:0] wb_if_pc;
    logic wb_if_pc_valid;
    logic [`XLEN-1:0] if_id_instr;
    logic [`XLEN-1:0] if_id_pc;
    logic if_id_instr_valid;
    logic id_if_instr_ready;
    logic [`XLEN-1:0] imem_if_rdata;
    logic imem_if_rvalid;
    logic [`XLEN-1:0] if_imem_araddr;
    logic if_imem_arvalid;

    IFU u_ifu (
    .clk(clk),
    .rst(rst),
    //来自WB阶段的跳转信息
    .wb_if_pc(wb_if_pc),
    .wb_if_pc_valid(wb_if_pc_valid),

    //IF/ID寄存器
    .if_id_instr(if_id_instr),
    .if_id_pc(if_id_pc),
    .if_id_instr_valid(if_id_instr_valid),
    .id_if_instr_ready(id_if_instr_ready),

    //内存访问
    .imem_if_rdata(imem_if_rdata),
    .imem_if_rvalid(imem_if_rvalid),
    .if_imem_araddr(if_imem_araddr),
    .if_imem_arvalid(if_imem_arvalid)
    );
    
    IMEM u_imem (
    .rst(rst),
    .if_imem_araddr(if_imem_araddr),
    .imem_valid(if_imem_arvalid),
    .imem_if_rdata(imem_if_rdata),
    .imem_if_rvalid(imem_if_rvalid)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period
    end
    
    // Test stimulus
    initial begin
        rst = 1;
        wb_if_pc = 0;
        wb_if_pc_valid = 0;
        id_if_instr_ready = 0;
        #20 rst = 0;
        id_if_instr_ready = 1;
        
        #40 id_if_instr_ready = 0;
        #20 id_if_instr_ready = 1;

        #20
        id_if_instr_ready = 0;
        #20
        wb_if_pc_valid = 1;
        wb_if_pc = 32'h00000010;
        #10
        wb_if_pc_valid = 0; 
        id_if_instr_ready = 1;
        #400
        $display("Test completed!");
        
        $finish;
    end
    
    // Optional: Waveform dumping
    initial begin
        $dumpfile("build/waveform.vcd");
        $dumpvars(0, IFU_tb);
    end
    
endmodule
