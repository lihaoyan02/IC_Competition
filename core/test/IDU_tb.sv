`timescale 1ns/1ps
`include "macro.v"

module IDU_tb;

    localparam INST_WIDTH    = `XLEN;
    localparam DATA_WIDTH    = `XLEN;
    localparam REGADDR_WIDTH = 5;

    //============================================================
    // Clock / Reset
    //============================================================
    logic clk;
    logic rst;

    initial clk = 1'b0;
    always #5 clk = ~clk;   // 100MHz clock

    //============================================================
    // DUT signals
    //============================================================

    // IFU -> IDU
    logic [INST_WIDTH-1:0] if_id_instr;
    logic                  if_id_instr_valid;
    logic [`XLEN-1:0]      if_id_pc;
    logic                  id_if_instr_ready;

    // EXU -> IDU
    logic                  ex_id_ready;
    logic                  ex_glb_flush;

    // IDU -> EXU
    logic                  id_ex_valid;
    logic [DATA_WIDTH-1:0] id_ex_imm;
    logic [REGADDR_WIDTH-1:0] id_ex_rd;
    logic [REGADDR_WIDTH-1:0] id_rf_rs1_addr;
    logic [REGADDR_WIDTH-1:0] id_rf_rs2_addr;
    logic [3:0]            id_ex_alu_ctrl;
    logic [1:0]            alu_op_ctrl;
    logic [`XLEN-1:0]      id_ex_pc;
    logic [2:0]            wb_ctrl;
    logic                  id_ex_rf_we;
    logic                  id_ex_lsu_en;
    logic                  id_ex_lsu_we;
    logic [2:0]            lsu_ctrl;
    logic                  ebreak_flag;
    logic                  j_en;
    logic [2:0]            id_ex_J_cond;

    // CSR
    logic                  csr_wen;
    logic                  csr_event;
    logic [11:0]           csr_addr;

    //============================================================
    // Clocking block
    //============================================================
    clocking drv_cb @(posedge clk);
        default input #1step output #1ns;

        output if_id_instr;
        output if_id_instr_valid;
        output if_id_pc;
        output ex_id_ready;
        output ex_glb_flush;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;

        input id_if_instr_ready;
        input id_ex_valid;
        input id_ex_imm;
        input id_ex_rd;
        input id_rf_rs1_addr;
        input id_rf_rs2_addr;
        input id_ex_alu_ctrl;
        input alu_op_ctrl;
        input id_ex_pc;
        input wb_ctrl;
        input id_ex_rf_we;
        input id_ex_lsu_en;
        input id_ex_lsu_we;
        input lsu_ctrl;
        input ebreak_flag;
        input j_en;
        input id_ex_J_cond;
        input csr_wen;
        input csr_event;
        input csr_addr;
    endclocking

    default clocking drv_cb;

    //============================================================
    // DUT instance
    //============================================================
    IDU #(
        .INST_WIDTH    (INST_WIDTH),
        .REGADDR_WIDTH (REGADDR_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH)
    ) dut (
        .clk                (clk),
        .rst                (rst),

        .if_id_instr        (if_id_instr),
        .if_id_instr_valid  (if_id_instr_valid),
        .if_id_pc           (if_id_pc),
        .id_if_instr_ready  (id_if_instr_ready),

        .ex_id_ready        (ex_id_ready),
        .ex_glb_flush       (ex_glb_flush),

        .id_ex_valid        (id_ex_valid),
        .id_ex_imm          (id_ex_imm),
        .id_ex_rd           (id_ex_rd),
        .id_rf_rs1_addr     (id_rf_rs1_addr),
        .id_rf_rs2_addr     (id_rf_rs2_addr),
        .id_ex_alu_ctrl     (id_ex_alu_ctrl),
        .alu_op_ctrl        (alu_op_ctrl),
        .id_ex_pc           (id_ex_pc),
        .wb_ctrl            (wb_ctrl),
        .id_ex_rf_we        (id_ex_rf_we),
        .id_ex_lsu_en       (id_ex_lsu_en),
        .id_ex_lsu_we       (id_ex_lsu_we),
        .lsu_ctrl           (lsu_ctrl),
        .ebreak_flag        (ebreak_flag),
        .j_en               (j_en),
        .id_ex_J_cond       (id_ex_J_cond),

        .csr_wen            (csr_wen),
        .csr_event          (csr_event),
        .csr_addr           (csr_addr)
    );

    //============================================================
    // Instruction encode helper functions
    //============================================================

    function automatic [`XLEN-1:0] enc_I;
        input [11:0] imm;
        input [4:0]  rs1;
        input [2:0]  funct3;
        input [4:0]  rd;
        input [6:0]  opcode;
        begin
            enc_I = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    function automatic [`XLEN-1:0] enc_R;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_R = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction

    function automatic [`XLEN-1:0] enc_U;
        input [19:0] imm20;
        input [4:0]  rd;
        input [6:0]  opcode;
        begin
            enc_U = {imm20, rd, opcode};
        end
    endfunction

    function automatic [`XLEN-1:0] enc_S;
        input [11:0] imm;
        input [4:0]  rs2;
        input [4:0]  rs1;
        input [2:0]  funct3;
        input [6:0]  opcode;
        begin
            enc_S = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
        end
    endfunction

    function automatic [`XLEN-1:0] enc_B;
        input [12:0] imm;
        input [4:0]  rs2;
        input [4:0]  rs1;
        input [2:0]  funct3;
        input [6:0]  opcode;
        begin
            enc_B = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
        end
    endfunction

    function automatic [`XLEN-1:0] enc_J;
        input [20:0] imm;
        input [4:0]  rd;
        input [6:0]  opcode;
        begin
            enc_J = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
        end
    endfunction

    //============================================================
    // Basic tasks
    //============================================================

    task automatic apply_reset;
        begin
            rst = 1'b1;

            drv_cb.if_id_instr       <= '0;
            drv_cb.if_id_instr_valid <= 1'b0;
            drv_cb.if_id_pc          <= '0;
            drv_cb.ex_id_ready       <= 1'b1;
            drv_cb.ex_glb_flush      <= 1'b0;

            repeat (3) @(posedge clk);
            rst = 1'b0;
            repeat (1) @(posedge clk);
        end
    endtask

    task automatic drive_inst;
        input [`XLEN-1:0] inst;
        input [`XLEN-1:0] pc;
        begin
            drv_cb.if_id_instr       <= inst;
            drv_cb.if_id_pc          <= pc;
            drv_cb.if_id_instr_valid <= 1'b1;
            drv_cb.ex_id_ready       <= 1'b1;
            drv_cb.ex_glb_flush      <= 1'b0;

            // 第一个周期 DUT 看到有效指令；
            // 下一个 posedge 后，mon_cb 采样稳定输出。
            ##1;
        end
    endtask 

    task automatic clear_inst;
        begin
            drv_cb.if_id_instr       <= '0;
            drv_cb.if_id_pc          <= '0;
            drv_cb.if_id_instr_valid <= 1'b0;
            ##1;
        end
    endtask

    task automatic check_equal;
        input string name;
        input [`XLEN-1:0] actual;
        input [`XLEN-1:0] expected;
        begin
            if (actual !== expected) begin
                $error("[%0t] CHECK FAIL: %s, actual = 0x%08h, expected = 0x%08h",
                       $time, name, actual, expected);
            end
            else begin
                $display("[%0t] CHECK PASS: %s = 0x%08h",
                         $time, name, actual);
            end
        end
    endtask

    task automatic check_1bit;
        input string name;
        input actual;
        input expected;
        begin
            if (actual !== expected) begin
                $error("[%0t] CHECK FAIL: %s, actual = %0b, expected = %0b",
                       $time, name, actual, expected);
            end
            else begin
                $display("[%0t] CHECK PASS: %s = %0b",
                         $time, name, actual);
            end
        end
    endtask

    //============================================================
