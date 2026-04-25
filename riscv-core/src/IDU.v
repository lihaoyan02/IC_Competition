`include "macro.v"

module IDU (
    input clk,
    input rst,  //Synchronous High Active reset

    // Singnals to/from IFU
    input  [`XLEN-1:0] if_id_instr,
    input  [`XLEN-1:0] if_id_pc,
    input              if_id_instr_valid,
    output             id_if_instr_ready,

    // Singnals to/from EXU
    input                  ex_id_ready,
    input                  ex_glb_flush,    //Flush pipe line
    input                  ex_mem_rf_we,    //To detecet RAW
    input      [      4:0] ex_mem_rd,       //To detecet RAW
    output reg             id_ex_valid,     //High Active
    output reg [      3:0] id_ex_alu_ctrl,  //Modified here original [2:0]
    output reg [      2:0] id_ex_op1,
    output reg [      2:0] id_ex_op2,
    output reg [`XLEN-1:0] id_ex_imm,
    output reg [`XLEN-1:0] id_ex_rs1_data,
    output reg [`XLEN-1:0] id_ex_rs2_data,
    output reg [`XLEN-1:0] id_ex_pc,
    output reg [      4:0] id_ex_rd,
    output reg             id_ex_is_brch,
    output reg             id_ex_is_jump,
    output reg [      2:0] id_ex_J_cond,
    output reg             id_ex_dm_re,
    output reg             id_ex_dm_we,
    output reg             id_ex_rf_we,


    //register file access
    input  [`XLEN-1:0]  rf_id_rs1_data,      //For now, assume that the reg file read out data with conbine logic
    input  [`XLEN-1:0]  rf_id_rs2_data,      //For now, assume that the reg file read out data with conbine logic
    output reg [4:0] id_rf_rs1_addr,
    output reg [4:0] id_rf_rs2_addr,

    //Global stall ctrl
    output reg id_glb_stall

);


//regroup instruction
wire [6:0] opcode = if_id_instr[6:0];
wire [2:0] funct3 = if_id_instr[14:12];
wire [6:0] funct7 = if_id_instr[31:25];
wire [4:0] rs1    = if_id_instr[19:15];
wire [4:0] rs2    = if_id_instr[24:20];
wire [4:0] rd     = if_id_instr[11:7];

//imm_number
reg [`XLEN-1:0] imm;

