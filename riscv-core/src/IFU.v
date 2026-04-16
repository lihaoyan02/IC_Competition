`include "macro.v"
module IFU (
    input                       clk,
    input                       rst,
    //来自WB阶段的跳转信息
    input       [`XLEN-1:0]     wb_if_pc,
    input                       wb_if_pc_valid,

    //IF/ID寄存器
    output reg  [`XLEN-1:0]  if_id_instr,
    output reg  [`XLEN-1:0]  if_id_pc,
    output reg          if_id_instr_valid,
    input               id_if_instr_ready,

    //内存访问
    input       [`XLEN-1:0]  imem_if_rdata,
    input               imem_if_rvalid,
    output      [`XLEN-1:0]  if_imem_araddr,
    output              if_imem_arvalid
);


endmodule