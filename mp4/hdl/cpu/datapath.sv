`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module datapath(
    input clk,
    input rst,

    // Signals to intermediate registers
    input logic stall_ID,
    input logic stall_EX,
    input logic stall_MEM,
    input logic stall_WB,

    input logic [3:0] d_byte_enable,
    input logic d_read,
    input logic d_write,

    // Signals from control words to MUXes
    input alumux::alumux1_sel_t alumux1_sel,
    input alumux::alumux2_sel_t alumux2_sel,
    input regfilemux::regfilemux_sel_t regfilemux_sel,
    input cmpmux::cmpmux1_sel_t cmpmux1_sel,
    input cmpmux::cmpmux2_sel_t cmpmux2_sel,
    input mwdrmux::mwdrmux_sel_t mwdrmux_sel,
    input pcmux::pcmux_sel_t pcmux_sel,

    // Signals to ALU, CMP and regfile
    input alu_ops aluop,
    input branch_funct3_t cmpop,
    input logic regfile_wb,
    input rv32i_reg regfile_rd,

    // Output of CMP
    output logic br_en,

    // Signals to I-Cache
    output rv32i_word i_addr,
    input  rv32i_word i_rdata,

    // Signals to D-Cache
    output rv32i_word d_addr,
    input  rv32i_word d_rdata,
    output rv32i_word d_wdata
);

// ================================ Internal signals ================================

// Output of IR
rv32i_reg rs1, rs2;
rv32i_word i_imm, u_imm, b_imm, s_imm, j_imm;
rv32i_opcode opcode;
logic [2:0] funct3;
logic [6:0] funct7;
rv32i_reg rd_out;

// Output of Regfile
rv32i_word rs1_out, rs2_out;

// Output of ALU
rv32i_word alu_out;

// Output of PC and chained intermediate registers
rv32i_word pc_out, pc_imm1_out;

// Output of intermediate registers
rv32i_word regfile_in, alu_in1, alu_in2, cmp_in1, cmp_in2, alu_wb_imm_out, mwdr_imm_out;
rv32i_word u_imm1_out, u_imm2_out, cmp_wb_imm_out, cmpmux1_out, cmpmux2_out;
rv32i_word alumux1_out, alumux2_out, regfilemux_out, marmux_out, pcmux_out, mwdrmux_out;

assign i_addr = pc_out;

// ================================ Registers ================================

// Keep Instruction register named `IR` for RVFI Monitor
ir IR(
    .clk(clk),
    .rst(rst),
    .load(~stall_ID),
    .in(i_rdata),
    .funct3(funct3),
    .funct7(funct7),
    .opcode(opcode),
    .i_imm(i_imm),
    .u_imm(u_imm),
    .b_imm(b_imm),
    .s_imm(s_imm),
    .j_imm(j_imm),
    .rs1(rs1),   // to regfile
    .rs2(rs2),   // to regfile
    .rd(rd_out)
);

register u_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(u_imm),
    .out(u_imm1_out)
);

register u_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(u_imm1_out),
    .out(u_imm2_out)
);

pc_register PC(
    .clk(clk),
    .rst(rst),
    .load((~stall_ID) || (~stall_EX && (pcmux_sel == pcmux::alu_out || pcmux_sel == pcmux::alu_mod2 || (pcmux_sel == pcmux::br && br_en)))),
    .in(pcmux_out),
    .out(pc_out)
);

register pc_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_ID),
    .in(pc_out),
    .out(pc_imm1_out)
);

register MDAR(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(alu_out),
    .out(d_addr)
);

register MWDR(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(mwdr_imm_out),
    .out(d_wdata)
);

register mwdr_imm(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(mwdrmux_out),
    .out(mwdr_imm_out)
);

register regfile_imm(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(regfilemux_out),
    .out(regfile_in)
);

register alu_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(alumux1_out),
    .out(alu_in1)
);

register alu_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(alumux2_out),
    .out(alu_in2)
);

register alu_wb_imm(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(alu_out),
    .out(alu_wb_imm_out)
);

register cmp_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(cmpmux1_out),
    .out(cmp_in1)
);

register cmp_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(cmpmux2_out),
    .out(cmp_in2)
);

register cmp_wb_imm(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in({31'b0, br_en}),
    .out(cmp_wb_imm_out)
);

// ================================ Regfile, ALU and CMP ================================

regfile regfile(
    .clk(clk),
    .rst(rst),
    .load(regfile_wb && (~stall_WB)),
    .in(regfile_in),
    .src_a(rs1),        // directly from IR
    .src_b(rs2),        // directly from IR
    .dest(regfile_rd),  // from control word
    .reg_a(rs1_out),
    .reg_b(rs2_out)
);

alu alu(
    .aluop(aluop),
    .a(alu_in1),
    .b(alu_in2),
    .f(alu_out)
);

cmp cmp(
    .cmpop(cmpop),
    .a(cmp_in1),  // cmpmux1_out
    .b(cmp_in2),  // cmpmux2_out
    .f(br_en)
);

// ================================ MUXes ================================

always_comb begin : MUXES

    // Using enumerated types rather than bit vectors
    // provides compile time type safety.  Defensive programming is extremely
    // useful in SystemVerilog.  In this case, we actually use
    // Offensive programming --- making simulation halt with a fatal message
    // warning when an unexpected mux select value occurs

    // pcmux
    unique case (pcmux_sel)
        pcmux::pc_plus4: pcmux_out = pc_out + 4;
        pcmux::br:       pcmux_out = (br_en ? alu_out : pc_out + 4);
        pcmux::alu_out:  pcmux_out = alu_out;
        pcmux::alu_mod2: pcmux_out = {alu_out[31:1], 1'b0};
        default: `BAD_MUX_SEL;
    endcase

    // regfilemux
    regfilemux_out = 32'hXXXXXXXX;
    unique case (regfilemux_sel)
        regfilemux::alu_out:  regfilemux_out = alu_wb_imm_out;
        regfilemux::br_en:    regfilemux_out = cmp_wb_imm_out;
        regfilemux::u_imm:    regfilemux_out = u_imm2_out;
        regfilemux::pc_plus4: regfilemux_out = pc_out + 4;
        regfilemux::lw:       regfilemux_out = d_rdata;
        regfilemux::lb:       regfilemux_out = {{24{d_rdata[7]}}, d_rdata[7:0]};
        regfilemux::lbu:      regfilemux_out = {24'b0, d_rdata[7:0]};
        regfilemux::lh:       regfilemux_out = {{16{d_rdata[15]}}, d_rdata[15:0]};
        regfilemux::lhu:      regfilemux_out = {16'b0, d_rdata[15:0]};
        default: `BAD_MUX_SEL;
    endcase

    // alumux1
    unique case (alumux1_sel)
        alumux::rs1_out: alumux1_out = rs1_out;
        alumux::pc_out:  alumux1_out = pc_imm1_out;  // need to get data from PC chain
        alumux::alumux1_alu_out: alumux1_out = alu_out;
        alumux::alumux1_regfilemux_out: alumux1_out = regfilemux_out;
        alumux::alumux1_regfile_imm_out: alumux1_out = regfile_in;
        default: `BAD_MUX_SEL;
    endcase

    // alumux2
    unique case (alumux2_sel)
        alumux::i_imm:   alumux2_out = i_imm;
        alumux::u_imm:   alumux2_out = u_imm;
        alumux::b_imm:   alumux2_out = b_imm;
        alumux::s_imm:   alumux2_out = s_imm;
        alumux::j_imm:   alumux2_out = j_imm;
        alumux::rs2_out: alumux2_out = rs2_out;
        alumux::alumux2_alu_out: alumux2_out = alu_out;
        alumux::alumux2_regfilemux_out: alumux2_out = regfilemux_out;
        alumux::alumux2_regfile_imm_out: alumux2_out = regfile_in;
        default: `BAD_MUX_SEL;
    endcase

    // cmpmux
    unique case (cmpmux1_sel)
        cmpmux::rs1_out:                    cmpmux1_out = rs1_out;
        cmpmux::cmpmux1_alu_out:            cmpmux1_out = alu_out;
        cmpmux::cmpmux1_regfilemux_out:     cmpmux1_out = regfilemux_out;
        cmpmux::cmpmux1_regfile_imm_out:    cmpmux1_out = regfile_in;
        default: `BAD_MUX_SEL;
    endcase

    unique case (cmpmux2_sel)
        cmpmux::rs2_out:                    cmpmux2_out = rs2_out;
        cmpmux::i_imm:                      cmpmux2_out = i_imm;
        cmpmux::cmpmux2_alu_out:            cmpmux2_out = alu_out;
        cmpmux::cmpmux2_regfilemux_out:     cmpmux2_out = regfilemux_out;
        cmpmux::cmpmux2_regfile_imm_out:    cmpmux2_out = regfile_in;
        default: `BAD_MUX_SEL;
    endcase

    // mwdrmux
    unique case (mwdrmux_sel)
        mwdrmux::rs2_out:                    mwdrmux_out = rs2_out;
        mwdrmux::mwdrmux1_alu_out:           mwdrmux_out = alu_out;
        mwdrmux::mwdrmux1_regfilemux_out:    mwdrmux_out = regfilemux_out;
        mwdrmux::mwdrmux1_regfile_imm_out:   mwdrmux_out = regfile_in;
        default: `BAD_MUX_SEL;
    endcase
end


// ================================ Signals and Intermediate Registers for RVFI ================================

// rvfi_pc_rdata
rv32i_word pc_imm2_out, pc_imm3_out, rvfi_pc_rdata;
register pc_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(pc_imm1_out),
    .out(pc_imm2_out)
);
register pc_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(pc_imm2_out),
    .out(pc_imm3_out)
);
register pc_imm4(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(pc_imm3_out),
    .out(rvfi_pc_rdata)
);