always @(*) begin
    imm = `XLEN'b0;
    case (opcode)
        // I-type (ADDI, LW, JALR)
        `INST_TYPE_I,`INST_TYPE_IL,`INST_JALR:
            imm = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
        // S-type (SW)
        `INST_TYPE_S:
            imm = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
        // B-type (BEQ, BNE)
        `INST_TYPE_B:
            imm = {{20{if_id_instr[31]}}, if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8], 1'b0};
        // U-type (LUI, AUIPC)
        `INST_LUI,`INST_AUIPC:
            imm = {if_id_instr[31:12], 12'b0};
        // J-type (JAL)
        `INST_JAL:
            imm = {{12{if_id_instr[31]}}, if_id_instr[19:12], if_id_instr[20], if_id_instr[30:21], 1'b0};
        default: 
            imm = `XLEN'b0;
    endcase
end

//***********************************************************//
//                                                           //
//                      signal to IFU                        //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//

//id_if_instr_ready
assign id_if_instr_ready = ~id_glb_stall & ex_id_ready;

//***********************************************************//
//                                                           //
//                  control signal to EXU                    //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//

//id_ex_valid
always @(posedge clk) begin
    if(rst) 
        id_ex_valid <= 1'b0;
    else if(ex_glb_flush)
        id_ex_valid <= 1'b0;
    else 
        id_ex_valid <= (ex_id_ready & if_id_instr_valid) ? 1'b1 : 1'b0;
end

//id_ex_alu_ctrl
always @(posedge clk) begin
    if(rst) 
        id_ex_alu_ctrl <= 4'b0;
    else if(ex_glb_flush)
        id_ex_alu_ctrl <= 4'b0;
    else begin
        case (opcode)
            //Type R
            `INST_TYPE_R: begin         //reg
                case (funct3)
                `F3_ADD_SUB: begin
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_ADD : id_ex_alu_ctrl;
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_B) ? `ALU_SUB : id_ex_alu_ctrl;
                end
                `F3_XOR:
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_XOR : id_ex_alu_ctrl;
                `F3_OR:
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_OR : id_ex_alu_ctrl;
                `F3_AND:
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_AND : id_ex_alu_ctrl;
                `F3_SLL:
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_SLL : id_ex_alu_ctrl;
                `F3_SRL_SRA: begin
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_SRL : id_ex_alu_ctrl;
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_B) ? `ALU_SRA : id_ex_alu_ctrl;
                end
                `F3_SLT:
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_SLT : id_ex_alu_ctrl;
                `F3_SLTU:
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_SLTU : id_ex_alu_ctrl;
                default: ;
                endcase
            end
            
            //Type I
            `INST_TYPE_I: begin         //Imm involved
                case (funct3)
                `F3_ADDI: 
                    id_ex_alu_ctrl <= `ALU_ADD;
                `F3_XORI:
                    id_ex_alu_ctrl <= `ALU_XOR;
                `F3_ORI:
                    id_ex_alu_ctrl <= `ALU_OR;
                `F3_ANDI:
                    id_ex_alu_ctrl <= `ALU_AND;
                `F3_SLLI:
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_SLL : id_ex_alu_ctrl;
                `F3_SRLI_SRAI:begin
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_A) ? `ALU_SRL : id_ex_alu_ctrl;
                    id_ex_alu_ctrl <= (funct7 == `F7_INST_B) ? `ALU_SRA : id_ex_alu_ctrl;
                end
                `F3_SLTI:
                    id_ex_alu_ctrl <= `ALU_SLT;
                `F3_SLTIU:
                    id_ex_alu_ctrl <= `ALU_SLTU;
                default: ;
                endcase
            end

            //Type IL
            `INST_TYPE_IL: begin        //Load
                id_ex_alu_ctrl <= `ALU_ADD;
            end

            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_alu_ctrl <= `ALU_ADD;
            end

            //Type B
            `INST_TYPE_B: begin         //Branch
 /*               case (funct3)
                `F3_BEQ:
                    id_ex_alu_ctrl <= `ALU_BEQ;
                `F3_BNE:
                    id_ex_alu_ctrl <= `ALU_SUB;
                `F3_BLT:
                    id_ex_alu_ctrl <= `ALU_SLT;
                `F3_BGE:
                    id_ex_alu_ctrl <= `ALU_BGE;
                `F3_BLTU:
                    id_ex_alu_ctrl <= `ALU_SLTU;
                `F3_BGEU:
                    id_ex_alu_ctrl <= `ALU_BGEU;
                default: ;
                endcase*/
                id_ex_alu_ctrl <= `ALU_ADD;
                end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_alu_ctrl    <= `ALU_ADD;
            end

            //Type J(JALR)
            `INST_JALR: begin           //Jump and Link reg
                id_ex_alu_ctrl    <= `ALU_JALR;
            end

            //Type U(LUI)
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_alu_ctrl    <= `ALU_ADD;
            end

            //Type U(AUIPC)
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_alu_ctrl    <= `ALU_ADD;
            end

            default: ;

        endcase

    end

end

//id_ex_op1
always @(posedge clk) begin
    if(rst) 
        id_ex_op1 <= `ALU_SRC_REG;      //Select RS1
    else if(ex_glb_flush)               //Flush pipeline
        id_ex_op1 <= `ALU_SRC_REG;
    else begin
        case(opcode)
            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_op1    <= `ALU_SRC_PC;
            end

            //Type J(JALR)
            `INST_JALR: begin           //Jump and Link reg
                id_ex_op1    <= `ALU_SRC_PC;
            end

            //Type U(LUI)
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_op1   <= `ALU_SRC_0;
            end

            //Type U(AUIPC)
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_op1    <= `ALU_SRC_PC;
            end
        endcase
    end
