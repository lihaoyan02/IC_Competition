`include "macro.v"

module top (
    input clk,
    input rst
);

    //========================================================
    // IFU / IMEM wires
    //========================================================
    wire [`XLEN-1:0] ex_if_pc;
    wire             ex_if_pc_valid;

    wire [`XLEN-1:0] if_id_instr;
    wire [`XLEN-1:0] if_id_pc;
    wire             if_id_instr_valid;
    wire             id_if_instr_ready;

    wire [`XLEN-1:0] imem_if_rdata;
    wire             imem_if_rvalid;
    wire [`XLEN-1:0] if_imem_araddr;
    wire             if_imem_arvalid;

    wire             ex_glb_flush;

    //========================================================
    // EXU -> IDU
    //========================================================
    wire             ex_id_ready;

    //========================================================
    // IDU -> EXU
    //========================================================
    wire             id_ex_valid;
    wire [`XLEN-1:0] id_ex_imm;
    wire [`XLEN-1:0] id_ex_rs1_data;
    wire [`XLEN-1:0] id_ex_rs2_data;
    wire [4:0]       id_ex_rd;
    wire [4:0]       id_ex_rs1_addr;
    wire [4:0]       id_ex_rs2_addr;
    wire [4:0]       id_rf_rs1_addr;
    wire [4:0]       id_rf_rs2_addr;
    wire [3:0]       id_ex_alu_ctrl;
    wire [1:0]       alu_op_ctrl;
    wire [`XLEN-1:0] id_ex_pc;
    wire [2:0]       wb_ctrl;
    wire             id_ex_rf_we;
    wire             id_ex_lsu_en;
    wire             id_ex_lsu_we;
    wire [2:0]       id_ex_lsu_ctrl;
    wire             ebreak_flag;
    wire             j_en;
    wire [2:0]       id_ex_J_cond;

    //========================================================
    // Regfile / WBU wires
    //========================================================
    wire [`XLEN-1:0] rf_id_rs1_data;
    wire [`XLEN-1:0] rf_id_rs2_data;
    wire [`XLEN-1:0] wb_rf_data;
    wire             wb_rf_wen;
    wire [4:0]       wb_rf_rd;

    //========================================================
    // EXU -> LSU / IDU hazard detect wires
    //========================================================
    wire             ex_lsu_valid;
    wire             lsu_ex_ready;
    wire [`XLEN-1:0] ex_lsu_addr;
    wire [`XLEN-1:0] ex_lsu_data;
    wire [`XLEN-1:0] ex_lsu_wb_data;
    wire [1:0]       ex_lsu_ctrl;
    wire [1:0]       ex_lsu_size;
    wire [4:0]       ex_lsu_wb_rd;
    wire             ex_lsu_wb_wen;

    wire [`XLEN-1:0] ex_lsu_pc;
    wire             ebreak_exu_lsu;

    //========================================================
    // LSU -> Cache wires
    //========================================================
    wire             lsu_cache_valid;
    wire             lsu_cache_wen;
    wire             cache_lsu_hit;
    wire [`XLEN-1:0] lsu_cache_addr;
    wire [`XLEN-1:0] lsu_cache_wdata;
    wire [`XLEN-1:0] cache_lsu_rdata;
    wire [3:0]       lsu_cache_wmask;
    wire [1:0]       lsu_cache_size;

    //========================================================
    // LSU -> WBU wires
    //========================================================
    wire             lsu_wbu_valid;
    wire             lsu_wbu_wen;
    wire [`XLEN-1:0] lsu_wbu_data;
    wire [4:0]       lsu_wbu_rd;


    wire [`XLEN-1:0] lsu_wb_pc;
    wire             ebreak_lsu_wbu;

    //========================================================
    // IFU
    //========================================================
    IFU u_IFU (
        .clk               (clk),
        .rst               (rst),

        // 来自 EXU 的跳转信息
        .ex_if_pc          (ex_if_pc),
        .ex_if_pc_valid    (ex_if_pc_valid),

        // IF/ID 寄存器
        .if_id_instr       (if_id_instr),
        .if_id_pc          (if_id_pc),
        .if_id_instr_valid (if_id_instr_valid),
        .id_if_instr_ready (id_if_instr_ready),

        // 内存访问
        .imem_if_rdata     (imem_if_rdata),
        .imem_if_rvalid    (imem_if_rvalid),
        .if_imem_araddr    (if_imem_araddr),
        .if_imem_arvalid   (if_imem_arvalid),

        .ex_glb_flush      (ex_glb_flush)
    );

    //========================================================
    // IMEM
    //========================================================
    IMEM u_imem (
        .rst              (rst),
        .if_imem_araddr   (if_imem_araddr),
        .imem_valid       (if_imem_arvalid),
        .imem_if_rdata    (imem_if_rdata),
        .imem_if_rvalid   (imem_if_rvalid)
    );

    //========================================================
    // IDU
    //========================================================
    IDU u_IDU (
        .clk             (clk),
        .rst             (rst),

        // Signals to/from IFU
        .if_id_instr     (if_id_instr),
        .if_id_instr_valid(if_id_instr_valid),
        .if_id_pc        (if_id_pc),
        .id_if_instr_ready(id_if_instr_ready),

        // Signals to/from EXU
        .ex_id_ready     (ex_id_ready),
        .ex_glb_flush    (ex_glb_flush),

        .ex_lsu_valid    (ex_lsu_valid),
        .ex_lsu_wb_wen   (ex_lsu_wb_wen),
        .ex_lsu_wb_rd    (ex_lsu_wb_rd),
        .ex_lsu_ctrl     (ex_lsu_ctrl),

        .id_ex_valid     (id_ex_valid),
        .id_ex_imm       (id_ex_imm),
        .id_ex_rs1_data  (id_ex_rs1_data),
        .id_ex_rs2_data  (id_ex_rs2_data),
        .id_ex_rd        (id_ex_rd),
        .id_ex_rs1_addr  (id_ex_rs1_addr),
        .id_ex_rs2_addr  (id_ex_rs2_addr),
        .id_ex_alu_ctrl  (id_ex_alu_ctrl),
        .alu_op_ctrl     (alu_op_ctrl),
        .id_ex_pc        (id_ex_pc),
        .wb_ctrl         (wb_ctrl),
        .id_ex_rf_we     (id_ex_rf_we),
        .id_ex_lsu_en    (id_ex_lsu_en),
        .id_ex_lsu_we    (id_ex_lsu_we),
        .id_ex_lsu_ctrl  (id_ex_lsu_ctrl),
        .ebreak_flag     (ebreak_flag),
        .j_en            (j_en),
        .id_ex_J_cond    (id_ex_J_cond),

        // Register file access
        .rf_id_rs1_data  (rf_id_rs1_data),
        .rf_id_rs2_data  (rf_id_rs2_data),
        .id_rf_rs1_addr  (id_rf_rs1_addr),
        .id_rf_rs2_addr  (id_rf_rs2_addr),

        // Signals to/from CSR
        .csr_wen         (),
        .csr_event       (),
        .csr_addr        (),

        // Global stall ctrl
        .id_glb_stall    ()
    );

    //========================================================
    // Regfile
    //========================================================
    Regfile u_regfile (
        .clk       (clk),
        .rst       (rst),

        .rs1_addr  (id_rf_rs1_addr),
        .rs2_addr  (id_rf_rs2_addr),
        .rs1_data  (rf_id_rs1_data),
        .rs2_data  (rf_id_rs2_data),

        .we        (wb_rf_wen),
        .rd_addr   (wb_rf_rd),
        .rd_data   (wb_rf_data)
    );

    //========================================================
    // EXU
    //========================================================
    EXU u_EXU (
        .clk             (clk),
        .rst             (rst),

        .id_ex_valid     (id_ex_valid),
        .id_ex_pc        (id_ex_pc),
        .id_ex_imm       (id_ex_imm),
        .id_ex_rs1_data  (id_ex_rs1_data),
        .id_ex_rs2_data  (id_ex_rs2_data),
        .id_ex_rs1_addr  (id_ex_rs1_addr),
        .id_ex_rs2_addr  (id_ex_rs2_addr),
        .id_ex_rd        (id_ex_rd),
        .id_ex_alu_ctrl  (id_ex_alu_ctrl),
        .alu_op_ctrl     (alu_op_ctrl),
        .wb_ctrl         (wb_ctrl),
        .id_ex_rf_we     (id_ex_rf_we),
        .id_ex_lsu_en    (id_ex_lsu_en),
        .id_ex_lsu_we    (id_ex_lsu_we),
        .id_ex_lsu_ctrl  (id_ex_lsu_ctrl),
        .ebreak_flag     (ebreak_flag),
        .j_en            (j_en),
        .id_ex_J_cond    (id_ex_J_cond),

        .ex_id_ready     (ex_id_ready),
        .ex_glb_flush    (ex_glb_flush),

        .csr_ex_rdata    ({`XLEN{1'b0}}),

        .ex_if_pc_valid  (ex_if_pc_valid),
        .ex_if_pc        (ex_if_pc),

        .ex_lsu_valid    (ex_lsu_valid),
        .lsu_ex_ready    (lsu_ex_ready),
        .ex_lsu_addr     (ex_lsu_addr),
        .ex_lsu_data     (ex_lsu_data),
        .ex_lsu_ctrl     (ex_lsu_ctrl),
        .ex_lsu_size     (ex_lsu_size),

        .ex_lsu_wb_data  (ex_lsu_wb_data),
        .ex_lsu_wb_rd    (ex_lsu_wb_rd),
        .ex_lsu_wb_wen   (ex_lsu_wb_wen),
        
        /*-----------------for debug--------------------*/
        .ex_lsu_pc       (ex_lsu_pc),
        .ebreak_exu_lsu  (ebreak_exu_lsu),
        /*----------------------------------------------*/

        .wb_rf_we        (wb_rf_wen),
        .wb_rf_rd        (wb_rf_rd),
        .wb_rd_dat       (wb_rf_data)
    );

    //========================================================
    // L1 Cache
    //========================================================
    L1_cache u_cache (
        .clk       (clk),
        .rst       (rst),
        .valid     (lsu_cache_valid),
        .wen       (lsu_cache_wen),
        .addr      (lsu_cache_addr),
        .wdata     (lsu_cache_wdata),
        .wmask     (lsu_cache_wmask),
        .size      (lsu_cache_size),
        .rdata     (cache_lsu_rdata),
        .hit       (cache_lsu_hit)
    );

    //========================================================
    // LSU
    //========================================================
    LSU u_LSU (
        .clk              (clk),
        .rst              (rst),

        .ex_lsu_valid     (ex_lsu_valid),
        .lsu_ex_ready     (lsu_ex_ready),
        .ex_lsu_addr      (ex_lsu_addr),
        .ex_lsu_data      (ex_lsu_data),
        .ex_lsu_ctrl      (ex_lsu_ctrl),
        .ex_lsu_size      (ex_lsu_size),

        .ex_lsu_wb_data   (ex_lsu_wb_data),
        .ex_lsu_wb_rd     (ex_lsu_wb_rd),
        .ex_lsu_wb_wen    (ex_lsu_wb_wen),

        /*-----------------for debug--------------------*/
        .ex_lsu_pc(ex_lsu_pc),
        .lsu_wb_pc(lsu_wb_pc),
        .ebreak_exu_lsu  (ebreak_exu_lsu),
        .ebreak_lsu_wbu  (ebreak_lsu_wbu),
        /*----------------------------------------------*/

        .lsu_wbu_valid    (lsu_wbu_valid),
        .lsu_wbu_data     (lsu_wbu_data),
        .lsu_wbu_rd       (lsu_wbu_rd),
        .lsu_wbu_wen      (lsu_wbu_wen),

        .lsu_cache_valid  (lsu_cache_valid),
        .lsu_cache_wen    (lsu_cache_wen),
        .lsu_cache_addr   (lsu_cache_addr),
        .lsu_cache_wdata  (lsu_cache_wdata),
        .lsu_cache_wmask  (lsu_cache_wmask),
        .lsu_cache_size   (lsu_cache_size),
        .cache_lsu_rdata  (cache_lsu_rdata),
        .cache_lsu_hit    (cache_lsu_hit)
    );

    //========================================================
    // WBU
    //========================================================
    WBU u_WBU (
        .clk             (clk),
        .rst             (rst),

        // From Memory stage
        .lsu_wbu_data    (lsu_wbu_data),
        .lsu_wbu_valid   (lsu_wbu_valid),
        .lsu_wbu_rd      (lsu_wbu_rd),
        .lsu_wbu_wen     (lsu_wbu_wen),
        .lsu_wb_pc          (lsu_wb_pc),
        .ebreak_lsu_wbu  (ebreak_lsu_wbu),

        // Write back interface
        .wb_rf_data      (wb_rf_data),
        .wb_rf_rd        (wb_rf_rd),
        .wb_rf_wen       (wb_rf_wen)
    );

endmodule