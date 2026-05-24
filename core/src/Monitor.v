/*
`include "macro.v"

module monitor (
    input clk,
    input rst,

    // IFU -> IDU
    input [`XLEN-1:0] if_id_pc,
    input [`XLEN-1:0] if_id_instr,
    input             if_id_instr_valid,
    input             id_if_instr_ready,

    // IDU -> EXU
    input             id_ex_valid,
    input [`XLEN-1:0] id_ex_pc,
    input [`XLEN-1:0] id_ex_imm,
    input [4:0]       id_ex_rd,
    input [4:0]       id_ex_rs1_addr,
    input [4:0]       id_ex_rs2_addr,
    input [3:0]       id_ex_alu_ctrl,
    input [1:0]       alu_op_ctrl,
    input [2:0]       wb_ctrl,
    input             id_ex_rf_we,
    input             id_ex_lsu_en,
    input             id_ex_lsu_we,
    input [2:0]       id_ex_lsu_ctrl,
    input             j_en,
    input [2:0]       id_ex_J_cond,
    input             id_ex_is_uload,

    // EXU branch / flush
    input [`XLEN-1:0] ex_if_pc,
    input             ex_if_pc_valid,
    input             ex_glb_flush,
    input             ex_id_ready,

    // EXU -> LSU
    input             ex_lsu_valid,
    input             lsu_ex_ready,
    input [`XLEN-1:0] ex_lsu_pc,
    input [`XLEN-1:0] ex_lsu_addr,
    input [`XLEN-1:0] ex_lsu_data,
    input [`XLEN-1:0] ex_lsu_wb_data,
    input [1:0]       ex_lsu_ctrl,
    input [1:0]       ex_lsu_size,
    input [4:0]       ex_lsu_wb_rd,
    input             ex_lsu_wb_wen,
    input             ex_lsu_is_uload,

    // LSU -> WBU
    input             lsu_wbu_valid,
    input [`XLEN-1:0] lsu_wb_pc,
    input [`XLEN-1:0] lsu_wbu_data,
    input [4:0]       lsu_wbu_rd,
    input             lsu_wbu_wen,

    // WBU -> Regfile
    input [`XLEN-1:0] wb_rf_data,
    input             wb_rf_wen,
    input [4:0]       wb_rf_rd
);

    monitor_ifu_idu u_ifu_idu (
        .clk               (clk),
        .rst               (rst),
        .if_id_pc          (if_id_pc),
        .if_id_instr       (if_id_instr),
        .if_id_instr_valid (if_id_instr_valid),
        .id_if_instr_ready (id_if_instr_ready)
    );

    monitor_idu_exu u_idu_exu (
        .clk               (clk),
        .rst               (rst),
        .id_ex_valid       (id_ex_valid),
        .id_ex_pc          (id_ex_pc),
        .id_ex_imm         (id_ex_imm),
        .id_ex_rd          (id_ex_rd),
        .id_ex_rs1_addr    (id_ex_rs1_addr),
        .id_ex_rs2_addr    (id_ex_rs2_addr),
        .id_ex_alu_ctrl    (id_ex_alu_ctrl),
        .alu_op_ctrl       (alu_op_ctrl),
        .wb_ctrl           (wb_ctrl),
        .id_ex_rf_we       (id_ex_rf_we),
        .id_ex_lsu_en      (id_ex_lsu_en),
        .id_ex_lsu_we      (id_ex_lsu_we),
        .id_ex_lsu_ctrl    (id_ex_lsu_ctrl),
        .j_en              (j_en),
        .id_ex_J_cond      (id_ex_J_cond),
        .id_ex_is_uload    (id_ex_is_uload),
        .ex_id_ready       (ex_id_ready),
        .ex_glb_flush      (ex_glb_flush)
    );

    monitor_exu_ifu u_exu_ifu (
        .clk               (clk),
        .rst               (rst),
        .ex_if_pc          (ex_if_pc),
        .ex_if_pc_valid    (ex_if_pc_valid),
        .ex_glb_flush      (ex_glb_flush)
    );

    monitor_exu_lsu u_exu_lsu (
        .clk               (clk),
        .rst               (rst),
        .ex_lsu_valid      (ex_lsu_valid),
        .lsu_ex_ready      (lsu_ex_ready),
        .ex_lsu_pc         (ex_lsu_pc),
        .ex_lsu_addr       (ex_lsu_addr),
        .ex_lsu_data       (ex_lsu_data),
        .ex_lsu_wb_data    (ex_lsu_wb_data),
        .ex_lsu_ctrl       (ex_lsu_ctrl),
        .ex_lsu_size       (ex_lsu_size),
        .ex_lsu_wb_rd      (ex_lsu_wb_rd),
        .ex_lsu_wb_wen     (ex_lsu_wb_wen),
        .ex_lsu_is_uload   (ex_lsu_is_uload)
    );

    monitor_lsu_wbu u_lsu_wbu (
        .clk               (clk),
        .rst               (rst),
        .lsu_wbu_valid     (lsu_wbu_valid),
        .lsu_wb_pc         (lsu_wb_pc),
        .lsu_wbu_data      (lsu_wbu_data),
        .lsu_wbu_rd        (lsu_wbu_rd),
        .lsu_wbu_wen       (lsu_wbu_wen)
    );

    monitor_wbu_rf u_wbu_rf (
        .clk               (clk),
        .rst               (rst),
        .wb_rf_data        (wb_rf_data),
        .wb_rf_wen         (wb_rf_wen),
        .wb_rf_rd          (wb_rf_rd)
    );

endmodule
*/

