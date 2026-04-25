`include "macro.v"

module EXU (
    input clk,
    input rst,

    //Singnals to/from IFU
    output reg             ex_if_bpc_vld,  //Banching valid
    output reg [`XLEN-1:0] ex_if_bpc,      //Branching new PC

    // Singnals to/from IDU
    output           ex_id_ready,
    output reg       ex_glb_flush,  //Flush pipe line
    output           ex_mem_rf_we,  //To detecet RAW
    output     [4:0] ex_mem_rd,     //To detecet RAW

    input             id_ex_valid,     //High Active
    input [      3:0] id_ex_alu_ctrl,  //Modified here original [2:0]
    input [      2:0] id_ex_op1,
    input [      2:0] id_ex_op2,
    input [`XLEN-1:0] id_ex_imm,
    input [`XLEN-1:0] id_ex_rs1_data,
    input [`XLEN-1:0] id_ex_rs2_data,
    input [`XLEN-1:0] id_ex_pc,
    input [      4:0] id_ex_rd,
    input             id_ex_is_brch,
    input             id_ex_is_jump,
    input [      2:0] id_ex_J_cond,
    input             id_ex_dm_re,
    input             id_ex_dm_we,
    input             id_ex_rf_we,

    // Singnals to/from LSU (Load Store Unit)
    output reg             ex_lsu_valid,
    input                  lsu_ex_ready,
    output reg [      1:0] ex_lsu_ctrl,   // 00: no action, 01: read, 10: write
    output reg [      1:0] ex_lsu_size,   // 00: byte, 01: half-word, 10: word
    output reg [`XLEN-1:0] ex_lsu_addr,
    output reg [`XLEN-1:0] ex_lsu_data
);
    
