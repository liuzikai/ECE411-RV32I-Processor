`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module datapath(
    input clk,
    input rst,

    // Signals output to control_rom
    output rv32i_opcode opcode,
    output logic [2:0] funct3,
    output logic [6:0] funct7,
    output rv32i_reg rd_out,

    // Signals to intermediate registers
    input logic load_pc,
    input logic load_ir,
    input logic load_regfile_imm,

    // Signals from control words to MUXes
    input alumux::alumux1_sel_t alumux1_sel,
    input alumux::alumux2_sel_t alumux2_sel,
    input regfilemux::regfilemux_sel_t regfilemux_sel,
    input cmpmux::cmpmux_sel_t cmpmux_sel,
    input pcmux::pcmux_sel_t pcmux_sel,

    // Signals to ALU, CMP and regfile
    input alu_ops aluop,
    input branch_funct3_t cmpop,
    input logic load_regfile,
    input rv32i_reg rd_in,

    // Signals to I-Cache
    output rv32i_word i_addr,
    input  rv32i_word i_rdata,

    // Signals to D-Cache
    output rv32i_word d_addr,
    input  rv32i_word d_rdata,
    output rv32i_word d_wdata,

    // Signals for branch control
    input  logic use_br_en,
    output logic br_en
    // TODO: more signals to add in order to support flush and branch prediction
);

// ================================ Internal signals ================================

rv32i_reg rs1, rs2;  // directly connected from IR to regfile, since it is used directly in the ID stage

rv32i_word rs1_out, rs2_out;
rv32i_word i_imm, u_imm, b_imm, s_imm, j_imm;
rv32i_word alu_out, pc_out;

rv32i_word regfile_in, alu_in1, alu_in2, cmp_in1, cmp_in2;
pcmux::pcmux_sel_t pcmux_sel;

rv32i_word alumux1_out, alumux2_out, regfilemux_out, marmux_out, cmpmux_out;

assign i_addr = pc_out;

// ================================ Registers ================================

// Keep Instruction register named `IR` for RVFI Monitor
ir IR(
    .clk(clk),
    .rst(rst),
    .load(load_ir),
    .in(i_rdata),
    .funct3(funct3),
    .funct7(funct7),
    .opcode(opcode),
    .i_imm(i_imm),
    .u_imm(u_imm),
    .b_imm(b_imm),
    .s_imm(s_imm),
    .j_imm(j_imm),
    .rs1(rs1),   // directly to regfile
    .rs2(rs2),   // directly to regfile
    .rd(rd_out)  // to control_rom
);

pc_register PC(
    .clk(clk),
    .rst(rst),
    .load(load_pc),
    .in(pcmux_out),
    .out(pc_out)
);

register MDAR(
    .clk(clk),
    .rst(rst),
    .load(1'b1),
    .in(alu_out),
    .out(d_addr)
);

register MWDR(
    .clk(clk),
    .rst(rst),
    .load(1'b1),
    .in(rs2_out),
    .out(d_wdata)
);

register regfile_imm(
    .clk(clk),
    .rst(rst),
    .load(load_regfile_imm),
    .in(regfilemux_out),
    .out(regfile_in)
);

register alu_imm1(
    .clk(clk),
    .rst(rst),
    .load(1'b1),
    .in(alumux1_out),
    .out(alu_in1)
);

register alu_imm2(
    .clk(clk),
    .rst(rst),
    .load(1'b1),
    .in(alumux2_out),
    .out(alu_in2)
);

register cmp_imm1(
    .clk(clk),
    .rst(rst),
    .load(1'b1),
    .in(cmpmux_out),
    .out(cmp_in1)
);

register cmp_imm2(
    .clk(clk),
    .rst(rst),
    .load(1'b1),
    .in(rs1_out),
    .out(cmp_in2)
);

// ================================ Regfile, ALU and CMP ================================

regfile regfile(
    .clk(clk),
    .rst(rst),
    .load(load_regfile),
    .in(regfile_in),
    .src_a(rs1),   // directly from IR
    .src_b(rs2),   // directly from IR
    .dest(rd_in),  // from control word
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
    .a(cmp_in2),  // rs1_out
    .b(cmp_in1),  // cmpmux_out
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
    if (use_br_en & br_en) begin
        // A BR instruction is in EX state and the branch is taken, use this address as next PC
        unique case (pcmux_sel)
            pcmux::alu_out:  pcmux_out = alu_out;
            pcmux::alu_mod2: pcmux_out = {alu_out[31:1], 1'b0};
            default: `BAD_MUX_SEL;
        endcase
    end else begin
        pcmux_out = pc_out + 4;
    end

    // alumux1
    unique case (alumux1_sel)
        alumux::rs1_out: alumux1_out = rs1_out;
        alumux::pc_out:  alumux1_out = pc_out;
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
        default: `BAD_MUX_SEL;
    endcase

    // regfilemux
    regfilemux_out = 32'hXXXXXXXX;
    unique case (regfilemux_sel)
        regfilemux::alu_out:  regfilemux_out = alu_out;
        regfilemux::br_en:    regfilemux_out = br_en;
        regfilemux::u_imm:    regfilemux_out = u_imm;
        regfilemux::pc_plus4: regfilemux_out = pc_out + 4;
        regfilemux::lw:       regfilemux_out = mem_rdata;
        regfilemux::lb:       regfilemux_out = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
        regfilemux::lbu:      regfilemux_out = {24'b0, mem_rdata[7:0]};
        regfilemux::lh:       regfilemux_out = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
        regfilemux::lhu:      regfilemux_out = {16'b0, mem_rdata[15:0]};
        default: `BAD_MUX_SEL;
    endcase

    // cmpmux
    unique case (cmpmux_sel)
        cmpmux::rs2_out: cmpmux_out = rs2_out;
        cmpmux::i_imm:   cmpmux_out = i_imm;
        default: `BAD_MUX_SEL;
    endcase

end

endmodule : datapath
