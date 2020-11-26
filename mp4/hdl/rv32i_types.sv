package rv32i_types;
// Mux types are in their own packages to prevent identiier collisions
// e.g. pcmux::pc_plus4 and wbdatamux::pc_plus4 are seperate identifiers
// for seperate enumerated types
import pcmux::*;
import cmpmux::*;
import alumux::*;
import wbdatamux::*;

typedef logic [31:0] rv32i_word;
typedef logic [4:0] rv32i_reg;
typedef logic [3:0] rv32i_mem_wmask;

typedef enum bit [6:0] {
    op_lui   = 7'b0110111, //load upper immediate (U type)
    op_auipc = 7'b0010111, //add upper immediate PC (U type)
    op_jal   = 7'b1101111, //jump and link (J type)
    op_jalr  = 7'b1100111, //jump and link register (I type)
    op_br    = 7'b1100011, //branch (B type)
    op_load  = 7'b0000011, //load (I type)
    op_store = 7'b0100011, //store (S type)
    op_imm   = 7'b0010011, //arith ops with register/immediate operands (I type)
    op_reg   = 7'b0110011, //arith ops with register operands (R type)
    op_csr   = 7'b1110011, //control and status register (I type)
    op_none  = 7'b0000000
} rv32i_opcode;

typedef enum bit [2:0] {
    beq  = 3'b000,
    bne  = 3'b001,
    blt  = 3'b100,
    bge  = 3'b101,
    bltu = 3'b110,
    bgeu = 3'b111
} branch_funct3_t;

typedef enum bit [2:0] {
    lb  = 3'b000,
    lh  = 3'b001,
    lw  = 3'b010,
    lbu = 3'b100,
    lhu = 3'b101
} load_funct3_t;

typedef enum bit [2:0] {
    sb = 3'b000,
    sh = 3'b001,
    sw = 3'b010
} store_funct3_t;

typedef enum bit [2:0] {
    add  = 3'b000, //check bit30 for sub if op_reg opcode
    sll  = 3'b001,
    slt  = 3'b010,
    sltu = 3'b011,
    axor = 3'b100,
    sr   = 3'b101, //check bit30 for logical/arithmetic
    aor  = 3'b110,
    aand = 3'b111
} arith_funct3_t;

typedef enum bit [2:0] {
    alu_add = 3'b000,
    alu_sll = 3'b001,
    alu_sra = 3'b010,
    alu_sub = 3'b011,
    alu_xor = 3'b100,
    alu_srl = 3'b101,
    alu_or  = 3'b110,
    alu_and = 3'b111
} alu_ops;

// ================================ MP4 ================================

typedef struct packed {

    // ================ Common ================

    rv32i_opcode opcode;

    // ================ Datapath ================

    // MUX and function selections
    alumux::alumux1_sel_t alumux1_sel;
    alumux::alumux2_sel_t alumux2_sel;
    wbdatamux::wbdatamux_sel_t wbdatamux_sel;
    cmpmux::cmpmux1_sel_t cmpmux1_sel;
    cmpmux::cmpmux2_sel_t cmpmux2_sel;
    mwdrmux::mwdrmux_sel_t mwdrmux_sel;
    logic use_cmp;
    logic use_cmp_output;
    alu_ops aluop;
    branch_funct3_t cmpop;

    // For BR/JAL/JALR instruction in EX stage
    pcmux::pcmux_sel_t pcmux_sel;

    // MEM stage control signals
    logic d_read;
    logic d_write;
    logic [3:0] d_byte_enable;

    // WB stage control signals
    logic regfile_wb;
    logic rs1_read;
    logic rs2_read;

} rv32i_control_word;

typedef struct packed {
    rv32i_reg rs1;
    rv32i_reg rs2;
    rv32i_reg rd;
} rv32i_reg_pack;

endpackage : rv32i_types
