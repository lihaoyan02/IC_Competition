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

// 根据PC读取指令
assign if_imem_araddr = pc;
assign if_imem_arvalid = (~rst) & (id_if_instr_ready | wb_if_pc_valid); // 只有在IF/ID准备好接受新指令时才发出地址请求

reg [`XLEN-1:0] pc;
always @(posedge clk) begin
	if (rst) pc <= 32'h0;
	else if(wb_if_pc_valid) begin
        pc <= wb_if_pc;
    end
    else if(imem_if_rvalid && id_if_instr_ready) begin
        pc <= pc + 4;
    end
    else begin
        pc <= pc;
    end      
end

always @(posedge clk) begin
    if (rst) begin
        if_id_instr <= 32'b0;
        if_id_pc <= 32'b0;
        if_id_instr_valid <= 1'b0;
    end
    else if(imem_if_rvalid & id_if_instr_ready) begin
        if_id_instr <= imem_if_rdata;
        if_id_pc <= pc;
        if_id_instr_valid <= 1'b1;
    end
    else begin
        if_id_instr <= if_id_instr;
        if_id_pc <= if_id_pc;
        if_id_instr_valid <= if_id_instr_valid;
    end
end
endmodule
