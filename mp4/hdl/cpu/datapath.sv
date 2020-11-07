`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module datapath(
    input clk,
    input rst,

    input logic load_pc,
    input logic load_ir,
    input logic load_regfile,
    input logic load_mar,
    input logic load_mdr,
    input logic load_data_out,

    input pcmux::pcmux_sel_t pcmux_sel,
    input branch_funct3_t cmpop,
    input alumux::alumux1_sel_t alumux1_sel,
    input alumux::alumux2_sel_t alumux2_sel,
    input regfilemux::regfilemux_sel_t regfilemux_sel,
    input marmux::marmux_sel_t marmux_sel,
    input cmpmux::cmpmux_sel_t cmpmux_sel,
    input alu_ops aluop,

    input logic [1:0] mem_shift_amount,

    output rv32i_word mem_address,
    input rv32i_word mem_rdata,
    output rv32i_word mem_wdata, // signal used by RVFI Monitor

    output rv32i_opcode opcode,
    output logic [2:0] funct3,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [6:0] funct7,

    output logic br_en,
    output logic [1:0] alu_out_2lsb
);

/******************* Signals Needed for RVFI Monitor *************************/
rv32i_word pcmux_out;
rv32i_word mdrreg_out;
rv32i_word mem_addr;
assign mem_addr = mem_address;
/*****************************************************************************/

rv32i_reg rd;
rv32i_word rs1_out, rs2_out;
rv32i_word i_imm, u_imm, b_imm, s_imm, j_imm;
rv32i_word alumux1_out, alumux2_out, regfilemux_out, marmux_out, cmpmux_out;
rv32i_word alu_out, pc_out;
rv32i_word mem_data_out_in;
/***************************** Registers *************************************/
// Keep Instruction register named `IR` for RVFI Monitor
ir IR(
    .clk(clk),
    .rst(rst),
    .load(load_ir),
    .in(mdrreg_out),
    .funct3(funct3),
    .funct7(funct7),
    .opcode(opcode),
    .i_imm(i_imm),
    .u_imm(u_imm),
    .b_imm(b_imm),
    .s_imm(s_imm),
    .j_imm(j_imm),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd)
);

pc_register #(32) PC(
    .clk(clk),
    .rst(rst),
    .load(load_pc),
    .in(pcmux_out),
    .out(pc_out)
);

register MDR(
    .clk(clk),
    .rst(rst),
    .load(load_mdr),
    .in(mem_rdata),
    .out(mdrreg_out)
);

register MAR(
    .clk(clk),
    .rst(rst),
    .load(load_mar),
    .in(marmux_out),
    .out(mem_address)
);

register mem_data_out(
    .clk(clk),
    .rst(rst),
    .load(load_data_out),
    .in(mem_data_out_in),
    .out(mem_wdata)
);

regfile regfile(
    .clk(clk),
    .rst(rst),
    .load(load_regfile),
    .in(regfilemux_out),
    .src_a(rs1),
    .src_b(rs2),
    .dest(rd),
    .reg_a(rs1_out),
    .reg_b(rs2_out)
);
/*****************************************************************************/

/******************************* ALU and CMP *********************************/
alu alu(
    .aluop(aluop),
    .a(alumux1_out),
    .b(alumux2_out),
    .f(alu_out)
);
assign alu_out_2lsb = alu_out[1:0];

cmp cmp(
    .cmpop(cmpop),
    .a(rs1_out),
    .b(cmpmux_out),
    .f(br_en)
);
/*****************************************************************************/

/******************************** Muxes **************************************/
always_comb begin : MUXES
    // We provide one (incomplete) example of a mux instantiated using
    // a case statement.  Using enumerated types rather than bit vectors
    // provides compile time type safety.  Defensive programming is extremely
    // useful in SystemVerilog.  In this case, we actually use
    // Offensive programming --- making simulation halt with a fatal message
    // warning when an unexpected mux select value occurs

    // pcmux
    pcmux_out = 32'hXXXXXXXX;
    unique case (pcmux_sel)
        pcmux::pc_plus4: pcmux_out = pc_out + 4;
        pcmux::alu_out:  pcmux_out = alu_out;
        pcmux::alu_mod2: pcmux_out = {alu_out[31:1], 1'b0};
        default: `BAD_MUX_SEL;
    endcase

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
        regfilemux::lw:       regfilemux_out = mdrreg_out;
        regfilemux::pc_plus4: regfilemux_out = pc_out + 4;
        regfilemux::lb: begin
            unique case (mem_shift_amount)
                2'b00: regfilemux_out = {{24{mdrreg_out[7]}}, mdrreg_out[7:0]};
                2'b01: regfilemux_out = {{24{mdrreg_out[15]}}, mdrreg_out[15:8]};
                2'b10: regfilemux_out = {{24{mdrreg_out[23]}}, mdrreg_out[23:16]};
                2'b11: regfilemux_out = {{24{mdrreg_out[31]}}, mdrreg_out[31:24]};
            endcase
        end
        regfilemux::lbu: begin
            unique case (mem_shift_amount)
                2'b00: regfilemux_out = {{24{1'b0}}, mdrreg_out[7:0]};
                2'b01: regfilemux_out = {{24{1'b0}}, mdrreg_out[15:8]};
                2'b10: regfilemux_out = {{24{1'b0}}, mdrreg_out[23:16]};
                2'b11: regfilemux_out = {{24{1'b0}}, mdrreg_out[31:24]};
            endcase
        end
        regfilemux::lh: begin
            unique case (mem_shift_amount)
                2'b00: regfilemux_out = {{16{mdrreg_out[15]}}, mdrreg_out[15:0]};
                2'b10: regfilemux_out = {{16{mdrreg_out[31]}}, mdrreg_out[31:16]};
                default: $fatal("%0t %s %0d: lh addr not aligned", $time, `__FILE__, `__LINE__);
            endcase
        end      
        regfilemux::lhu: begin
            unique case (mem_shift_amount)
                2'b00: regfilemux_out = {{16{1'b0}}, mdrreg_out[15:0]};
                2'b10: regfilemux_out = {{16{1'b0}}, mdrreg_out[31:16]};
                default: $fatal("%0t %s %0d: lhu addr not aligned", $time, `__FILE__, `__LINE__);
            endcase
        end
        default: `BAD_MUX_SEL;
    endcase

    // marmux
    unique case (marmux_sel)
        marmux::pc_out:  marmux_out = pc_out;
        marmux::alu_out: marmux_out = {alu_out[31:2], 2'b00};  // align by 4 bytes
        default: `BAD_MUX_SEL;
    endcase

    // cmpmux
    unique case (cmpmux_sel)
        cmpmux::rs2_out: cmpmux_out = rs2_out;
        cmpmux::i_imm:   cmpmux_out = i_imm;
        default: `BAD_MUX_SEL;
    endcase

    // Here we need to use alu_out since mem_data_out_load happens in the same cycle of calc_addr
    unique case (alu_out_2lsb)  
        2'b00: mem_data_out_in = rs2_out;
        2'b01: mem_data_out_in = {rs2_out[23:0], 8'b0};
        2'b10: mem_data_out_in = {rs2_out[15:0], 16'b0};
        2'b11: mem_data_out_in = {rs2_out[7:0], 24'b0};
        default: mem_data_out_in = rs2_out;
    endcase
end
/*****************************************************************************/
endmodule : datapath
