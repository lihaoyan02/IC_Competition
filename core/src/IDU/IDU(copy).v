`include "macro.v"

module IDU #(
    parameter INST_WIDTH    = `XLEN,
    parameter REGADDR_WIDTH = 5,
    parameter DATA_WIDTH    = `XLEN
) (
    input clk,
    input rst,  //Synchronous High Active reset

    // Singnals to/from IFU
    input  [INST_WIDTH-1:0]      if_id_instr,
    input                        if_id_instr_valid,
    input  [`XLEN-1:0]           if_id_pc,
    output                       id_if_instr_ready,

    // Singnals to/from EXU
    input                           ex_id_ready,
    input                           ex_glb_flush,    //Flush pipe line 

    output reg                      id_ex_valid,     //High Active
    output reg [DATA_WIDTH-1:0]     id_ex_imm,
    output reg [REGADDR_WIDTH-1:0]  id_ex_rd,
    //output reg [REGADDR_WIDTH-1:0]  id_rf_rs1_addr,
    //output reg [REGADDR_WIDTH-1:0]  id_rf_rs2_addr,
    output reg [3:0]                id_ex_alu_ctrl,     //ALU function
    output reg [1:0]                alu_op_ctrl,        //Select ALU OP1 and OP2
    output reg [`XLEN-1:0]          id_ex_pc,
    output reg [2:0]                wb_ctrl,       // 
    output reg                      id_ex_rf_we,
    output reg                      id_ex_lsu_en,        // 
    output reg                      id_ex_lsu_we,
    output      [2:0]               lsu_ctrl,      // 
    output reg                      ebreak_flag,
    output reg                      j_en,          // 
    output      [2:0]               id_ex_J_cond,

    // Register file access
    output reg [REGADDR_WIDTH-1:0]  id_rf_rs1_addr,
    output reg [REGADDR_WIDTH-1:0]  id_rf_rs2_addr,

    // Singnals to/from csr
    output reg                      csr_wen,
    output reg                      csr_event,
    output reg [11:0]               csr_addr
);

localparam WB_IDLE = 3'b000,
           WB_ALU  = 3'b001,
           WB_PC   = 3'b010,
           WB_IMM  = 3'b011,
           WB_MEM  = 3'b100;
reg [2:0] j_cond_r;

wire [`OPCODE_WIDTH-1:0] opcode;
wire [`FUNCT3_WIDTH-1:0] funct3;
wire [`FUNCT7_WIDTH-1:0] funct7;

wire [DATA_WIDTH-1:0] imm_I;
wire [DATA_WIDTH-1:0] imm_U;
wire [DATA_WIDTH-1:0] imm_S;
wire [DATA_WIDTH-1:0] imm_J;
wire [DATA_WIDTH-1:0] imm_B;

assign opcode = if_id_instr[6:0];
assign funct3 = if_id_instr[14:12];
assign funct7 = if_id_instr[31:25];

