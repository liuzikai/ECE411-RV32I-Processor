package expcmux;
typedef enum bit [1:0] {
    none = 2'b00
    ,br = 2'b01
    ,alu_out  = 2'b10
    ,alu_mod2 = 2'b11
} expcmux_sel_t;
endpackage

package cmpmux;
typedef enum bit {
    rs2_out = 1'b0
    ,i_imm  = 1'b1
} cmpmux2_sel_t;
endpackage

package alumux;
typedef enum bit {
    rs1_out = 1'b0
    ,pc_out = 1'b1
} alumux1_sel_t;

typedef enum bit [2:0] {
    i_imm    = 3'b000
    ,u_imm   = 3'b001
    ,b_imm   = 3'b010
    ,s_imm   = 3'b011
    ,j_imm   = 3'b100
    ,rs2_out = 3'b101
} alumux2_sel_t;
endpackage

package wbdatamux;
typedef enum bit [3:0] {

    // The following four have wbdatamux_sel[3] == 1'b0
    alu_out    = 4'b0000
    ,br_en     = 4'b0001
    ,u_imm     = 4'b0010
    ,pc_plus4  = 4'b0011

    // The following five equals to {1'b1, load_funct3_t}
    ,lb        = 4'b1000
    ,lh        = 4'b1001
    ,lw        = 4'b1010
    ,lbu       = 4'b1100  // unsigned byte
    ,lhu       = 4'b1101  // unsigned halfword

} wbdatamux_sel_t;
endpackage

package rsmux;
typedef enum bit [2:0] { 
    regfile_out    = 3'b100  // no forwarding

    // The following four equals to wbdatamux_sel[2:0]
    ,alu_out       = 3'b000  // 1 stage forwarding
    ,cmp_out       = 3'b001  // 1 stage forwarding
    ,u_imm_ex      = 3'b010  // 1 stage forwarding
    ,pc_ex_plus4   = 3'b011  // 1 stage forwarding

    ,wbdatamux_out = 3'b101  // 2 stage forwarding, already considered wbdatamux_sel
    ,wbdata_out    = 3'b110  // 3 stage forwarding, already considered wbdatamux_sel
} rsmux_sel_t;
endpackage