end

//id_ex_op2
always @(posedge clk) begin
    if(rst) 
        id_ex_op2 <= `ALU_SRC_REG;      //Select RS2
    else if(ex_glb_flush)               //Flush pipeline
        id_ex_op2 <= `ALU_SRC_REG;
    else begin
        case(opcode)
            //Type I
            `INST_TYPE_I: begin         //Imm involved
                case (funct3)
                `F3_SLLI,`F3_SRLI_SRAI: 
                    id_ex_op2 <= `ALU_SRC_IMM_5;
                default: 
                    id_ex_op2 <= `ALU_SRC_IMM;
                endcase
            end

            //Type IL
            `INST_TYPE_IL: begin        //load IMM_NUMBER
                id_ex_op2 <= `ALU_SRC_IMM;         
            end
            
            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_op2 <= `ALU_SRC_IMM;         
            end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_op2    <= `ALU_SRC_4;
            end

            //Type J(JALR)
            `INST_JALR: begin           //Jump and Link reg
                id_ex_op2    <= `ALU_SRC_4;
            end

            //Type U(LUI)
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_op2   <= `ALU_SRC_IMM_12;
            end

            //Type U(AUIPC)
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_op2   <= `ALU_SRC_IMM_12;
            end
        endcase
    end
end

//id_ex_imm
always @(posedge clk) begin
    if(rst) 
        id_ex_imm <= `XLEN'b0;
    else if(ex_glb_flush)
        id_ex_imm <= `XLEN'b0;
    else 
        id_ex_imm <= imm;
end

//id_ex_rs1_data
always @(*) begin
    if(rst) 
        id_ex_rs1_data = `XLEN'b0;
    else if(ex_glb_flush)
        id_ex_rs1_data = `XLEN'b0;
    else 
        id_ex_rs1_data = rf_id_rs1_data;
end

//id_ex_rs2_data
always @(*) begin
    if(rst) 
        id_ex_rs2_data = `XLEN'b0;
    else if(ex_glb_flush)
        id_ex_rs2_data = `XLEN'b0;
    else 
        id_ex_rs2_data = rf_id_rs2_data;
end

//id_ex_rd
always @(posedge clk) begin
    if(rst) 
        id_ex_rd <= 5'b0;
    else if(ex_glb_flush)
        id_ex_rd <= 5'b0;
    else 
        id_ex_rd <= rd;
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

//id_ex_is_brch
always @(posedge clk) begin
    if(rst) 
        id_ex_is_brch <= 1'b0;
    else if(ex_glb_flush)
        id_ex_is_brch <= 1'b0;
    else begin
        case (opcode)
            //Type R
            `INST_TYPE_R: begin         //reg
                id_ex_is_brch   <= 1'b0;
            end

            //Type I
            `INST_TYPE_I: begin         //Imm involved
                id_ex_is_brch   <= 1'b0;
            end

            //Type IL
            `INST_TYPE_IL: begin        //Load
                id_ex_is_brch   <= 1'b0;
            end

            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_is_brch   <= 1'b0;
            end

            //Type B
            `INST_TYPE_B: begin         //Branch
                id_ex_is_brch   <= 1'b1;
            end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_is_brch   <= 1'b0;
            end

            //Type J(JALR)
            `INST_JALR: begin           //Jump and Link reg
                id_ex_is_brch   <= 1'b0;
            end

            //Type U(LUI)
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_is_brch   <= 1'b0;
            end

            //Type U(AUIPC)
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_is_brch   <= 1'b0;
            end
        endcase
    end
end

