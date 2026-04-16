module IDU (
    input clk,
    input rst_n,
    
    // Input from IFU
    input  [`XLEN-1:0]  if_id_instr,
    input  [`XLEN-1:0]  if_id_pc,
    input               if_id_instr_valid,
    output              id_if_instr_ready,
    
    // Output to EXU
    output reg id_ex_valid,
    input       ex_id_ready,
    output reg [2:0] id_ex_alu_ctrl,
    output reg [1:0] id_ex_op1,
    output reg [1:0] id_ex_op2,
    output reg [`XLEN-1:0] id_ex_imm,
    output reg [`XLEN-1:0] id_ex_rs1_data,
    output reg [`XLEN-1:0] id_ex_rs2_data
    
    //register file access
    output reg [4:0] id_rf_rs1_addr,
    output reg [4:0] id_rf_rs2_addr,
    input  [`XLEN-1:0] rf_id_rs1_data,
    input  [`XLEN-1:0] rf_id_rs2_data
    
);

    // Instruction decode logic here
    
endmodule