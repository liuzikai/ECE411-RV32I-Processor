package pcmux;
typedef enum bit [1:0] {
    pc_plus4 = 2'b00
    ,br = 2'b01
    ,alu_out  = 2'b10
    ,alu_mod2 = 2'b11
} pcmux_sel_t;
endpackage

package cmpmux;
typedef enum bit [2:0] {
    rs1_out = 3'b000
    ,cmpmux1_alu_out = 3'b001
    ,cmpmux1_cmp_out = 3'b010
    ,cmpmux1_wbdatamux_out = 3'b011
    ,cmpmux1_wbdata_out = 3'b100
} cmpmux1_sel_t;

typedef enum bit [2:0] {
    rs2_out = 3'b000
    ,i_imm = 3'b001
    ,cmpmux2_alu_out = 3'b010
    ,cmpmux2_cmp_out = 3'b011
    ,cmpmux2_wbdatamux_out = 3'b100
    ,cmpmux2_wbdata_out = 3'b101
} cmpmux2_sel_t;
endpackage

package alumux;
typedef enum bit [2:0] {
    rs1_out = 3'b000
    ,pc_out = 3'b001
    ,alumux1_alu_out = 3'b010
    ,alumux1_cmp_out = 3'b011
    ,alumux1_wbdatamux_out = 3'b100
    ,alumux1_wbdata_out = 3'b101
    ,zero = 3'b110
} alumux1_sel_t;

typedef enum bit [3:0] {
    i_imm    = 4'b0000
    ,u_imm   = 4'b0001
    ,b_imm   = 4'b0010
    ,s_imm   = 4'b0011
    ,j_imm   = 4'b0100
    ,rs2_out = 4'b0101
    ,alumux2_alu_out = 4'b0110
    ,alumux2_cmp_out = 4'b0111
    ,alumux2_wbdatamux_out = 4'b1000
    ,alumux2_wbdata_out = 4'b1001
} alumux2_sel_t;
endpackage

package mwdrmux;
typedef enum bit [2:0] {
    rs2_out = 3'b000
    ,mwdrmux_alu_out = 3'b001
    ,mwdrmux_cmp_out = 3'b010
    ,mwdrmux_wbdatamux_out = 3'b011
    ,mwdrmux_wbdata_out = 3'b100
} mwdrmux_sel_t;
endpackage

package wbdatamux;
typedef enum bit [3:0] {
    alu_out    = 4'b0000
    ,br_en     = 4'b0001
    ,u_imm     = 4'b0010
    ,lw        = 4'b0011
    ,pc_plus4  = 4'b0100
    ,lb        = 4'b0101
    ,lbu       = 4'b0110  // unsigned byte
    ,lh        = 4'b0111
    ,lhu       = 4'b1000  // unsigned halfword
} wbdatamux_sel_t;
endpackage

package rsmux;
typedef enum bit[2:0] { 
    regfile_out = 3'b000     // no forwarding
    ,alu_out = 3'b001        // 1 stage forwarding
    ,cmp_out = 3'b010        // 1 stage forwarding
    ,wbdatamux_out = 3'b011  // 2 stage forwarding
    ,wbdata_out = 3'b100     // 3 stage forwarding
} rsmux_sel_t;
endpackage
