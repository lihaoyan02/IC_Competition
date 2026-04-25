`define XLEN 32
`define NREGS 32

//********IDU********
// opcode
`define OPCODE_WIDTH 7

`define INST_TYPE_R    `OPCODE_WIDTH'b0110011 // add/sub/xor/or/and/sll/srl/sra/slt/sltu
`define INST_TYPE_I    `OPCODE_WIDTH'b0010011 // addi/xori/ori/andi/slli/srli/srai/slti/sltiu
`define INST_TYPE_IL   `OPCODE_WIDTH'b0000011 // lb/lh/lw/lbu/lhu
`define INST_TYPE_S    `OPCODE_WIDTH'b0100011 // sb/sh/sw
`define INST_TYPE_B    `OPCODE_WIDTH'b1100011 // beq/bne/blt/bge/bltu/bgeu
`define INST_JAL       `OPCODE_WIDTH'b1101111 // jal
`define INST_JALR      `OPCODE_WIDTH'b1100111 // jalr
`define INST_LUI       `OPCODE_WIDTH'b0110111 // lui
`define INST_AUIPC     `OPCODE_WIDTH'b0010111 // auipc
`define INST_MISC_MEM  `OPCODE_WIDTH'b0001111 // fence
`define INST_SYSTEM    `OPCODE_WIDTH'b1110011 // ecall/ebreak/(csr related encoding space)

// funct3

`define FUNCT3_WIDTH 3

// R-type
`define F3_ADD_SUB   `FUNCT3_WIDTH'h0 
`define F3_XOR       `FUNCT3_WIDTH'h4
`define F3_OR        `FUNCT3_WIDTH'h6
`define F3_AND       `FUNCT3_WIDTH'h7
`define F3_SLL       `FUNCT3_WIDTH'h1
`define F3_SRL_SRA   `FUNCT3_WIDTH'h5
`define F3_SLT       `FUNCT3_WIDTH'h2
`define F3_SLTU      `FUNCT3_WIDTH'h3
// I-type 
`define F3_ADDI      `FUNCT3_WIDTH'h0
`define F3_XORI      `FUNCT3_WIDTH'h4
`define F3_ORI       `FUNCT3_WIDTH'h6
`define F3_ANDI      `FUNCT3_WIDTH'h7
`define F3_SLLI      `FUNCT3_WIDTH'h1
`define F3_SRLI_SRAI `FUNCT3_WIDTH'h5 
`define F3_SLTI      `FUNCT3_WIDTH'h2
`define F3_SLTIU     `FUNCT3_WIDTH'h3
// I-type load
`define F3_LB        `FUNCT3_WIDTH'h0
`define F3_LH        `FUNCT3_WIDTH'h1
`define F3_LW        `FUNCT3_WIDTH'h2
`define F3_LBU       `FUNCT3_WIDTH'h4
`define F3_LHU       `FUNCT3_WIDTH'h5
// S-type
`define F3_SB        `FUNCT3_WIDTH'h0
`define F3_SH        `FUNCT3_WIDTH'h1
`define F3_SW        `FUNCT3_WIDTH'h2
// B-type
`define F3_BEQ       `FUNCT3_WIDTH'h0
`define F3_BNE       `FUNCT3_WIDTH'h1
`define F3_BLT       `FUNCT3_WIDTH'h4
`define F3_BGE       `FUNCT3_WIDTH'h5
`define F3_BLTU      `FUNCT3_WIDTH'h6
`define F3_BGEU      `FUNCT3_WIDTH'h7
// I-type environment
`define F3_ECALL     `FUNCT3_WIDTH'h0
`define F3_EBREAK    `FUNCT3_WIDTH'h0

//Branch Control
`define J_UNCOND 3'b000
`define J_BEQ 3'b001
`define J_BNE 3'b010
`define J_BGE 3'b011
`define J_BGE_U 3'b100
`define J_BLT_U 3'b101
`define J_BLT 3'b110


// funct7

`define FUNCT7_WIDTH 7
`define F7_INST_A  `FUNCT7_WIDTH'h00
`define F7_INST_B  `FUNCT7_WIDTH'h20


// ALU opcode

`define ALU_OP_WIDTH 4
`define ALU_AND  `ALU_OP_WIDTH'b0000
`define ALU_OR   `ALU_OP_WIDTH'b0001
`define ALU_XOR  `ALU_OP_WIDTH'b0010
`define ALU_ADD  `ALU_OP_WIDTH'b0011
`define ALU_SUB  `ALU_OP_WIDTH'b0100
`define ALU_SLL  `ALU_OP_WIDTH'b0101 // shift left logical
`define ALU_SRL  `ALU_OP_WIDTH'b0110 // shift right logical
`define ALU_SRA  `ALU_OP_WIDTH'b0111 // shift right arith 
`define ALU_SLT  `ALU_OP_WIDTH'b1000 // set less than  
`define ALU_SLTU `ALU_OP_WIDTH'b1001 // set less than (unsigned) 
`define ALU_BEQ  `ALU_OP_WIDTH'b1010 // branch equal
`define ALU_BGE  `ALU_OP_WIDTH'b1011 // branch more or equal than
`define ALU_BGEU `ALU_OP_WIDTH'b1100 // branch more or equal than (unsigned)
`define ALU_JALR `ALU_OP_WIDTH'b1101 // PC = rs1 + imm

// ALU select soure

`define ALU_SRC_WIDTH 3
`define ALU_SRC_REG     `ALU_SRC_WIDTH'b000 // reg
`define ALU_SRC_IMM     `ALU_SRC_WIDTH'b001 // imm
`define ALU_SRC_IMM_5   `ALU_SRC_WIDTH'b010 // imm[4:0]
`define ALU_SRC_IMM_12  `ALU_SRC_WIDTH'b011 // imm << 12
`define ALU_SRC_PC      `ALU_SRC_WIDTH'b100 // PC
`define ALU_SRC_4       `ALU_SRC_WIDTH'b101 // 4
`define ALU_SRC_0       `ALU_SRC_WIDTH'b110 // 0

