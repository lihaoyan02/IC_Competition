`include "macro.v"

module IDU #(
    parameter INST_WIDTH    = `XLEN,
    parameter REGADDR_WIDTH = 5,
    parameter DATA_WIDTH    = `XLEN
) (
    input clk,
    input rst,  // Synchronous High Active reset

    // Signals to/from IFU
    input  [INST_WIDTH-1:0] if_id_instr,
    input                   if_id_instr_valid,
    input  [     `XLEN-1:0] if_id_pc,
    output                  id_if_instr_ready,

    // Signals to/from EXU
    input       ex_id_ready,
    input       ex_glb_flush,
    
    input       ex_lsu_valid,       //To detect 
    input       ex_lsu_wb_wen,
    input [4:0] ex_lsu_wb_rd,
    input [1:0] ex_lsu_ctrl,

    output reg                     id_ex_valid,
    output reg [   DATA_WIDTH-1:0] id_ex_imm,
//    output reg [        `XLEN-1:0] id_ex_rs1_data,
//    output reg [        `XLEN-1:0] id_ex_rs2_data,
    output reg [REGADDR_WIDTH-1:0] id_ex_rd,
    output reg [REGADDR_WIDTH-1:0] id_ex_rs1_addr,
    output reg [REGADDR_WIDTH-1:0] id_ex_rs2_addr,
    output reg [              3:0] id_ex_alu_ctrl,
    output reg [              1:0] alu_op_ctrl,
    output reg [        `XLEN-1:0] id_ex_pc,
    output reg [              2:0] wb_ctrl,
    output reg                     id_ex_rf_we,
    output reg                     id_ex_lsu_en,
    output reg                     id_ex_lsu_we,
    output reg [              2:0] id_ex_lsu_ctrl,
    output reg                     ebreak_flag,
    output reg                     j_en,
    output reg [              2:0] id_ex_J_cond,
    output reg                     id_ex_is_uload,

    // Register file access
//    input      [        `XLEN-1:0] rf_id_rs1_data,
//    input      [        `XLEN-1:0] rf_id_rs2_data,
//    output reg [REGADDR_WIDTH-1:0] id_rf_rs1_addr,
//    output reg [REGADDR_WIDTH-1:0] id_rf_rs2_addr,

    // Signals to/from csr
    output reg        id_ex_csr_wen,
    output reg        id_ex_csr_event,
    output reg [`CSR_ADDR_WIDTH-1:0] id_ex_csr_addr,

    //Global stall ctrl
    output reg id_glb_stall
);

localparam WB_IDLE = 3'b000,
           WB_ALU  = 3'b001,
           WB_PC   = 3'b010,
           WB_IMM  = 3'b011,
           WB_MEM  = 3'b100;

           
// -------------------------
// Next-state decoded signals
// -------------------------
reg [DATA_WIDTH-1:0]       id_ex_imm_nxt;
reg [REGADDR_WIDTH-1:0]    id_ex_rd_nxt;
reg [3:0]                  id_ex_alu_ctrl_nxt;
reg [1:0]                  alu_op_ctrl_nxt;
reg [2:0]                  wb_ctrl_nxt;
reg                        id_ex_rf_we_nxt;
reg                        id_ex_lsu_en_nxt;
reg                        id_ex_lsu_we_nxt;
reg                        ebreak_flag_nxt;
reg                        j_en_nxt;
reg [2:0]                  id_ex_J_cond_nxt;
reg                        csr_wen_nxt;
reg                        csr_event_nxt;
reg [11:0]                 csr_addr_nxt;
reg [2:0]                  id_ex_lsu_ctrl_nxt;
reg [REGADDR_WIDTH-1:0]    id_ex_rs1_addr_nxt;
reg [REGADDR_WIDTH-1:0]    id_ex_rs2_addr_nxt;
reg                        id_ex_is_uload_nxt;



// -------------------------
// Instruction fields
// -------------------------
wire [`OPCODE_WIDTH-1:0] opcode = if_id_instr[6:0];
wire [`FUNCT3_WIDTH-1:0] funct3 = if_id_instr[14:12];
wire [`FUNCT7_WIDTH-1:0] funct7 = if_id_instr[31:25];