// Test sequence
//============================================================
/*initial begin
    $fsdbDumpfile("idu_tb.fsdb");
    $fsdbDumpvars(0, tb_IDU);
end
*/

 // Waveform dumping
    initial begin
        $dumpfile("build/waveform.vcd");   // 指定波形文件名
        $dumpvars(0, IDU_tb);     // 转储所有层级信号（0 表示所有层级）
    end

initial begin
    $display("==================================================");
    $display(" IDU TB START");
    $display("==================================================");

    apply_reset();

    //========================================================
    // Test 1: ADDI x1, x2, 10
    //========================================================
    $display("\n[TEST 1] ADDI");

    drive_inst(
        enc_I(12'd10, 5'd2, `F3_ADDI, 5'd1, `INST_TYPE_I),
        32'h0000_1000
    );

    check_1bit("id_ex_valid", id_ex_valid, 1'b1);
    check_equal("id_ex_rd", id_ex_rd, 5'd1);
    check_equal("id_rf_rs1_addr", id_rf_rs1_addr, 5'd2);
    check_equal("id_ex_imm", id_ex_imm, 32'd10);
    check_equal("id_ex_alu_ctrl", id_ex_alu_ctrl, `ALU_ADD);
    check_equal("alu_op_ctrl", alu_op_ctrl, `OP_RS1_IMM);
    check_1bit("id_ex_rf_we", id_ex_rf_we, 1'b1);

    //========================================================
    // Test 2: ADD x3, x4, x5
    //========================================================
    $display("\n[TEST 2] ADD");

    drive_inst(
        enc_R(`F7_INST_A, 5'd5, 5'd4, `F3_ADD_SUB, 5'd3, `INST_TYPE_R),
        32'h0000_1004
    );

    check_equal("id_ex_rd", id_ex_rd, 5'd3);
    check_equal("id_rf_rs1_addr", id_rf_rs1_addr, 5'd4);
    check_equal("id_rf_rs2_addr", id_rf_rs2_addr, 5'd5);
    check_equal("id_ex_alu_ctrl", id_ex_alu_ctrl, `ALU_ADD);
    check_equal("alu_op_ctrl", alu_op_ctrl, `OP_RS1_RS2);
    check_1bit("id_ex_rf_we", id_ex_rf_we, 1'b1);

    //========================================================
    // Test 3: SUB x6, x7, x8
    //========================================================
    $display("\n[TEST 3] SUB");

    drive_inst(
        enc_R(`F7_INST_B, 5'd8, 5'd7, `F3_ADD_SUB, 5'd6, `INST_TYPE_R),
        32'h0000_1008
    );

    check_equal("id_ex_rd", id_ex_rd, 5'd6);
    check_equal("id_rf_rs1_addr", id_rf_rs1_addr, 5'd7);
    check_equal("id_rf_rs2_addr", id_rf_rs2_addr, 5'd8);
    check_equal("id_ex_alu_ctrl", id_ex_alu_ctrl, `ALU_SUB);
    check_1bit("id_ex_rf_we", id_ex_rf_we, 1'b1);

    //========================================================
    // Test 4: LW x9, 16(x10)
    //========================================================
    $display("\n[TEST 4] LW");

    drive_inst(
        enc_I(12'd16, 5'd10, `F3_LW, 5'd9, `INST_TYPE_IL),
        32'h0000_100C
    );

    check_equal("id_ex_rd", id_ex_rd, 5'd9);
    check_equal("id_rf_rs1_addr", id_rf_rs1_addr, 5'd10);
    check_equal("id_ex_imm", id_ex_imm, 32'd16);
    check_equal("id_ex_alu_ctrl", id_ex_alu_ctrl, `ALU_ADD);
    check_equal("alu_op_ctrl", alu_op_ctrl, `OP_RS1_IMM);
    check_1bit("id_ex_lsu_en", id_ex_lsu_en, 1'b1);
    check_1bit("id_ex_lsu_we", id_ex_lsu_we, 1'b0);
    check_1bit("id_ex_rf_we", id_ex_rf_we, 1'b1);

    //========================================================
    // Test 5: SW x11, 20(x12)
    //========================================================
    $display("\n[TEST 5] SW");

    drive_inst(
        enc_S(12'd20, 5'd11, 5'd12, `F3_SW, `INST_TYPE_S),
        32'h0000_1010
    );

    check_equal("id_rf_rs1_addr", id_rf_rs1_addr, 5'd12);
    check_equal("id_rf_rs2_addr", id_rf_rs2_addr, 5'd11);
    check_equal("id_ex_imm", id_ex_imm, 32'd20);
    check_equal("id_ex_alu_ctrl", id_ex_alu_ctrl, `ALU_ADD);
    check_1bit("id_ex_lsu_en", id_ex_lsu_en, 1'b1);
    check_1bit("id_ex_lsu_we", id_ex_lsu_we, 1'b1);
    check_1bit("id_ex_rf_we", id_ex_rf_we, 1'b0);

    //========================================================
    // Test 6: BEQ x1, x2, offset 8
    //========================================================
    $display("\n[TEST 6] BEQ");

    drive_inst(
        enc_B(13'd8, 5'd2, 5'd1, `F3_BEQ, `INST_TYPE_B),
        32'h0000_1014
    );

    check_equal("id_rf_rs1_addr", id_rf_rs1_addr, 5'd1);
    check_equal("id_rf_rs2_addr", id_rf_rs2_addr, 5'd2);
    check_equal("id_ex_imm", id_ex_imm, 32'd8);
    check_1bit("j_en", j_en, 1'b1);
    check_equal("id_ex_J_cond", id_ex_J_cond, `J_BEQ);
    check_1bit("id_ex_rf_we", id_ex_rf_we, 1'b0);

    //========================================================
    // Test 7: JAL x1, offset 16
    //========================================================
    $display("\n[TEST 7] JAL");

    drive_inst(
        enc_J(21'd16, 5'd1, `INST_JAL),
        32'h0000_1018
    );

    check_equal("id_ex_rd", id_ex_rd, 5'd1);
    check_equal("id_ex_imm", id_ex_imm, 32'd16);
    check_1bit("j_en", j_en, 1'b1);
    check_1bit("id_ex_rf_we", id_ex_rf_we, 1'b1);

    //========================================================
    // Test 8: flush
    //========================================================
    $display("\n[TEST 8] FLUSH");

    drv_cb.ex_glb_flush <= 1'b1;
    ##1;
    #1;
    drv_cb.ex_glb_flush <= 1'b0;

    check_1bit("id_ex_valid after flush", id_ex_valid, 1'b0);
    check_equal("id_ex_pc after flush", id_ex_pc, 32'b0);

    clear_inst();

    $display("\n==================================================");
    $display(" IDU TB FINISH");
    $display("==================================================");

    #20;
    $finish;
end

    //============================================================
    // FSDB dump
    //============================================================


endmodule
