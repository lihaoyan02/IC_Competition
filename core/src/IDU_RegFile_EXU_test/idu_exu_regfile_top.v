`include "macro.v"

module idu_exu_regfile_top (
    input clk,
    input rst,

    // IFU -> IDU
    input  [`XLEN-1:0] if_id_instr,
    input              if_id_instr_valid,
    input  [`XLEN-1:0] if_id_pc,
    output             id_if_instr_ready,

    // Simple external write port to Regfile (for TB preload / writeback emulation)
    input              tb_rf_we,
    input  [4:0]       tb_rf_rd_addr,
    input  [`XLEN-1:0] tb_rf_rd_data,

    // External inputs to EXU
    input              lsu_ex_ready,
    input  [`XLEN-1:0] csr_ex_rdata,

    // EXU -> IFU
    output             ex_if_pc_valid,
    output [`XLEN-1:0] ex_if_pc,
    output             ex_glb_flush,

    // EXU -> LSU payload
    output             ex_lsu_valid,
    output [`XLEN-1:0] ex_lsu_addr,
    output [`XLEN-1:0] ex_lsu_data,
    output [1:0]       ex_lsu_ctrl,
    output [1:0]       ex_lsu_size,
    output [`XLEN-1:0] ex_lsu_wb_data,
    output [4:0]       ex_lsu_wb_rd,
    output             ex_lsu_wb_wen
);

    //========================================================
    // Internal wires: IDU <-> Regfile
    //========================================================
    wire [4:0]         id_rf_rs1_addr;
    wire [4:0]         id_rf_rs2_addr;
    wire [`XLEN-1:0]   rf_id_rs1_data;
    wire [`XLEN-1:0]   rf_id_rs2_data;

    //========================================================
    // Internal wires: IDU -> EXU
    //========================================================
    wire               ex_id_ready;

    wire               id_ex_valid;
    wire [`XLEN-1:0]   id_ex_imm;
    wire [`XLEN-1:0]   id_ex_rs1_data;
    wire [`XLEN-1:0]   id_ex_rs2_data;
    wire [4:0]         id_ex_rd;
    wire [3:0]         id_ex_alu_ctrl;
    wire [1:0]         alu_op_ctrl;
    wire [`XLEN-1:0]   id_ex_pc;
    wire [2:0]         wb_ctrl;
    wire               id_ex_rf_we;
    wire               id_ex_lsu_en;
    wire               id_ex_lsu_we;
    wire [2:0]         id_ex_lsu_ctrl;
    wire               ebreak_flag;
    wire               j_en;
    wire [2:0]         id_ex_J_cond;

    //========================================================
    // IDU
    //========================================================
    IDU u_idu (
        .clk               (clk),
        .rst               (rst),

        .if_id_instr       (if_id_instr),
        .if_id_instr_valid (if_id_instr_valid),
        .if_id_pc          (if_id_pc),
        .id_if_instr_ready (id_if_instr_ready),

        .ex_id_ready       (ex_id_ready),
        .ex_glb_flush      (ex_glb_flush),

        .id_ex_valid       (id_ex_valid),
        .id_ex_imm         (id_ex_imm),
        .id_ex_rs1_data    (id_ex_rs1_data),
        .id_ex_rs2_data    (id_ex_rs2_data),
        .id_ex_rd          (id_ex_rd),
        .id_ex_alu_ctrl    (id_ex_alu_ctrl),
        .alu_op_ctrl       (alu_op_ctrl),
        .id_ex_pc          (id_ex_pc),
        .wb_ctrl           (wb_ctrl),
        .id_ex_rf_we       (id_ex_rf_we),
        .id_ex_lsu_en      (id_ex_lsu_en),
        .id_ex_lsu_we      (id_ex_lsu_we),
        .id_ex_lsu_ctrl    (id_ex_lsu_ctrl),
        .ebreak_flag       (ebreak_flag),
        .j_en              (j_en),
        .id_ex_J_cond      (id_ex_J_cond),

        .rf_id_rs1_data    (rf_id_rs1_data),
        .rf_id_rs2_data    (rf_id_rs2_data),
        .id_rf_rs1_addr    (id_rf_rs1_addr),
        .id_rf_rs2_addr    (id_rf_rs2_addr),

        .csr_wen           (),          // not used in this top TB
        .csr_event         (),          // not used in this top TB
        .csr_addr          ()           // not used in this top TB
    );

    //========================================================
    // Regfile
    //========================================================
    Regfile u_regfile (
        .clk      (clk),
        .rst      (rst),

        .rs1_addr (id_rf_rs1_addr),
        .rs2_addr (id_rf_rs2_addr),
        .rs1_data (rf_id_rs1_data),
        .rs2_data (rf_id_rs2_data),

        .we       (tb_rf_we),
        .rd_addr  (tb_rf_rd_addr),
        .rd_data  (tb_rf_rd_data)
    );

    //========================================================
    // EXU
    //========================================================
    EXU u_exu (
        .clk            (clk),
        .rst            (rst),

        .id_ex_valid    (id_ex_valid),
        .id_ex_pc       (id_ex_pc),
        .id_ex_imm      (id_ex_imm),
        .id_ex_rs1_data (id_ex_rs1_data),
        .id_ex_rs2_data (id_ex_rs2_data),
        .id_ex_rd       (id_ex_rd),
        .id_ex_alu_ctrl (id_ex_alu_ctrl),
        .alu_op_ctrl    (alu_op_ctrl),
        .wb_ctrl        (wb_ctrl),
        .id_ex_rf_we    (id_ex_rf_we),
        .id_ex_lsu_en   (id_ex_lsu_en),
        .id_ex_lsu_we   (id_ex_lsu_we),
        .id_ex_lsu_ctrl (id_ex_lsu_ctrl),
        .ebreak_flag    (ebreak_flag),
        .j_en           (j_en),
        .id_ex_J_cond   (id_ex_J_cond),

        .ex_id_ready    (ex_id_ready),
        .ex_glb_flush   (ex_glb_flush),

        .csr_ex_rdata   (csr_ex_rdata),

        .ex_if_pc_valid (ex_if_pc_valid),
        .ex_if_pc       (ex_if_pc),

        .ex_lsu_valid   (ex_lsu_valid),
        .lsu_ex_ready   (lsu_ex_ready),
        .ex_lsu_addr    (ex_lsu_addr),
        .ex_lsu_data    (ex_lsu_data),
        .ex_lsu_ctrl    (ex_lsu_ctrl),
        .ex_lsu_size    (ex_lsu_size),
        .ex_lsu_wb_data (ex_lsu_wb_data),
        .ex_lsu_wb_rd   (ex_lsu_wb_rd),
        .ex_lsu_wb_wen  (ex_lsu_wb_wen)
    );

endmodule