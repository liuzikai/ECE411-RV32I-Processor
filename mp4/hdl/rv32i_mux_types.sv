package pcmux;
typedef enum bit [1:0] {
    pc_plus4 = 2'b00
    ,br = 2'b01
    ,alu_out  = 2'b10
    ,alu_mod2 = 2'b11
} pcmux_sel_t;
endpackage

package cmpmux;
typedef enum bit {
    rs2_out = 1'b0
    ,i_imm = 1'b1
} cmpmux_sel_t;
endpackage

package alumux;
typedef enum bit [2:0] {
    rs1_out = 3'b000
    ,pc_out = 3'b001
    ,alumux1_alumux_out = 3'b010
    ,alumux1_regfilemux_out = 3'b011
    ,alumux1_regfile_imm_out = 3'b100
} alumux1_sel_t;

typedef enum bit [3:0] {
    i_imm    = 4'b0000
    ,u_imm   = 4'b0001
    ,b_imm   = 4'b0010
    ,s_imm   = 4'b0011
    ,j_imm   = 4'b0100
    ,rs2_out = 4'b0101
    ,alumux2_alumux_out = 4'b0110
    ,alumux2_regfilemux_out = 4'b0111
    ,alumux2_regfile_imm_out = 4'b1000
} alumux2_sel_t;
endpackage

package regfilemux;
typedef enum bit [3:0] {
    alu_out   = 4'b0000
    ,br_en    = 4'b0001
    ,u_imm    = 4'b0010
    ,lw       = 4'b0011
    ,pc_plus4 = 4'b0100
    ,lb        = 4'b0101
    ,lbu       = 4'b0110  // unsigned byte
    ,lh        = 4'b0111
    ,lhu       = 4'b1000  // unsigned halfword
} regfilemux_sel_t;
endpackage
