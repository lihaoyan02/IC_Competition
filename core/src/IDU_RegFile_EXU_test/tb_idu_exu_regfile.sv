`timescale 1ns/1ps
`include "macro.v"

module tb_idu_exu_regfile_top;

    //============================================================
    // Parameters
    //============================================================
    localparam INST_WIDTH    = `XLEN;
    localparam DATA_WIDTH    = `XLEN;
    localparam REGADDR_WIDTH = 5;

    //============================================================
    // Clock / Reset
    //============================================================
    logic clk;
    logic rst;

    initial clk = 1'b0;
    always #5 clk = ~clk;   // 100MHz

    //============================================================
    // DUT I/O signals
    //============================================================

    // IF -> ID
    logic [`XLEN-1:0] if_id_instr;
    logic             if_id_instr_valid;
    logic [`XLEN-1:0] if_id_pc;
    logic             id_if_instr_ready;

    // TB write port to Regfile
    logic             tb_rf_we;
    logic [4:0]       tb_rf_rd_addr;
    logic [`XLEN-1:0] tb_rf_rd_data;

    // External EXU inputs
    logic             lsu_ex_ready;
    logic [`XLEN-1:0] csr_ex_rdata;

    // EXU -> IFU
    logic             ex_if_pc_valid;
    logic [`XLEN-1:0] ex_if_pc;
    logic             ex_glb_flush;

    // EXU -> LSU payload
    logic             ex_lsu_valid;
    logic [`XLEN-1:0] ex_lsu_addr;
    logic [`XLEN-1:0] ex_lsu_data;
    logic [1:0]       ex_lsu_ctrl;
    logic [1:0]       ex_lsu_size;
    logic [`XLEN-1:0] ex_lsu_wb_data;
    logic [4:0]       ex_lsu_wb_rd;
    logic             ex_lsu_wb_wen;

    //============================================================
    // Clocking Blocks
    //============================================================
    clocking drv_cb @(posedge clk);
        default input #1step output #1ns;

        output rst;

        output if_id_instr;
        output if_id_instr_valid;
        output if_id_pc;

        output tb_rf_we;
        output tb_rf_rd_addr;
        output tb_rf_rd_data;

        output lsu_ex_ready;
        output csr_ex_rdata;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;

        input id_if_instr_ready;

        input ex_if_pc_valid;
        input ex_if_pc;
        input ex_glb_flush;

        input ex_lsu_valid;
        input ex_lsu_addr;
        input ex_lsu_data;
        input ex_lsu_ctrl;
        input ex_lsu_size;
        input ex_lsu_wb_data;
        input ex_lsu_wb_rd;
        input ex_lsu_wb_wen;
    endclocking

    default clocking drv_cb;

    //============================================================
    // DUT instance
    //============================================================
    idu_exu_regfile_top dut (
        .clk            (clk),
        .rst            (rst),

        .if_id_instr       (if_id_instr),
        .if_id_instr_valid (if_id_instr_valid),
        .if_id_pc          (if_id_pc),
        .id_if_instr_ready (id_if_instr_ready),

        .tb_rf_we       (tb_rf_we),
        .tb_rf_rd_addr  (tb_rf_rd_addr),
        .tb_rf_rd_data  (tb_rf_rd_data),

        .lsu_ex_ready   (lsu_ex_ready),
        .csr_ex_rdata   (csr_ex_rdata),

        .ex_if_pc_valid (ex_if_pc_valid),
        .ex_if_pc       (ex_if_pc),
        .ex_glb_flush   (ex_glb_flush),

        .ex_lsu_valid   (ex_lsu_valid),
        .ex_lsu_addr    (ex_lsu_addr),
        .ex_lsu_data    (ex_lsu_data),
        .ex_lsu_ctrl    (ex_lsu_ctrl),
        .ex_lsu_size    (ex_lsu_size),
        .ex_lsu_wb_data (ex_lsu_wb_data),
        .ex_lsu_wb_rd   (ex_lsu_wb_rd),
        .ex_lsu_wb_wen  (ex_lsu_wb_wen)
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
    // Tasks
    //============================================================
    task automatic apply_reset;
        begin
            drv_cb.rst             <= 1'b1;
            drv_cb.if_id_instr     <= '0;
            drv_cb.if_id_instr_valid <= 1'b0;
            drv_cb.if_id_pc        <= '0;

            drv_cb.tb_rf_we        <= 1'b0;
            drv_cb.tb_rf_rd_addr   <= '0;
            drv_cb.tb_rf_rd_data   <= '0;

            drv_cb.lsu_ex_ready    <= 1'b1;
            drv_cb.csr_ex_rdata    <= '0;

            ##3;
            drv_cb.rst <= 1'b0;
            ##1;
        end
    endtask

    task automatic rf_write;
        input [4:0] addr;
        input [`XLEN-1:0] data;
        begin
            drv_cb.tb_rf_we      <= 1'b1;
            drv_cb.tb_rf_rd_addr <= addr;
            drv_cb.tb_rf_rd_data <= data;
            ##1;

            drv_cb.tb_rf_we      <= 1'b0;
            drv_cb.tb_rf_rd_addr <= '0;
            drv_cb.tb_rf_rd_data <= '0;
            ##1;
        end
    endtask

    task automatic drive_inst;
        input [`XLEN-1:0] inst;
        input [`XLEN-1:0] pc;
        begin
            drv_cb.if_id_instr       <= inst;
            drv_cb.if_id_instr_valid <= 1'b1;
            drv_cb.if_id_pc          <= pc;
            drv_cb.lsu_ex_ready      <= 1'b1;
            drv_cb.csr_ex_rdata      <= '0;

            // IDU打一拍 + EXU打一拍
            ##2;
        end
    endtask

    task automatic clear_inst;
        begin
            drv_cb.if_id_instr       <= '0;
            drv_cb.if_id_instr_valid <= 1'b0;
            drv_cb.if_id_pc          <= '0;
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
                $display("[%0t] CHECK PASS: %s = 0x%08h", $time, name, actual);
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
                $display("[%0t] CHECK PASS: %s = %0b", $time, name, actual);
            end
        end
    endtask

    //============================================================
    // FSDB
    //============================================================
    initial begin
        $fsdbDumpfile("idu_exu_regfile_top.fsdb");
        $fsdbDumpvars(0, tb_idu_exu_regfile_top);
    end

    //============================================================
    // Test sequence
    //============================================================
    initial begin
        $display("==================================================");
        $display(" IDU + RegFile + EXU TOP TB WITH CLOCKING BLOCK");
        $display("==================================================");

        apply_reset();

        // preload regfile
        rf_write(5'd2, 32'd7);         // x2 = 7
        rf_write(5'd3, 32'd5);         // x3 = 5
        rf_write(5'd4, 32'd20);        // x4 = 20
        rf_write(5'd5, 32'd8);         // x5 = 8
        rf_write(5'd6, 32'd100);       // x6 = 100
        rf_write(5'd7, 32'd200);       // x7 = 200
        rf_write(5'd8, 32'd200);       // x8 = 200
        rf_write(5'd9, 32'hA5A5_1234); // x9 = store data

        //========================================================
        // TEST1: ADDI x1, x2, 10 => 7 + 10 = 17
        //========================================================
        $display("\n[TEST1] ADDI");
        drive_inst(
            enc_I(12'd10, 5'd2, `F3_ADDI, 5'd1, `INST_TYPE_I),
            32'h0000_1000
        );

        check_1bit ("ex_lsu_valid",   mon_cb.ex_lsu_valid,   1'b1);
        check_equal("ex_lsu_wb_data", mon_cb.ex_lsu_wb_data, 32'd17);
        check_equal("ex_lsu_wb_rd",   mon_cb.ex_lsu_wb_rd,   5'd1);
        check_1bit ("ex_lsu_wb_wen",  mon_cb.ex_lsu_wb_wen,  1'b1);
        check_equal("ex_lsu_ctrl",    mon_cb.ex_lsu_ctrl,    2'b00);

        //========================================================
        // TEST2: ADD x10, x4, x5 => 20 + 8 = 28
        //========================================================
        $display("\n[TEST2] ADD");
        drive_inst(
            enc_R(`F7_INST_A, 5'd5, 5'd4, `F3_ADD_SUB, 5'd10, `INST_TYPE_R),
            32'h0000_1004
        );

        check_equal("ex_lsu_wb_data", mon_cb.ex_lsu_wb_data, 32'd28);
        check_equal("ex_lsu_wb_rd",   mon_cb.ex_lsu_wb_rd,   5'd10);
        check_1bit ("ex_lsu_wb_wen",  mon_cb.ex_lsu_wb_wen,  1'b1);

        //========================================================
        // TEST3: SW x9, 12(x6) => addr=112, data=x9
        //========================================================
        $display("\n[TEST3] SW");
        drive_inst(
            enc_S(12'd12, 5'd9, 5'd6, `F3_SW, `INST_TYPE_S),
            32'h0000_1008
        );

        check_1bit ("ex_lsu_valid", mon_cb.ex_lsu_valid, 1'b1);
        check_equal("ex_lsu_addr",  mon_cb.ex_lsu_addr,  32'd112);
        check_equal("ex_lsu_data",  mon_cb.ex_lsu_data,  32'hA5A5_1234);
        check_equal("ex_lsu_ctrl",  mon_cb.ex_lsu_ctrl,  2'b10);
        check_equal("ex_lsu_size",  mon_cb.ex_lsu_size,  2'b10);
        check_1bit ("ex_lsu_wb_wen", mon_cb.ex_lsu_wb_wen, 1'b0);

        //========================================================
        // TEST4: LW x11, 4(x6) => addr=104
        //========================================================
        $display("\n[TEST4] LW");
        drive_inst(
            enc_I(12'd4, 5'd6, `F3_LW, 5'd11, `INST_TYPE_IL),
            32'h0000_100C
        );

        check_equal("ex_lsu_addr",   mon_cb.ex_lsu_addr,   32'd104);
        check_equal("ex_lsu_ctrl",   mon_cb.ex_lsu_ctrl,   2'b01);
        check_equal("ex_lsu_size",   mon_cb.ex_lsu_size,   2'b10);
        check_equal("ex_lsu_wb_rd",  mon_cb.ex_lsu_wb_rd,  5'd11);
        check_1bit ("ex_lsu_wb_wen", mon_cb.ex_lsu_wb_wen, 1'b1);

        //========================================================
        // TEST5: BEQ x7, x8, +8 => taken
        //========================================================
        $display("\n[TEST5] BEQ");
        drive_inst(
            enc_B(13'd8, 5'd8, 5'd7, `F3_BEQ, `INST_TYPE_B),
            32'h0000_1010
        );

        check_1bit ("ex_if_pc_valid", mon_cb.ex_if_pc_valid, 1'b1);
        check_equal("ex_if_pc",       mon_cb.ex_if_pc,       32'h0000_1018);
        check_1bit ("ex_glb_flush",   mon_cb.ex_glb_flush,   1'b1);

        //========================================================
        // TEST6: JAL x1, +16 => target pc+16
        //========================================================
        $display("\n[TEST6] JAL");
        drive_inst(
            enc_J(21'd16, 5'd1, `INST_JAL),
            32'h0000_1020
        );

        check_1bit ("ex_if_pc_valid", mon_cb.ex_if_pc_valid, 1'b1);
        check_equal("ex_if_pc",       mon_cb.ex_if_pc,       32'h0000_1030);
        check_1bit ("ex_glb_flush",   mon_cb.ex_glb_flush,   1'b1);

        clear_inst();

        $display("\n==================================================");
        $display(" IDU + RegFile + EXU TOP TB FINISH");
        $display("==================================================");

        #20;
        $finish;
    end

endmodule