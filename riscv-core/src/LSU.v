`include "macro.v"
module LSU (
    // Clock and Reset
    input clk,
    input rst,
    
    // Input from Execute Stage
    input ex_lsu_valid,
    output reg lsu_ex_ready,
    input [`XLEN-1:0] ex_lsu_addr,     // Memory address
    input [`XLEN-1:0] ex_lsu_data,     // Data to write
    input [1:0] ex_lsu_ctrl,           // 00: no action, 01: read, 10: write
    input [1:0] ex_lsu_size,        // 00: byte, 01: half-word, 10: word

    input ex_lsu_wb_data,
    input [4:0] ex_lsu_wb_rd,
    input ex_lsu_wb_wen,
    
    // Output to Write Back Unit
    output reg lsu_wbu_valid,
    input wbu_lsu_ready,
    output reg [`XLEN-1:0] lsu_wbu_data, // Data
    output reg [4:0] lsu_wbu_rd,        // Destination register
    output reg lsu_wbu_wen,             // Write enable for WBU

    // Memory Interface (AXI-like)
    output reg mem_awvalid,
    input mem_awready,
    output reg [`XLEN-1:0] mem_awaddr,
    
    output reg mem_wvalid,
    input mem_wready,
    output reg [`XLEN-1:0] mem_wdata,
    output reg [3:0] mem_wstrb, // Write strobe for byte enables

    input mem_bvalid,
    output reg mem_bready,

    output reg mem_arvalid,
    input mem_arready,
    output reg [`XLEN-1:0] mem_araddr,

    output reg mem_rvalid,
    input mem_rready,
    input [`XLEN-1:0] mem_rdata,
    input mem_rlast
);

endmodule