//id_ex_is_jump
always @(posedge clk) begin
    if(rst) 
        id_ex_is_jump <= 1'b0;
    else if(ex_glb_flush)
        id_ex_is_jump <= 1'b0;
    else begin
        case (opcode)
            //Type R
            `INST_TYPE_R: begin         //reg
                id_ex_is_jump   <= 1'b0;
            end

            //Type I
            `INST_TYPE_I: begin         //Imm involved
                id_ex_is_jump   <= 1'b0;
            end

            //Type IL
            `INST_TYPE_IL: begin        //Load
                id_ex_is_jump   <= 1'b0;
            end

            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_is_jump   <= 1'b0;
            end

            //Type B
            `INST_TYPE_B: begin         //Branch
                id_ex_is_jump   <= 1'b0;
            end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_is_jump   <= 1'b1;
            end

            //Type J(JALR)
            `INST_JALR: begin           //Jump and Link reg
                id_ex_is_jump   <= 1'b1;
            end

            //Type U(LUI)
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_is_jump   <= 1'b0;
            end

            //Type U(AUIPC)
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_is_jump   <= 1'b0;
            end
        endcase
    end
end

//id_ex_J_cond
always @(posedge clk) begin
    if(rst) 
        id_ex_J_cond <= `J_UNCOND;
    else if(ex_glb_flush)
        id_ex_J_cond <= `J_UNCOND;
    else begin
        case (opcode)
            //Type R
            `INST_TYPE_R: begin         //reg
                id_ex_J_cond   <= `J_UNCOND;
            end

            //Type I
            `INST_TYPE_I: begin         //Imm involved
                id_ex_J_cond   <= `J_UNCOND;
            end

            //Type IL
            `INST_TYPE_IL: begin        //Load
                id_ex_J_cond   <= `J_UNCOND;
            end

            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_J_cond   <= `J_UNCOND;
            end

            //Type B
            `INST_TYPE_B: begin         //Branch
                case(funct3)
                    `F3_BEQ: begin
                        id_ex_J_cond <= `J_BEQ;
                    end
                    
                    `F3_BNE: begin
                        id_ex_J_cond <= `J_BNE;
                    end

                    `F3_BLT: begin
                        id_ex_J_cond <= `J_BLT;
                    end

                    `F3_BGE: begin
                        id_ex_J_cond <= `J_BGE;
                    end

                    `F3_BLTU: begin 
                        id_ex_J_cond <= `J_BLT_U;
                    end 

                    `F3_BGEU: begin
                        id_ex_J_cond <= `J_BGE_U;
                    end 
                endcase
            end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_J_cond   <= `J_UNCOND;
            end

            //Type J(JALR)
            `INST_JALR: begin           //Jump and Link reg
                id_ex_J_cond   <= `J_UNCOND;
            end

            //Type U(LUI)
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_J_cond   <= `J_UNCOND;
            end

            //Type U(AUIPC)
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_J_cond   <= `J_UNCOND;
            end
        endcase
    end
end