//***********************************************************//
//                                                           //
//                  Module connecet                          //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//

/*
module monitor_ifu_idu (
    input clk,
    input rst,
    input [`XLEN-1:0] if_id_pc,
    input [`XLEN-1:0] if_id_instr,
    input             if_id_instr_valid,
    input             id_if_instr_ready
);
    wire fire = if_id_instr_valid & id_if_instr_ready;
endmodule


module monitor_idu_exu (
    input clk,
    input rst,
    input             id_ex_valid,
    input [`XLEN-1:0] id_ex_pc,
    input [`XLEN-1:0] id_ex_imm,
    input [4:0]       id_ex_rd,
    input [4:0]       id_ex_rs1_addr,
    input [4:0]       id_ex_rs2_addr,
    input [3:0]       id_ex_alu_ctrl,
    input [1:0]       alu_op_ctrl,
    input [2:0]       wb_ctrl,
    input             id_ex_rf_we,
    input             id_ex_lsu_en,
    input             id_ex_lsu_we,
    input [2:0]       id_ex_lsu_ctrl,
    input             j_en,
    input [2:0]       id_ex_J_cond,
    input             id_ex_is_uload,
    input             ex_id_ready,
    input             ex_glb_flush
);
    wire fire = id_ex_valid & ex_id_ready;
endmodule


module monitor_exu_ifu (
    input clk,
    input rst,
    input [`XLEN-1:0] ex_if_pc,
    input             ex_if_pc_valid,
    input             ex_glb_flush
);
endmodule


module monitor_exu_lsu (
    input clk,
    input rst,
    input             ex_lsu_valid,
    input             lsu_ex_ready,
    input [`XLEN-1:0] ex_lsu_pc,
    input [`XLEN-1:0] ex_lsu_addr,
    input [`XLEN-1:0] ex_lsu_data,
    input [`XLEN-1:0] ex_lsu_wb_data,
    input [1:0]       ex_lsu_ctrl,
    input [1:0]       ex_lsu_size,
    input [4:0]       ex_lsu_wb_rd,
    input             ex_lsu_wb_wen,
    input             ex_lsu_is_uload
);
    wire fire = ex_lsu_valid & lsu_ex_ready;
endmodule


module monitor_lsu_wbu (
    input clk,
    input rst,
    input             lsu_wbu_valid,
    input [`XLEN-1:0] lsu_wb_pc,
    input [`XLEN-1:0] lsu_wbu_data,
    input [4:0]       lsu_wbu_rd,
    input             lsu_wbu_wen
);
endmodule


module monitor_wbu_rf (
    input clk,
    input rst,
    input [`XLEN-1:0] wb_rf_data,
    input             wb_rf_wen,
    input [4:0]       wb_rf_rd
);
endmodule

*/