assign imm_I = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
assign imm_U = {if_id_instr[31:12], 12'b0};
assign imm_S = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
assign imm_J = {{12{if_id_instr[31]}}, if_id_instr[19:12], if_id_instr[20], if_id_instr[30:21], 1'b0};
assign imm_B = {{20{if_id_instr[31]}}, if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8], 1'b0};

assign lsu_ctrl    = funct3;
assign id_ex_J_cond = j_cond_r;



//import "DPI-C" function void unknow_inst();

//id_if_instr_ready
assign id_if_instr_ready = ex_id_ready;


always @(*) begin
    // default value
    id_ex_rd       = if_id_instr[11:7];
    id_rf_rs1_addr = if_id_instr[19:15];
    id_rf_rs2_addr = if_id_instr[24:20];

    // keep these as-is because corresponding macros were not provided in your snippet
    id_ex_alu_ctrl = `ALU_IDLE;       // 
    alu_op_ctrl    = `OP_RS1_RS2;
    id_ex_imm      = {DATA_WIDTH{1'b0}};
    id_ex_rf_we    = 1'b0;
    wb_ctrl        = WB_IDLE;
    id_ex_lsu_en   = 1'b0;
    id_ex_lsu_we    = 1'b0;
    ebreak_flag    = 1'b0;
    j_en           = 1'b0;
    j_cond_r       = `J_UNCOND;
    csr_wen        = 1'b0;
    csr_event      = 1'b0;
    csr_addr       = if_id_instr[31:20];

    if (if_id_instr_valid) begin
        case (opcode)
            `INST_AUIPC: begin
                id_ex_alu_ctrl = `ALU_ADD;
                alu_op_ctrl    = `OP_PC_IMM;
                id_ex_imm      = imm_U;
                id_ex_rf_we    = 1'b1;
                wb_ctrl        = WB_ALU;
            end

            `INST_LUI: begin
                id_ex_imm   = imm_U;
                id_ex_rf_we = 1'b1;
                wb_ctrl     = WB_IMM;
            end

            `INST_TYPE_I: begin
                alu_op_ctrl = `OP_RS1_IMM;
                id_ex_imm   = imm_I;
                id_ex_rf_we = 1'b1;
                wb_ctrl     = WB_ALU;

                if (funct3 == `F3_ADDI) begin
                    id_ex_alu_ctrl = `ALU_ADD;
                end
                else if (funct3 == `F3_SLTIU) begin
                    id_ex_alu_ctrl = `ALU_LESS_U;
                end
                else if (funct3 == `F3_XORI) begin
                    id_ex_alu_ctrl = `ALU_XOR;
                end
                else if (funct3 == `F3_ORI) begin
                    id_ex_alu_ctrl = `ALU_OR;
                end
                else if (funct3 == `F3_ANDI) begin
                    id_ex_alu_ctrl = `ALU_AND;
                end
                else if (funct3 == `F3_SLTI) begin
                    id_ex_alu_ctrl = `ALU_LESS;
                end
                else if ((funct3 == `F3_SRLI_SRAI) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_SHIFT_RIGHT_U;
                end
                else if ((funct3 == `F3_SRLI_SRAI) && (funct7 == `F7_INST_B)) begin
                    id_ex_alu_ctrl = `ALU_SHIFT_RIGHT;
                end
                else if ((funct3 == `F3_SLLI) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_SHIFT_LEFT;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_TYPE_R: begin
                alu_op_ctrl = `OP_RS1_RS2;
                id_ex_rf_we = 1'b1;
                wb_ctrl     = WB_ALU;

                if ((funct3 == `F3_ADD_SUB) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_ADD;
                end
                else if ((funct3 == `F3_ADD_SUB) && (funct7 == `F7_INST_B)) begin
                    id_ex_alu_ctrl = `ALU_SUB;
                end
                else if ((funct3 == `F3_XOR) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_XOR;
                end
                else if ((funct3 == `F3_OR) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_OR;
                end
                else if ((funct3 == `F3_AND) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_AND;
                end
                else if ((funct3 == `F3_SRL_SRA) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_SHIFT_RIGHT_U;
                end
                else if ((funct3 == `F3_SRL_SRA) && (funct7 == `F7_INST_B)) begin
                    id_ex_alu_ctrl = `ALU_SHIFT_RIGHT;
                end
                else if ((funct3 == `F3_SLT) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_LESS;
                end
                else if ((funct3 == `F3_SLTU) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_LESS_U;
                end
                else if ((funct3 == `F3_SLL) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl = `ALU_SHIFT_LEFT;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_JAL: begin
                id_ex_alu_ctrl = `ALU_ADD;
                alu_op_ctrl    = `OP_PC_IMM;
                id_ex_imm      = imm_J;
                id_ex_rf_we    = 1'b1;
                wb_ctrl        = WB_PC;
                j_en           = 1'b1;
            end

            `INST_JALR: begin
                if (funct3 == `F3_ECALL) begin
                    id_ex_alu_ctrl = `ALU_ADD;
                    alu_op_ctrl    = `OP_RS1_IMM;
                    id_ex_imm      = imm_I;
                    id_ex_rf_we    = 1'b1;
                    wb_ctrl        = WB_PC;
                    j_en           = 1'b1;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_TYPE_B: begin
                id_ex_alu_ctrl = `ALU_ADD;
                alu_op_ctrl    = `OP_PC_IMM;
                id_ex_imm      = imm_B;
                id_ex_rf_we    = 1'b0;
                j_en           = 1'b1;

                if (funct3 == `F3_BEQ) begin
                    j_cond_r = `J_BEQ;
                end
                else if (funct3 == `F3_BNE) begin
                    j_cond_r = `J_BNE;
                end
                else if (funct3 == `F3_BGEU) begin
                    j_cond_r = `J_BGE_U;
                end
                else if (funct3 == `F3_BGE) begin
                    j_cond_r = `J_BGE;
                end
                else if (funct3 == `F3_BLTU) begin
                    j_cond_r = `J_BLT_U;
                end
                else if (funct3 == `F3_BLT) begin
                    j_cond_r = `J_BLT;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_TYPE_IL: begin
                case (funct3)
                    `F3_LB, `F3_LH, `F3_LW, `F3_LBU, `F3_LHU: begin
                        id_ex_alu_ctrl = `ALU_ADD;
                        alu_op_ctrl    = `OP_RS1_IMM;
                        id_ex_imm      = imm_I;
                        id_ex_lsu_en   = 1'b1;
                        id_ex_lsu_we    = 1'b0;
                        id_ex_rf_we    = 1'b1;
                        wb_ctrl        = WB_MEM;
                    end
                    default: `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                endcase
            end

            `INST_TYPE_S: begin
                case (funct3)
                    `F3_SB, `F3_SH, `F3_SW: begin
                        id_ex_alu_ctrl = `ALU_ADD;
                        alu_op_ctrl    = `OP_RS1_IMM;
                        id_ex_imm      = imm_S;
                        id_ex_lsu_en   = 1'b1;
                        id_ex_lsu_we    = 1'b1;
                        id_ex_rf_we    = 1'b0;
                    end
                    default: `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                endcase
            end

            `INST_SYSTEM: begin
                if ((imm_I == {{(DATA_WIDTH-1){1'b0}},1'b1}) &&
                    (id_rf_rs1_addr == {REGADDR_WIDTH{1'b0}}) &&
                    (funct3 == `F3_EBREAK) &&
                    (id_ex_rd == {REGADDR_WIDTH{1'b0}})) begin
                    ebreak_flag = 1'b1;
                end
                else if (if_id_instr[31:7] == 25'b0) begin
                    // ecall
                    csr_addr       = 12'h305; // mtvec
                    csr_event      = 1'b1;
                    id_ex_alu_ctrl = `ALU_OP2;
                    alu_op_ctrl    = `OP_RS1_CSR;
                    j_en           = 1'b1;
                end
                else if (if_id_instr[31:7] == 25'b001100000010_00000_000_00000) begin
                    // mret
                    csr_addr       = 12'h341; // mepc
                    id_ex_alu_ctrl = `ALU_OP2;
                    alu_op_ctrl    = `OP_RS1_CSR;
                    j_en           = 1'b1;
                end
                else if (funct3 == 3'b001) begin
                    // csrrw
                    id_ex_alu_ctrl = `ALU_OP2;
                    alu_op_ctrl    = `OP_RS1_CSR;
                    csr_wen        = 1'b1;
                    id_ex_rf_we    = 1'b1;
                    wb_ctrl        = WB_ALU;
                end
                else if (funct3 == 3'b010) begin
                    // csrrs
                    id_ex_alu_ctrl = `ALU_OR;
                    alu_op_ctrl    = `OP_RS1_CSR;
                    csr_wen        = 1'b0;
                    id_ex_rf_we    = 1'b1;
                    wb_ctrl        = WB_ALU;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            default: begin
                `ifndef SYNTHESIS
                    unknown_inst(if_id_instr, if_id_pc);
                `endif
            end
        endcase
    end
end

//id_ex_pc
always @(posedge clk) begin
    if(rst) 
        id_ex_pc <= `XLEN'b0;
    else if(ex_glb_flush)
        id_ex_pc <= `XLEN'b0;
    else 
        id_ex_pc <= if_id_pc;
end

//id_ex_valid
always @(posedge clk) begin
    if(rst) 
        id_ex_valid <= 1'b0;
    else if(ex_glb_flush)
        id_ex_valid <= 1'b0;
    else 
        id_ex_valid <= (ex_id_ready & if_id_instr_valid) ? 1'b1 : 1'b0;
end


`ifndef SYNTHESIS
task unknown_inst;
    input [`XLEN-1:0] if_id_instr;
    input [`XLEN-1:0] if_id_pc;
begin
    $display("[%0t] ERROR: Unknown instruction detected!", $time);
    $display("    PC   = 0x%08h", if_id_pc);
    $display("    INST = 0x%08h", if_id_instr);
end
endtask
`endif

endmodule