// 
reg [`XLEN-1:0] alu_in1;    // ALU input1
reg [`XLEN-1:0] alu_in2;    // ALU input2
reg [`XLEN-1:0] alu_result; 
reg brch_taken;             // Branch selected

//alu_in1
always @(*) begin
    alu_in1 = `XLEN'd0;
    case (id_ex_op1)
        `ALU_SRC_REG    :   alu_in1 = id_ex_rs1_data;       //Take data in rs1
        `ALU_SRC_IMM    :   alu_in1 = id_ex_imm;            //Take imm
        `ALU_SRC_IMM_5  :   alu_in1 = id_ex_imm[4:0];       //Take imm[4:0]
        `ALU_SRC_IMM_12 :   alu_in1 = id_ex_imm << 12;      //Take imm<<12
        `ALU_SRC_PC     :   alu_in1 = id_ex_pc;             //Take current PC
        `ALU_SRC_4      :   alu_in1 = `XLEN'd4;             //Take constant 4
        `ALU_SRC_0      :   alu_in1 = `XLEN'b0;             //Take constant 0
        default         :   alu_in1 = id_ex_rs1_data;       
    endcase
end

//alu_in2
always @(*) begin
    alu_in2 = `XLEN'd0;
    case (id_ex_op2)
        `ALU_SRC_REG    :   alu_in2 = id_ex_rs2_data;       //Take data in rs2
        `ALU_SRC_IMM    :   alu_in2 = id_ex_imm;            //Take imm
        `ALU_SRC_IMM_5  :   alu_in2 = id_ex_imm[4:0];       //Take imm[4:0]
        `ALU_SRC_IMM_12 :   alu_in2 = id_ex_imm << 12;      //Take imm<<12
        `ALU_SRC_PC     :   alu_in2 = id_ex_pc;             //Take current PC
        `ALU_SRC_4      :   alu_in2 = `XLEN'd4;             //Take constant 4
        `ALU_SRC_0      :   alu_in2 = `XLEN'b0;             //Take constant 0
        default         :   alu_in2 = id_ex_rs2_data;       
    endcase
end   

//***********************************************************//
//                                                           //
//                       alu_function                        //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//

always @(*) begin
    alu_result = {`XLEN{1'b0}};
    case (id_ex_alu_ctrl)
        `ALU_AND  : alu_result = alu_in1 & alu_in2;
        `ALU_OR   : alu_result = alu_in1 | alu_in2;
        `ALU_XOR  : alu_result = alu_in1 ^ alu_in2;
        `ALU_ADD  : alu_result = alu_in1 + alu_in2;
        `ALU_SUB  : alu_result = alu_in1 - alu_in2;

        // Shift
        `ALU_SLL  : alu_result = alu_in1 << alu_in2[4:0];
        `ALU_SRL  : alu_result = alu_in1 >> alu_in2[4:0];
        `ALU_SRA  : alu_result = $signed(alu_in1) >>> alu_in2[4:0];

        // Set less than
        `ALU_SLT  : alu_result = {{(`XLEN-1){1'b0}}, ($signed(alu_in1) <  $signed(alu_in2))};
        `ALU_SLTU : alu_result = {{(`XLEN-1){1'b0}}, (alu_in1 < alu_in2)};

        default   : alu_result = {`XLEN{1'b0}};
    endcase
end

//***********************************************************//
//                                                           //
//                       Branching                           //
//                        To IFU                             //
//                                                           //
//                                                           //
//***********************************************************//

//Generate brchtaken
always @(*) begin
    brch_taken = 1'b0;

    if (id_ex_is_brch) begin
        case (id_ex_J_cond)
            `J_BEQ   : brch_taken = (id_ex_rs1_data == id_ex_rs2_data);
            `J_BNE   : brch_taken = (id_ex_rs1_data != id_ex_rs2_data);
            `J_BLT   : brch_taken = ($signed(id_ex_rs1_data) <  $signed(id_ex_rs2_data));
            `J_BGE   : brch_taken = ($signed(id_ex_rs1_data) >= $signed(id_ex_rs2_data));
            `J_BLT_U : brch_taken = (id_ex_rs1_data <  id_ex_rs2_data);
            `J_BGE_U : brch_taken = (id_ex_rs1_data >= id_ex_rs2_data);
            default  : brch_taken = 1'b0;
        endcase
    end
end

//Calculate target address and branching_valid
always @(posedge clk) begin
    if (rst) begin
        ex_if_bpc <= `XLEN'b0;
        ex_if_bpc_vld <= 1'b0;
        ex_glb_flush <= 1'b0;
    end
    else if (id_ex_is_brch & brch_taken) begin                    //Branch taken：nextPC = PC + IMM 
        ex_if_bpc <= id_ex_pc + id_ex_imm;
        ex_if_bpc_vld <= 1'b1;
        ex_glb_flush <= 1'b1;
    end
    else if (id_ex_is_jump & id_ex_J_cond == `J_UNCOND) begin        
        if (id_ex_op1 == `ALU_SRC_PC) begin
                ex_if_bpc_vld <= 1'b1;
                ex_if_bpc = id_ex_pc + id_ex_imm;           // JAL：nextPC = PC + IMM 
                ex_glb_flush <= 1'b1;
            end
            else begin
                ex_if_bpc_vld <= 1'b1;
                ex_if_bpc = (id_ex_rs1_data + id_ex_imm) & {{(`XLEN-1){1'b1}}, 1'b0};  // JALR：nextPC = rs1 + IMM
                ex_glb_flush <= 1'b1;
            end
    end
    else begin
        ex_if_bpc <= `XLEN'b0;
        ex_if_bpc_vld <= 1'b0;
        ex_glb_flush <= 1'b0;
    end
end

/*//Banch valid
always @(posedge clk) begin
    if (rst)
        ex_if_bpc <= `XLEN'b0;
    else if (id_ex_is_brch && brch_taken) begin
        // 分支指令条件成立：PC + 立即数偏移
        ex_if_bpc_vld <= 1'b1;
        ex_if_bpc <= id_ex_pc + id_ex_imm;
        ex_glb_flush <= 1'b1;
    end 
    else if (id_ex_is_jump && id_ex_alu_op == `ALU_ADD) begin
        // JAL指令：PC + 立即数偏移
        ex_if_bpc_vld <= 1'b1;
        ex_if_bpc <= id_ex_pc + id_ex_imm;
        ex_glb_flush <= 1'b1;
    end 
    else if (id_ex_is_jump && id_ex_alu_op == `ALU_JALR) begin
        // JALR指令：rs1 + 立即数（最低位置0）
        ex_if_bpc_vld <= 1'b1;
        ex_if_bpc <= (id_ex_rs1_val + id_ex_imm) & ~1;
        ex_glb_flush <= 1'b1;
    end
    else begin
        ex_if_bpc_vld <= 1'b0;
        ex_if_bpc <= `XLEN'b0;
        ex_glb_flush <= 1'b0;
    end 
end
*/

//ex_id_ready
assign ex_id_ready = !id_ex_valid ? 1'b1 : ((id_ex_dm_re || id_ex_dm_we) ? lsu_ex_ready : 1'b1);

//***********************************************************//
//                                                           //
//                       Singnals to LSU                     //
//                                                           //
//                                                           //
//                                                           //
//***********************************************************//

//ex_lsu_addr


endmodule
