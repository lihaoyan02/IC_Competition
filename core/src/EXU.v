`include "macro.v"

module EXU #(
    parameter DATA_WIDTH = `XLEN
) (
    input clk,
    input rst,

    // Signals to/from IDU
    input                      id_ex_valid,
    input [`XLEN-1:0]          id_ex_pc,
    input [`XLEN-1:0]          id_ex_imm,
    input [`XLEN-1:0]          id_ex_rs1_data,
    input [`XLEN-1:0]          id_ex_rs2_data,
    input [4:0]                id_ex_rd,
    input [3:0]                id_ex_alu_ctrl,
    input [1:0]                alu_op_ctrl,
    input [2:0]                wb_ctrl,
    input                      id_ex_rf_we,
    input                      id_ex_lsu_en,
    input                      id_ex_lsu_we,
    input [2:0]                id_ex_lsu_ctrl,
    input                      ebreak_flag,
    input                      j_en,
    input [2:0]                id_ex_J_cond,
    output                     ex_id_ready,
    output reg                 ex_glb_flush,

    // CSR read data
    input [`XLEN-1:0]          csr_ex_rdata,


    // Signals to/from IFU
    output reg                 ex_if_pc_valid,
    output reg [`XLEN-1:0]     ex_if_pc,

    // Signals to/from LSU
    output reg                 ex_lsu_valid,
    input                      lsu_ex_ready,
    output reg [`XLEN-1:0]     ex_lsu_addr,
    output reg [`XLEN-1:0]     ex_lsu_data,
    output reg [1:0]           ex_lsu_ctrl,      // 00:none 01:read 10:write
    output reg [1:0]           ex_lsu_size,      // 00:byte 01:half 10:word

    output reg [`XLEN-1:0]     ex_lsu_wb_data,
    output reg [4:0]           ex_lsu_wb_rd,
    output reg                 ex_lsu_wb_wen
);

    //========================================================
    // Internal signals
    //========================================================
    reg [`XLEN-1:0] op1, op2;
    reg [`XLEN-1:0] alu_out;
    reg             j_taken;

    reg             ex_lsu_valid_nxt;
    reg [`XLEN-1:0] ex_lsu_addr_nxt;
    reg [`XLEN-1:0] ex_lsu_data_nxt;
    reg [1:0]       ex_lsu_ctrl_nxt;
    reg [1:0]       ex_lsu_size_nxt;
    reg [`XLEN-1:0] ex_lsu_wb_data_nxt;
    reg [4:0]       ex_lsu_wb_rd_nxt;
    reg             ex_lsu_wb_wen_nxt;

    wire is_jalr;
    wire ex_need_lsu;
    wire ex_payload_fire;

    assign is_jalr      = j_en && (id_ex_J_cond == `J_UNCOND) && (alu_op_ctrl == `OP_RS1_IMM);
    assign ex_need_lsu  = ex_lsu_valid;
    assign ex_payload_fire = (!ex_need_lsu) || lsu_ex_ready;


    assign ex_id_ready = ex_payload_fire;

    //========================================================
    // Operand select
    //========================================================
    always @(*) begin
        case (alu_op_ctrl)
            `OP_PC_IMM: begin
                op1 = id_ex_pc;
                op2 = id_ex_imm;
            end

            `OP_RS1_IMM: begin
                op1 = id_ex_rs1_data;
                op2 = id_ex_imm;
            end

            `OP_RS1_CSR: begin
                op1 = id_ex_rs1_data;
                op2 = csr_ex_rdata;
            end

            default: begin
                // `OP_RS1_RS2
                op1 = id_ex_rs1_data;
                op2 = id_ex_rs2_data;
            end
        endcase
    end

//***********************************************************//
//                                                           //
//                  ALU Function                             //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//
    always @(*) begin
        case (id_ex_alu_ctrl)
            `ALU_IDLE          : alu_out = {DATA_WIDTH{1'b0}};
            `ALU_ADD           : alu_out = op1 + op2;
            `ALU_SUB           : alu_out = op1 - op2;
            `ALU_OP2           : alu_out = op2;
            `ALU_LESS_U        : alu_out = (op1 < op2) ?
                                           {{(DATA_WIDTH-1){1'b0}}, 1'b1} :
                                           {DATA_WIDTH{1'b0}};
            `ALU_LESS          : alu_out = ($signed(op1) < $signed(op2)) ?
                                           {{(DATA_WIDTH-1){1'b0}}, 1'b1} :
                                           {DATA_WIDTH{1'b0}};
            `ALU_SHIFT_LEFT    : alu_out = op1 << op2[4:0];
            `ALU_SHIFT_RIGHT_U : alu_out = op1 >> op2[4:0];
            `ALU_SHIFT_RIGHT   : alu_out = $signed(op1) >>> op2[4:0];
            `ALU_AND           : alu_out = op1 & op2;
            `ALU_XOR           : alu_out = op1 ^ op2;
            `ALU_OR            : alu_out = op1 | op2;
            default            : alu_out = {DATA_WIDTH{1'b0}};
        endcase
    end

//***********************************************************//
//                                                           //
//                  Branching                                //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//
    always @(*) begin
        if (j_en) begin
            case (id_ex_J_cond)
                `J_UNCOND: j_taken = 1'b1;
                `J_BEQ   : j_taken = (id_ex_rs1_data == id_ex_rs2_data);
                `J_BNE   : j_taken = (id_ex_rs1_data != id_ex_rs2_data);
                `J_BGE   : j_taken = ($signed(id_ex_rs1_data) >= $signed(id_ex_rs2_data));
                `J_BGE_U : j_taken = (id_ex_rs1_data >= id_ex_rs2_data);
                `J_BLT_U : j_taken = (id_ex_rs1_data <  id_ex_rs2_data);
                `J_BLT   : j_taken = ($signed(id_ex_rs1_data) <  $signed(id_ex_rs2_data));
                default  : j_taken = 1'b0;
            endcase
        end
        else begin
            j_taken = 1'b0;
        end
    end

    //========================================================
    // Redirect PC / Flush Utilize combine logic
    //========================================================
//***********************************************************//
//                                                           //
//                  Signals to IFU                           //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//
    always @(*) begin
        ex_if_pc_valid = 1'b0;
        ex_if_pc       = {DATA_WIDTH{1'b0}};
        ex_glb_flush   = 1'b0;

        if (id_ex_valid && j_taken) begin
            ex_if_pc_valid = 1'b1;
            ex_glb_flush   = 1'b1;

            if (is_jalr)
                ex_if_pc = (id_ex_rs1_data + id_ex_imm) & ~{{(DATA_WIDTH-1){1'b0}}, 1'b1};
            else
                ex_if_pc = id_ex_pc + id_ex_imm;
        end
    end

    //========================================================
    // Next EX/LSU payload generation
    //========================================================
    always @(*) begin
    ex_lsu_valid_nxt  = id_ex_valid;
    ex_lsu_addr_nxt   = alu_out;
    ex_lsu_data_nxt   = id_ex_rs2_data;
    ex_lsu_wb_rd_nxt  = id_ex_rd;
    ex_lsu_wb_wen_nxt = id_ex_rf_we;

    if (!id_ex_lsu_en)
        ex_lsu_ctrl_nxt = 2'b00;
    else if (id_ex_lsu_we)
        ex_lsu_ctrl_nxt = 2'b10;
    else
        ex_lsu_ctrl_nxt = 2'b01;

    case (id_ex_lsu_ctrl)
        `F3_LB, `F3_LBU: ex_lsu_size_nxt = 2'b00;
        `F3_LH, `F3_LHU: ex_lsu_size_nxt = 2'b01;
        `F3_LW         : ex_lsu_size_nxt = 2'b10;
        default        : ex_lsu_size_nxt = 2'b10;
    endcase

    case (wb_ctrl)
        `WB_PC  : ex_lsu_wb_data_nxt = id_ex_pc + 32'd4; // JAL / JALR
        `WB_IMM : ex_lsu_wb_data_nxt = id_ex_imm;        // LUI
        `WB_ALU : ex_lsu_wb_data_nxt = alu_out;          // ALU / AUIPC
        `WB_MEM : ex_lsu_wb_data_nxt = alu_out;          // 
        default: ex_lsu_wb_data_nxt = alu_out;
    endcase
end

//***********************************************************//
//                                                           //
//                  Reg Signals to LSU                       //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//
    always @(posedge clk) begin
        if (rst) begin
            ex_lsu_valid   <= 1'b0;
            ex_lsu_addr    <= {DATA_WIDTH{1'b0}};
            ex_lsu_data    <= {DATA_WIDTH{1'b0}};
            ex_lsu_ctrl    <= 2'b00;
            ex_lsu_size    <= 2'b10;
            ex_lsu_wb_data <= {DATA_WIDTH{1'b0}};
            ex_lsu_wb_rd   <= 5'b0;
            ex_lsu_wb_wen  <= 1'b0;
        end
        else if (lsu_ex_ready) begin
            // 下一级 ready，才能推进
            ex_lsu_valid   <= ex_lsu_valid_nxt;
            ex_lsu_addr    <= ex_lsu_addr_nxt;
            ex_lsu_data    <= ex_lsu_data_nxt;
            ex_lsu_ctrl    <= ex_lsu_ctrl_nxt;
            ex_lsu_size    <= ex_lsu_size_nxt;
            ex_lsu_wb_data <= ex_lsu_wb_data_nxt;
            ex_lsu_wb_rd   <= ex_lsu_wb_rd_nxt;
            ex_lsu_wb_wen  <= ex_lsu_wb_wen_nxt;
        end
        else begin
            ex_lsu_valid   <= ex_lsu_valid;
            ex_lsu_addr    <= ex_lsu_addr;
            ex_lsu_data    <= ex_lsu_data;
            ex_lsu_ctrl    <= ex_lsu_ctrl;
            ex_lsu_size    <= ex_lsu_size;
            ex_lsu_wb_data <= ex_lsu_wb_data;
            ex_lsu_wb_rd   <= ex_lsu_wb_rd;
            ex_lsu_wb_wen  <= ex_lsu_wb_wen;
        end
    end

endmodule