//id_ex_dm_re
always @(posedge clk) begin
    if(rst) 
        id_ex_dm_re <= 1'b0;
    else if(ex_glb_flush)
        id_ex_dm_re <= 1'b0;
    else begin
        case (opcode)
            //Type R
            `INST_TYPE_R: begin         //reg
                id_ex_dm_re   <= 1'b0;
            end

            //Type I
            `INST_TYPE_I: begin         //Imm involved
                id_ex_dm_re   <= 1'b0;
            end

            //Type IL
            `INST_TYPE_IL: begin        //Load
                id_ex_dm_re   <= 1'b1;
            end

            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_dm_re   <= 1'b0;
            end

            //Type B
            `INST_TYPE_B: begin         //Branch
                id_ex_dm_re   <= 1'b0;
            end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_dm_re   <= 1'b0;
            end

            //Type J(JALR)
            `INST_JALR: begin           //Jump and Link reg
                id_ex_dm_re   <= 1'b0;
            end

            //Type U(LUI)
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_dm_re   <= 1'b0;
            end

            //Type U(AUIPC)
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_dm_re   <= 1'b0;
            end
        endcase
    end
end

//id_ex_dm_we
always @(posedge clk) begin
    if(rst) 
        id_ex_dm_we <= 1'b0;
    else if(ex_glb_flush)
        id_ex_dm_we <= 1'b0;
    else begin
        case (opcode)
            //Type R
            `INST_TYPE_R: begin         //reg
                id_ex_dm_we   <= 1'b0;
            end

            //Type I
            `INST_TYPE_I: begin         //Imm involved
                id_ex_dm_we   <= 1'b0;
            end

            //Type IL
            `INST_TYPE_IL: begin        //Load
                id_ex_dm_we   <= 1'b0;
            end

            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_dm_we   <= 1'b1;
            end

            //Type B
            `INST_TYPE_B: begin         //Branch
                id_ex_dm_we   <= 1'b0;
            end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_dm_we   <= 1'b0;
            end

            //Type J(JALR)              
            `INST_JALR: begin           //Jump and Link reg
                id_ex_dm_we   <= 1'b0;
            end

            //Type U(LUI)               
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_dm_we   <= 1'b0;
            end

            //Type U(AUIPC)         
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_dm_we   <= 1'b0;
            end
        endcase
    end
end

//id_ex_rf_we
always @(posedge clk) begin
    if(rst) 
        id_ex_rf_we <= 1'b0;
    else if(ex_glb_flush)
        id_ex_rf_we <= 1'b0;
    else begin
        case (opcode)
            //Type R
            `INST_TYPE_R: begin         //reg
                id_ex_rf_we   <= 1'b1;
            end

            //Type I
            `INST_TYPE_I: begin         //Imm involved
                id_ex_rf_we   <= 1'b1;
            end

            //Type IL
            `INST_TYPE_IL: begin        //Load
                id_ex_rf_we   <= 1'b1;
            end

            //Type S
            `INST_TYPE_S: begin         //Store
                id_ex_rf_we   <= 1'b0;
            end

            //Type B
            `INST_TYPE_B: begin         //Branch
                id_ex_rf_we   <= 1'b0;
            end

            //Type J(JAL)
            `INST_JAL: begin            //Jump and Link
                id_ex_rf_we   <= 1'b1;
            end

            //Type J(JALR)              
            `INST_JALR: begin           //Jump and Link reg
                id_ex_rf_we   <= 1'b1;
            end

            //Type U(LUI)               
            `INST_LUI: begin            //Load Upper Immediate
                id_ex_rf_we   <= 1'b1;
            end

            //Type U(AUIPC)         
            `INST_AUIPC: begin          //Add Upper Immediate to PC
                id_ex_rf_we   <= 1'b1;
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

//id_rf_rs1_addr
always @(posedge clk) begin
    if(rst) 
        id_rf_rs1_addr <= 5'b0;
    else if(ex_glb_flush)
        id_rf_rs1_addr <= 5'b0;
    else 
        id_rf_rs1_addr <= rs1;
end

//id_rf_rs2_addr
always @(posedge clk) begin
    if(rst) 
        id_rf_rs2_addr <= 5'b0;
    else if(ex_glb_flush)
        id_rf_rs2_addr <= 5'b0;
    else 
        id_rf_rs2_addr <= rs2;
end

//***********************************************************//
//                                                           //
//                 Global stall generation                   //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//

// RAW harzard
wire raw_hazard_rs1 = (ex_mem_rf_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs1));
wire raw_hazard_rs2 = (ex_mem_rf_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs2));
wire raw_hazard = raw_hazard_rs1 || raw_hazard_rs2;

//id_glb_stall
always @(*) begin
    id_glb_stall = raw_hazard;          
end

endmodule