`include "macro.v"

module monitor (
    input clk,
    input rst,

    // IFU -> IDU
    input [`XLEN-1:0] if_id_pc,
    input             if_id_instr_valid,
    input             id_if_instr_ready,

    // IDU -> EXU
    input [`XLEN-1:0] id_ex_pc,
    input             id_ex_valid,
    input             ex_id_ready,

    // EXU -> IFU redirect
    input [`XLEN-1:0] ex_if_pc,
    input             ex_if_pc_valid,
    input             ex_glb_flush,

    // EXU -> LSU
    input [`XLEN-1:0] ex_lsu_pc,
    input             ex_lsu_valid,
    input             lsu_ex_ready,

    // LSU -> WBU
    input [`XLEN-1:0] lsu_wb_pc,
    input             lsu_wbu_valid,

    // WBU -> Regfile
    input             wb_rf_wen,
    input [4:0]       wb_rf_rd
);

    monitor_ifu_idu u_ifu_idu (
        .clk               (clk),
        .rst               (rst),
        .if_id_pc          (if_id_pc),
        .if_id_instr_valid (if_id_instr_valid),
        .id_if_instr_ready (id_if_instr_ready)
    );

    monitor_idu_exu u_idu_exu (
        .clk               (clk),
        .rst               (rst),
        .id_ex_pc          (id_ex_pc),
        .id_ex_valid       (id_ex_valid),
        .ex_id_ready       (ex_id_ready),
        .ex_glb_flush      (ex_glb_flush)
    );

    monitor_exu_ifu u_exu_ifu (
        .clk               (clk),
        .rst               (rst),
        .ex_if_pc          (ex_if_pc),
        .ex_if_pc_valid    (ex_if_pc_valid),
        .ex_glb_flush      (ex_glb_flush)
    );

    monitor_exu_lsu u_exu_lsu (
        .clk               (clk),
        .rst               (rst),
        .ex_lsu_pc         (ex_lsu_pc),
        .ex_lsu_valid      (ex_lsu_valid),
        .lsu_ex_ready      (lsu_ex_ready)
    );

    monitor_lsu_wbu u_lsu_wbu (
        .clk               (clk),
        .rst               (rst),
        .lsu_wb_pc         (lsu_wb_pc),
        .lsu_wbu_valid     (lsu_wbu_valid)
    );

    monitor_wbu_rf u_wbu_rf (
        .clk               (clk),
        .rst               (rst),
        .wb_rf_wen         (wb_rf_wen),
        .wb_rf_rd          (wb_rf_rd)
    );

endmodule

module monitor_ifu_idu (
    input clk,
    input rst,
    input [`XLEN-1:0] if_id_pc,
    input             if_id_instr_valid,
    input             id_if_instr_ready
);
    wire fire = if_id_instr_valid & id_if_instr_ready;
endmodule


module monitor_idu_exu (
    input clk,
    input rst,
    input [`XLEN-1:0] id_ex_pc,
    input             id_ex_valid,
    input             ex_id_ready,
    input             ex_glb_flush
);
    wire fire = id_ex_valid & ex_id_ready;
endmodule


module monitor_exu_ifu (
    input clk,
    input rst,
    input [`XLEN-1:0] ex_if_pc,
    input             ex_if_pc_valid,
    input             ex_glb_flush
);
    wire redirect_fire = ex_if_pc_valid;
endmodule


module monitor_exu_lsu (
    input clk,
    input rst,
    input [`XLEN-1:0] ex_lsu_pc,
    input             ex_lsu_valid,
    input             lsu_ex_ready
);
    wire fire = ex_lsu_valid & lsu_ex_ready;
endmodule


module monitor_lsu_wbu (
    input clk,
    input rst,
    input [`XLEN-1:0] lsu_wb_pc,
    input             lsu_wbu_valid
);
    wire fire = lsu_wbu_valid;
endmodule


module monitor_wbu_rf (
    input clk,
    input rst,
    input             wb_rf_wen,
    input [4:0]       wb_rf_rd
);
    wire fire = wb_rf_wen;
endmodule