// rvfi_pc_wdata
rv32i_word pc_wdata_imm1_out, pc_wdata_imm2_out, pc_wdata_imm3_in, pc_wdata_imm3_out, rvfi_pc_wdata;
register pc_wdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_ID),
    .in(pc_out + 4),
    .out(pc_wdata_imm1_out)
);
register pc_wdata_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(pc_wdata_imm1_out),
    .out(pc_wdata_imm2_out)
);

always_comb begin
    unique case (pcmux_sel)
        pcmux::pc_plus4: pc_wdata_imm3_in = pc_wdata_imm2_out;
        pcmux::br:       pc_wdata_imm3_in = (br_en ? pcmux_out : pc_wdata_imm2_out);
        default:         pc_wdata_imm3_in = pcmux_out;
    endcase
end

register pc_wdata_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(pc_wdata_imm3_in),
    .out(pc_wdata_imm3_out)
);
register pc_wdata_imm4(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(pc_wdata_imm3_out),
    .out(rvfi_pc_wdata)
);

// rvfi_rd_addr
rv32i_reg rvfi_rd_addr;
assign rvfi_rd_addr = (regfile_wb ? regfile_rd : 5'b0);

// rvfi_rd_wdata
rv32i_word rvfi_rd_wdata;
assign rvfi_rd_wdata = (rvfi_rd_addr ? regfile_in: 32'b0);

// rvfi_rs1_rdata
rv32i_word rs1_rdata_imm1_out, rs1_rdata_imm2_out, rvfi_rs1_rdata;
register rs1_rdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(rs1_out),
    .out(rs1_rdata_imm1_out)
);
register rs1_rdata_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(rs1_rdata_imm1_out),
    .out(rs1_rdata_imm2_out)
);
register rs1_rdata_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(rs1_rdata_imm2_out),
    .out(rvfi_rs1_rdata)
);

// rvfi_rs2_rdata
rv32i_word rs2_rdata_imm1_out, rs2_rdata_imm2_out, rvfi_rs2_rdata;
register rs2_rdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(rs2_out),
    .out(rs2_rdata_imm1_out)
);
register rs2_rdata_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(rs2_rdata_imm1_out),
    .out(rs2_rdata_imm2_out)
);
register rs2_rdata_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(rs2_rdata_imm2_out),
    .out(rvfi_rs2_rdata)
);

// rvfi_insn
rv32i_word insn_imm1_out, insn_imm2_out, insn_imm3_out, rvfi_insn;
register insn_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_ID),
    .in(i_rdata),
    .out(insn_imm1_out)
);
register insn_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(insn_imm1_out),
    .out(insn_imm2_out)
);
register insn_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_MEM),
    .in(insn_imm2_out),
    .out(insn_imm3_out)
);
register insn_imm4(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(insn_imm3_out),
    .out(rvfi_insn)
);


endmodule : datapath