wire [DATA_WIDTH-1:0] imm_I = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
wire [DATA_WIDTH-1:0] imm_U = {if_id_instr[31:12], 12'b0};
wire [DATA_WIDTH-1:0] imm_S = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
wire [DATA_WIDTH-1:0] imm_J = {{12{if_id_instr[31]}}, if_id_instr[19:12], if_id_instr[20], if_id_instr[30:21], 1'b0};
wire [DATA_WIDTH-1:0] imm_B = {{20{if_id_instr[31]}}, if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8], 1'b0};

// Current IF/ID instruction is an unconditional jump.
// Used only to stop IFU from fetching the next sequential PC.
wire uncond_jump_in_id = if_id_instr_valid && j_en_nxt && (id_ex_J_cond_nxt == `J_UNCOND);


//id_if_instr_ready
wire inst_ready_inter = ~id_glb_stall & ex_id_ready;
assign id_if_instr_ready = ~id_glb_stall & ex_id_ready & (!uncond_jump_in_id); // ID stage is ready when EX can take a new instr for uncondJ, stop

//***********************************************************//
//                                                           //
//                  Stall / Hazard Detect                    //
//                                                           //
//                                                           //
//***********************************************************//

//Identify current use of rs1 / rs2
reg uses_rs1;
reg uses_rs2;

always @(*) begin
    uses_rs1 = 1'b0;
    uses_rs2 = 1'b0;

    case (opcode)
        // R-type: rs1, rs2 in use
        `INST_TYPE_R: begin
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b1;
        end

        // I-type ALU / Load / JALR: rs1 in use
        `INST_TYPE_I,
        `INST_TYPE_IL,
        `INST_JALR: begin
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b0;
        end

        // Store / Branch: rs1, rs2 in use
        `INST_TYPE_S,
        `INST_TYPE_B: begin
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b1;
        end

        // SYSTEM:  rs1 in use
        `INST_SYSTEM: begin
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b0;
        end

        default: begin
            uses_rs1 = 1'b0;
            uses_rs2 = 1'b0;
        end
    endcase
end

// Current rs1 rs2
wire [4:0] rs1 = if_id_instr[19:15];
wire [4:0] rs2 = if_id_instr[24:20];

/*
//-----------------------------------------------------------
// RAW hazard with current EX->LSU stage
//-----------------------------------------------------------
wire raw_hazard_rs1 = if_id_instr_valid && uses_rs1 &&
                      ex_lsu_valid && ex_lsu_wb_wen &&
                      (ex_lsu_wb_rd != 5'b0) &&
                      (ex_lsu_wb_rd == rs1);

wire raw_hazard_rs2 = if_id_instr_valid && uses_rs2 &&
                      ex_lsu_valid && ex_lsu_wb_wen &&
                      (ex_lsu_wb_rd != 5'b0) &&
                      (ex_lsu_wb_rd == rs2);

wire raw_hazard = raw_hazard_rs1 || raw_hazard_rs2;

//-----------------------------------------------------------
// load-use hazard
// ex_lsu_ctrl == 2'b01 means load/read
//-----------------------------------------------------------
wire load_use_hazard = (ex_lsu_ctrl == 2'b01) && raw_hazard;
//wire uncond_jump_in_ex = id_ex_valid && j_en && (id_ex_J_cond == `J_UNCOND);

//-----------------------------------------------------------
// Stall generation
//-----------------------------------------------------------
always @(*) begin
    if (rst)
        id_glb_stall = 1'b0;
//    else if (ex_glb_flush)
//        id_glb_stall = 1'b0;
    else
        id_glb_stall = load_use_hazard || raw_hazard;
end
*/

//-----------------------------------------------------------
// load-use hazard
//-----------------------------------------------------------
wire id_ex_is_load = id_ex_valid &&
                     id_ex_lsu_en &&
                    !id_ex_lsu_we &&
                     id_ex_rf_we;

wire load_use_hazard_rs1 = if_id_instr_valid &&
                           uses_rs1 &&
                           id_ex_is_load &&
                           (id_ex_rd != 5'b0) &&
                           (id_ex_rd == rs1);

wire load_use_hazard_rs2 = if_id_instr_valid &&
                           uses_rs2 &&
                           id_ex_is_load &&
                           (id_ex_rd != 5'b0) &&
                           (id_ex_rd == rs2);

wire load_use_hazard = load_use_hazard_rs1 || load_use_hazard_rs2;

//-----------------------------------------------------------
// Stall generation
//-----------------------------------------------------------
always @(*) begin
    if (rst)
        id_glb_stall = 1'b0;
    else
        id_glb_stall = load_use_hazard & ex_id_ready;
end


`ifndef SYNTHESIS
task unknown_inst;
    input [`XLEN-1:0] if_id_instr_t;
    input [`XLEN-1:0] if_id_pc_t;
begin
    $display("[%0t] ERROR: Unknown instruction detected!", $time);
    $display("    PC   = 0x%08h", if_id_pc_t);
    $display("    INST = 0x%08h", if_id_instr_t);
end
endtask
`endif

// -------------------------
// Combinational decode
// -------------------------
always @(*) begin
    // defaults
    id_ex_rd_nxt       = if_id_instr[11:7];
    id_ex_imm_nxt      = {DATA_WIDTH{1'b0}};
    id_ex_alu_ctrl_nxt = `ALU_IDLE;
    alu_op_ctrl_nxt    = `OP_RS1_RS2;
    wb_ctrl_nxt        = WB_IDLE;
    id_ex_rf_we_nxt    = 1'b0;
    id_ex_lsu_en_nxt   = 1'b0;
    id_ex_lsu_we_nxt   = 1'b0;
    ebreak_flag_nxt    = 1'b0;
    j_en_nxt           = 1'b0;
    id_ex_J_cond_nxt   = `J_UNCOND;
    csr_wen_nxt        = 1'b0;
    csr_event_nxt      = 1'b0;
    csr_addr_nxt       = if_id_instr[31:20];
    id_ex_lsu_ctrl_nxt = funct3;
    id_ex_is_uload_nxt = 1'b0;

    if (if_id_instr_valid) begin
        case (opcode)
            `INST_AUIPC: begin
                id_ex_alu_ctrl_nxt = `ALU_ADD;
                alu_op_ctrl_nxt    = `OP_PC_IMM;
                id_ex_imm_nxt      = imm_U;
                id_ex_rf_we_nxt    = 1'b1;
                wb_ctrl_nxt        = WB_ALU;
            end

            `INST_LUI: begin
                id_ex_imm_nxt   = imm_U;
                id_ex_rf_we_nxt = 1'b1;
                wb_ctrl_nxt     = WB_IMM;
            end

            `INST_TYPE_I: begin
                alu_op_ctrl_nxt = `OP_RS1_IMM;
                id_ex_imm_nxt   = imm_I;
                id_ex_rf_we_nxt = 1'b1;
                wb_ctrl_nxt     = WB_ALU;

                if (funct3 == `F3_ADDI) begin
                    id_ex_alu_ctrl_nxt = `ALU_ADD;
                end
                else if (funct3 == `F3_SLTIU) begin
                    id_ex_alu_ctrl_nxt = `ALU_LESS_U;
                end
                else if (funct3 == `F3_XORI) begin
                    id_ex_alu_ctrl_nxt = `ALU_XOR;
                end
                else if (funct3 == `F3_ORI) begin
                    id_ex_alu_ctrl_nxt = `ALU_OR;
                end
                else if (funct3 == `F3_ANDI) begin
                    id_ex_alu_ctrl_nxt = `ALU_AND;
                end
                else if (funct3 == `F3_SLTI) begin
                    id_ex_alu_ctrl_nxt = `ALU_LESS;
                end
                else if ((funct3 == `F3_SRLI_SRAI) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_SHIFT_RIGHT_U;
                end
                else if ((funct3 == `F3_SRLI_SRAI) && (funct7 == `F7_INST_B)) begin
                    id_ex_alu_ctrl_nxt = `ALU_SHIFT_RIGHT;
                end
                else if ((funct3 == `F3_SLLI) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_SHIFT_LEFT;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_TYPE_R: begin
                alu_op_ctrl_nxt = `OP_RS1_RS2;
                id_ex_rf_we_nxt = 1'b1;
                wb_ctrl_nxt     = WB_ALU;

                if ((funct3 == `F3_ADD_SUB) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_ADD;
                end
                else if ((funct3 == `F3_ADD_SUB) && (funct7 == `F7_INST_B)) begin
                    id_ex_alu_ctrl_nxt = `ALU_SUB;
                end
                else if ((funct3 == `F3_XOR) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_XOR;
                end
                else if ((funct3 == `F3_OR) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_OR;
                end
                else if ((funct3 == `F3_AND) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_AND;
                end
                else if ((funct3 == `F3_SRL_SRA) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_SHIFT_RIGHT_U;
                end
                else if ((funct3 == `F3_SRL_SRA) && (funct7 == `F7_INST_B)) begin
                    id_ex_alu_ctrl_nxt = `ALU_SHIFT_RIGHT;
                end
                else if ((funct3 == `F3_SLT) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_LESS;
                end
                else if ((funct3 == `F3_SLTU) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_LESS_U;
                end
                else if ((funct3 == `F3_SLL) && (funct7 == `F7_INST_A)) begin
                    id_ex_alu_ctrl_nxt = `ALU_SHIFT_LEFT;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_JAL: begin
                id_ex_alu_ctrl_nxt = `ALU_ADD;
                alu_op_ctrl_nxt    = `OP_PC_IMM;
                id_ex_imm_nxt      = imm_J;
                id_ex_rf_we_nxt    = 1'b1;
                wb_ctrl_nxt        = WB_PC;
                j_en_nxt           = 1'b1;
            end

            `INST_JALR: begin
                if (funct3 == 3'b000) begin
                    id_ex_alu_ctrl_nxt = `ALU_ADD;
                    alu_op_ctrl_nxt    = `OP_RS1_IMM;
                    id_ex_imm_nxt      = imm_I;
                    id_ex_rf_we_nxt    = 1'b1;
                    wb_ctrl_nxt        = WB_PC;
                    j_en_nxt           = 1'b1;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_TYPE_B: begin
                id_ex_alu_ctrl_nxt = `ALU_ADD;
                alu_op_ctrl_nxt    = `OP_PC_IMM;
                id_ex_imm_nxt      = imm_B;
                id_ex_rf_we_nxt    = 1'b0;
                j_en_nxt           = 1'b1;

                if (funct3 == `F3_BEQ) begin
                    id_ex_J_cond_nxt = `J_BEQ;
                end
                else if (funct3 == `F3_BNE) begin
                    id_ex_J_cond_nxt = `J_BNE;
                end
                else if (funct3 == `F3_BGEU) begin
                    id_ex_J_cond_nxt = `J_BGE_U;
                end
                else if (funct3 == `F3_BGE) begin
                    id_ex_J_cond_nxt = `J_BGE;
                end
                else if (funct3 == `F3_BLTU) begin
                    id_ex_J_cond_nxt = `J_BLT_U;
                end
                else if (funct3 == `F3_BLT) begin
                    id_ex_J_cond_nxt = `J_BLT;
                end
                else begin
                    `ifndef SYNTHESIS
                        unknown_inst(if_id_instr, if_id_pc);
                    `endif
                end
            end

            `INST_TYPE_IL: begin
                case (funct3)
                    `F3_LB, `F3_LH, `F3_LW: begin
                        id_ex_alu_ctrl_nxt = `ALU_ADD;
                        alu_op_ctrl_nxt    = `OP_RS1_IMM;
                        id_ex_imm_nxt      = imm_I;
                        id_ex_lsu_en_nxt   = 1'b1;
                        id_ex_lsu_we_nxt   = 1'b0;
                        id_ex_rf_we_nxt    = 1'b1;
                        wb_ctrl_nxt        = WB_MEM;
                        id_ex_is_uload_nxt = 1'b0;
                    end
                    `F3_LBU, `F3_LHU: begin
                        id_ex_alu_ctrl_nxt = `ALU_ADD;
                        alu_op_ctrl_nxt    = `OP_RS1_IMM;
                        id_ex_imm_nxt      = imm_I;
                        id_ex_lsu_en_nxt   = 1'b1;
                        id_ex_lsu_we_nxt   = 1'b0;
                        id_ex_rf_we_nxt    = 1'b1;
                        wb_ctrl_nxt        = WB_MEM;    
                        id_ex_is_uload_nxt = 1'b1;                    
                    end
                    default: begin
                        `ifndef SYNTHESIS
                            unknown_inst(if_id_instr, if_id_pc);
                        `endif
                    end
                endcase
            end

            `INST_TYPE_S: begin
                case (funct3)
                    `F3_SB, `F3_SH, `F3_SW: begin
                        id_ex_alu_ctrl_nxt = `ALU_ADD;
                        alu_op_ctrl_nxt    = `OP_RS1_IMM;
                        id_ex_imm_nxt      = imm_S;
                        id_ex_lsu_en_nxt   = 1'b1;
                        id_ex_lsu_we_nxt   = 1'b1;
                        id_ex_rf_we_nxt    = 1'b0;
                    end
                    default: begin
                        `ifndef SYNTHESIS
                            unknown_inst(if_id_instr, if_id_pc);
                        `endif
                    end
                endcase
            end

            `INST_SYSTEM: begin
                if ((imm_I == {{(DATA_WIDTH-1){1'b0}},1'b1}) &&
                    (id_ex_rs1_addr_nxt == {REGADDR_WIDTH{1'b0}}) &&
                    (funct3 == `F3_EBREAK) &&
                    (id_ex_rd_nxt == {REGADDR_WIDTH{1'b0}})) begin
                    ebreak_flag_nxt = 1'b1;
                end
                /*ecall*/
                else if (if_id_instr[31:7] == 25'b0) begin
                    csr_addr_nxt       = 12'h305; // mtvec
                    csr_event_nxt      = 1'b1;
                    id_ex_alu_ctrl_nxt = `ALU_OP2;
                    alu_op_ctrl_nxt    = `OP_RS1_CSR;
                    j_en_nxt           = 1'b1;
                end
                /*mret*/
                else if (if_id_instr[31:7] == 25'b001100000010_00000_000_00000) begin
                    csr_addr_nxt       = 12'h341; // mepc
                    id_ex_alu_ctrl_nxt = `ALU_OP2;
                    alu_op_ctrl_nxt    = `OP_RS1_CSR;
                    j_en_nxt           = 1'b1;
                end
                /*------csrrw------*/
                else if (funct3 == 3'b001) begin
                    id_ex_alu_ctrl_nxt = `ALU_OP2;
                    alu_op_ctrl_nxt    = `OP_RS1_CSR;
                    csr_wen_nxt        = 1'b1;
                    id_ex_rf_we_nxt    = 1'b1;
                    wb_ctrl_nxt        = WB_ALU;
                end
                /*------csrrs------*/
                else if (funct3 == 3'b010) begin
                    id_ex_alu_ctrl_nxt = `ALU_OR;
                    alu_op_ctrl_nxt    = `OP_RS1_CSR;
                    csr_wen_nxt        = 1'b0;
                    id_ex_rf_we_nxt    = 1'b1;
                    wb_ctrl_nxt        = WB_ALU;
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

//***********************************************************//
//                                                           //
//         control signal to register file access            //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//
always @(*) begin
    if (rst) begin
        id_ex_rs1_addr_nxt = {REGADDR_WIDTH{1'b0}};
        id_ex_rs2_addr_nxt = {REGADDR_WIDTH{1'b0}};
    end
    else if (ex_glb_flush) begin
        id_ex_rs1_addr_nxt = {REGADDR_WIDTH{1'b0}};
        id_ex_rs2_addr_nxt = {REGADDR_WIDTH{1'b0}};
    end
    else begin
        id_ex_rs1_addr_nxt = if_id_instr[19:15];
        id_ex_rs2_addr_nxt = if_id_instr[24:20];
    end
end

//***********************************************************//
//                                                           //
//                  Reg control signal to EXU                //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//
//valid / basic data path
always @(posedge clk) begin
    if (rst) begin
        id_ex_valid    <= 1'b0;
        id_ex_pc       <= `XLEN'b0;
        id_ex_imm      <= {DATA_WIDTH{1'b0}};
//        id_ex_rs1_data <= `XLEN'b0;
//        id_ex_rs2_data <= `XLEN'b0;
        id_ex_rs1_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rs2_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rd       <= {REGADDR_WIDTH{1'b0}};

        id_ex_alu_ctrl <= `ALU_IDLE;
        alu_op_ctrl    <= `OP_RS1_RS2;
        wb_ctrl        <= WB_IDLE;
        id_ex_rf_we    <= 1'b0;
        id_ex_is_uload <= 1'b0;

        id_ex_lsu_en   <= 1'b0;
        id_ex_lsu_we   <= 1'b0;
        id_ex_lsu_ctrl <= 3'b0;

        ebreak_flag  <= 1'b0;
        j_en         <= 1'b0;
        id_ex_J_cond <= `J_UNCOND;

        id_ex_csr_wen   <= 1'b0;
        id_ex_csr_event <= 1'b0;
        id_ex_csr_addr  <= 12'b0;
    end
    else if (ex_glb_flush) begin
        id_ex_valid    <= 1'b0;
        id_ex_pc       <= id_ex_pc;
        id_ex_imm      <= {DATA_WIDTH{1'b0}};
//        id_ex_rs1_data <= `XLEN'b0;
//        id_ex_rs2_data <= `XLEN'b0;
        id_ex_rs1_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rs2_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rd       <= {REGADDR_WIDTH{1'b0}};

        id_ex_alu_ctrl <= `ALU_IDLE;
        alu_op_ctrl    <= `OP_RS1_RS2;
        wb_ctrl        <= WB_IDLE;
        id_ex_rf_we    <= 1'b0;
        id_ex_is_uload <= 1'b0;

        id_ex_lsu_en   <= 1'b0;
        id_ex_lsu_we   <= 1'b0;
        id_ex_lsu_ctrl <= 3'b0;

        ebreak_flag  <= 1'b0;
        j_en         <= 1'b0;
        id_ex_J_cond <= `J_UNCOND;

        id_ex_csr_wen   <= 1'b0;
        id_ex_csr_event <= 1'b0;
        id_ex_csr_addr  <= 12'b0;
    end
    else if (id_glb_stall) begin

        // Insert bubble into ID/EX for load-use hazard.
        // IF/ID is held by id_if_instr_ready = 0.
        id_ex_valid    <= 1'b0;
        id_ex_pc       <= id_ex_pc;
        id_ex_imm      <= {DATA_WIDTH{1'b0}};
//        id_ex_rs1_data <= `XLEN'b0;
//        id_ex_rs2_data <= `XLEN'b0;
        id_ex_rs1_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rs2_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rd       <= {REGADDR_WIDTH{1'b0}};

        id_ex_alu_ctrl <= `ALU_IDLE;
        alu_op_ctrl    <= `OP_RS1_RS2;
        wb_ctrl        <= WB_IDLE;
        id_ex_rf_we    <= 1'b0;
        id_ex_is_uload <= 1'b0;

        id_ex_lsu_en   <= 1'b0;
        id_ex_lsu_we   <= 1'b0;
        id_ex_lsu_ctrl <= 3'b0;

        ebreak_flag  <= 1'b0;
        j_en         <= 1'b0;
        id_ex_J_cond <= `J_UNCOND;

        id_ex_csr_wen   <= 1'b0;
        id_ex_csr_event <= 1'b0;
        id_ex_csr_addr  <= 12'b0;

    end
    else if (if_id_instr_valid & inst_ready_inter) begin
        id_ex_valid    <= 1;
        id_ex_pc       <= if_id_pc;
        id_ex_imm      <= id_ex_imm_nxt;
//        id_ex_rs1_data <= rf_id_rs1_data;
//        id_ex_rs2_data <= rf_id_rs2_data;
        id_ex_rs1_addr <= id_ex_rs1_addr_nxt;
        id_ex_rs2_addr <= id_ex_rs2_addr_nxt;
        id_ex_rd       <= id_ex_rd_nxt;

        id_ex_alu_ctrl <= id_ex_alu_ctrl_nxt;
        alu_op_ctrl    <= alu_op_ctrl_nxt;
        wb_ctrl        <= wb_ctrl_nxt;
        id_ex_rf_we    <= id_ex_rf_we_nxt;
        id_ex_is_uload <= id_ex_is_uload_nxt;

        id_ex_lsu_en   <= id_ex_lsu_en_nxt;
        id_ex_lsu_we   <= id_ex_lsu_we_nxt;
        id_ex_lsu_ctrl <= id_ex_lsu_ctrl_nxt;

        ebreak_flag  <= ebreak_flag_nxt;
        j_en         <= j_en_nxt;
        id_ex_J_cond <= id_ex_J_cond_nxt;

        id_ex_csr_wen   <= csr_wen_nxt;
        id_ex_csr_event <= csr_event_nxt;
        id_ex_csr_addr  <= csr_addr_nxt;
    end
    else if (inst_ready_inter & id_ex_valid) begin
        id_ex_valid    <= 1'b0;
        id_ex_pc       <= id_ex_pc;
        id_ex_imm      <= {DATA_WIDTH{1'b0}};
//        id_ex_rs1_data <= `XLEN'b0;
//        id_ex_rs2_data <= `XLEN'b0;
        id_ex_rs1_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rs2_addr <= {REGADDR_WIDTH{1'b0}};
        id_ex_rd       <= {REGADDR_WIDTH{1'b0}};

        id_ex_alu_ctrl <= `ALU_IDLE;
        alu_op_ctrl    <= `OP_RS1_RS2;
        wb_ctrl        <= WB_IDLE;
        id_ex_rf_we    <= 1'b0;
        id_ex_is_uload <= 1'b0;

        id_ex_lsu_en   <= 1'b0;
        id_ex_lsu_we   <= 1'b0;
        id_ex_lsu_ctrl <= 3'b0;

        ebreak_flag  <= 1'b0;
        j_en         <= 1'b0;
        id_ex_J_cond <= `J_UNCOND;

        id_ex_csr_wen   <= 1'b0;
        id_ex_csr_event <= 1'b0;
        id_ex_csr_addr  <= 12'b0;
    end
end

endmodule
