`include "macro.v"
module EXU (
    input clk,
    input rst,
    
    // From IDU (Instruction Decode Unit)

    input id_ex_valid,
    output reg ex_id_ready,
    input [2:0] id_ex_alu_ctrl,
    input [1:0] id_ex_op1,
    input [1:0] id_ex_op2,
    input [`XLEN-1:0] id_ex_imm,
    input [`XLEN-1:0] id_ex_rs1_data,
    input [`XLEN-1:0] id_ex_rs2_data,

    // to lsu (Load Store Unit)
    output reg ex_lsu_valid,
    input lsu_ex_ready,
    output reg [1:0] ex_lsu_ctrl, // 00: no action, 01: read, 10: write
    output reg [1:0] ex_lsu_size, // 00: byte, 01: half-word, 10: word
    output reg [`XLEN-1:0] ex_lsu_addr,
    output reg [`XLEN-1:0] ex_lsu_data
);
    
    // ALU and execution logic here
    
endmodule