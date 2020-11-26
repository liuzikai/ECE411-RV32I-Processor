`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module datapath(
    input clk,
    input rst,

    // IF, signals to I-Cache
    output rv32i_word i_addr,
    input  rv32i_word i_rdata,

    // ID
    input alumux::alumux1_sel_t alumux1_sel,
    input alumux::alumux2_sel_t alumux2_sel,
    input cmpmux::cmpmux2_sel_t cmpmux2_sel,
    input rsmux::rsmux_sel_t rs1mux_sel,
    input rsmux::rsmux_sel_t rs2mux_sel,
    // rs1 and rs2 comes from IR as "raw" values


    // EX
    input alu_ops aluop,
    input branch_funct3_t cmpop,
    // For BR/JAL/JALR instruction in EX stage
    input expcmux::expcmux_sel_t expcmux_sel,
    // For control to decide whether to flush
    output logic ex_load_pc,


    // MEM
    input wbdatamux::wbdatamux_sel_t wbdatamux_sel,
    // Signals to D-Cache
    output rv32i_word d_addr,
    input  rv32i_word d_rdata,
    output rv32i_word d_wdata
    

    // WB
    input rv32i_reg regfile_rd,
    

    // Stall signals
    input logic stall_id,
    input logic stall_ex,
    input logic stall_mem,
    input logic stall_wb
);

// ================================ Internal signals ================================

// Output of ir
rv32i_reg rs1, rs2;
rv32i_word i_imm, u_imm, b_imm, s_imm, j_imm;
rv32i_opcode opcode;
logic [2:0] funct3;
logic [6:0] funct7;
rv32i_reg rd_out;

// Output of regfile
rv32i_word regfile_rs1_out, regfile_rs1_out;

// Output of alu
rv32i_word alu_out;

// Output of cmp in 32 bits
rv32i_word cmp_out;

// Output of pc and chained intermediate registers
rv32i_word pc_out, pc_id_out, pc_ex_out, pc_mem_out, rvfi_pc_rdata;

// Output of intermediate registers
rv32i_word regfile_in, alu_in1, alu_in2, cmp_in1, cmp_in2, alu_wb_imm_out, mwdr_ex_out;
rv32i_word u_imm_ex_out, u_imm_mem_out, cmp_wb_imm_out, cmpmux2_out;
rv32i_word alumux1_out, alumux2_out, wbdatamux_out, marmux_out, pcmux_out;

// Data after forwarding
rv32i_word rs1_actual, rs2_actual;

assign i_addr = pc_out;
assign cmp_out = {31'b0, br_en};

logic ld_pc;

// ================================ Registers ================================

ir ir(
    .clk(clk),
    .rst(rst),
    .load(~stall_id),
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

register u_imm_ex(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(u_imm),
    .out(u_imm_ex_out)
);

register u_imm_mem(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(u_imm_ex_out),
    .out(u_imm_mem_out)
);

pc_register pc(
    .clk(clk),
    .rst(rst),
    .load(ld_pc),
    .in(pcmux_out),
    .out(pc_out)
);

register pc_id(
    .clk(clk),
    .rst(rst),
    .load(~stall_id),
    .in(pc_out),
    .out(pc_id_out)
);

register pc_ex(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(pc_id_out),
    .out(pc_ex_out)
);
register pc_mem(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(pc_ex_out),
    .out(pc_mem_out)
);
register pc_wb(
    .clk(clk),
    .rst(rst),
    .load(~stall_wb),
    .in(pc_mem_out),
    .out(rvfi_pc_rdata)
);

register mdar(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(alu_out),
    .out(d_addr)
);

register mwdr(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(mwdr_ex_out),
    .out(d_wdata)
);

register mwdr_ex(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(rs2_actual),
    .out(mwdr_ex_out)
);

register wbdata(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(wbdatamux_out),
    .out(regfile_in)
);

register alu_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(alumux1_out),
    .out(alu_in1)
);

register alu_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(alumux2_out),
    .out(alu_in2)
);

register alu_wb_imm(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(alu_out),
    .out(alu_wb_imm_out)
);

register cmp_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(rs1_actual),
    .out(cmp_in1)
);

register cmp_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(cmpmux2_out),
    .out(cmp_in2)
);

register cmp_wb_imm(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(cmp_out),
    .out(cmp_wb_imm_out)
);

// ================================ Regfile, ALU and CMP ================================

regfile regfile(
    .clk(clk),
    .rst(rst),
    .load(regfile_wb && (~stall_wb)),
    .in(regfile_in),
    .src_a(rs1),        // directly from IR
    .src_b(rs2),        // directly from IR
    .dest(regfile_rd),  // from control word
    .reg_a(regfile_rs1_out),
    .reg_b(regfile_rs2_out)
);

alu alu(
    .aluop(aluop),
    .a(alu_in1),
    .b(alu_in2),
    .f(alu_out)
);

cmp cmp(
    .cmpop(cmpop),
    .a(cmp_in1),
    .b(cmp_in2),
    .f(br_en)
);

// ================================ MUXes ================================

always_comb begin : MUXES

    unique case ({expcmux_sel, br_en})
        3'b100, 3'b101: begin  // expcmux::alu_out, regardless of br_en
            pcmux_out = alu_out; 
            ld_pc = ~stall_ex;
            ex_load_pc = 1'b1;
        end
        3'b110, 3'b111: begin  // expcmux::alu_mod2, regardless of br_en
            pcmux_out = {alu_out[31:1], 1'b0};
            ld_pc = ~stall_ex;
            ex_load_pc = 1'b1;
        end
        3'b011: begin  // expcmux::br and br_en
            pcmux_out = alu_out;
            ld_pc = ~stall_ex;
            ex_load_pc = 1'b1;
        end
        default: begin
            pcmux_out = pc_out + 4;
            ld_pc = ~stall_id;
            ex_load_pc = 1'b0;
        end
    endcase

    //rs1mux
    unique case (rs1mux_sel)
        rsmux::regfile_out:    rs1_actual = regfile_rs1_out;
        rsmux::alu_out:        rs1_actual = alu_out;
        rsmux::cmp_out:        rs1_actual = cmp_out;
        rsmux::u_imm_ex:       rs1_actual = u_imm_ex_out;
        rsmux::pc_ex_plus4:    rs1_actual = pc_ex_out + 4;
        rsmux::wbdatamux_out:  rs1_actual = wbdatamux_out;
        rsmux::wbdata_out:     rs1_actual = regfile_in;
    endcase

    //rs2mux
    unique case (rs2mux_sel)
        rsmux::regfile_out:    rs2_actual = regfile_rs2_out;
        rsmux::alu_out:        rs2_actual = alu_out;
        rsmux::cmp_out:        rs2_actual = cmp_out;
        rsmux::u_imm_ex:       rs2_actual = u_imm_ex_out;
        rsmux::pc_ex_plus4:    rs2_actual = pc_ex_out + 4;
        rsmux::wbdatamux_out:  rs2_actual = wbdatamux_out;
        rsmux::wbdata_out:     rs2_actual = regfile_in;
    endcase

    // wbdatamux
    unique case (wbdatamux_sel)
        wbdatamux::alu_out:   wbdatamux_out = alu_wb_imm_out;
        wbdatamux::br_en:     wbdatamux_out = cmp_wb_imm_out;
        wbdatamux::u_imm:     wbdatamux_out = u_imm_mem_out;
        wbdatamux::pc_plus4:  wbdatamux_out = pc_mem_out + 4;
        wbdatamux::lw:        wbdatamux_out = d_rdata;
        wbdatamux::lb:        wbdatamux_out = {{24{d_rdata[7]}}, d_rdata[7:0]};
        wbdatamux::lbu:       wbdatamux_out = {24'b0, d_rdata[7:0]};
        wbdatamux::lh:        wbdatamux_out = {{16{d_rdata[15]}}, d_rdata[15:0]};
        wbdatamux::lhu:       wbdatamux_out = {16'b0, d_rdata[15:0]};
        default: `BAD_MUX_SEL;
    endcase

    // alumux1
    unique case (alumux1_sel)
        alumux::rs1_out:  alumux1_out = rs1_actual;
        alumux::pc_out:   alumux1_out = pc_id_out;
        default: `BAD_MUX_SEL;
    endcase

    // alumux2
    unique case (alumux2_sel)
        alumux::i_imm:    alumux2_out = i_imm;
        alumux::u_imm:    alumux2_out = u_imm;
        alumux::b_imm:    alumux2_out = b_imm;
        alumux::s_imm:    alumux2_out = s_imm;
        alumux::j_imm:    alumux2_out = j_imm;
        alumux::rs2_out:  alumux2_out = rs2_actual;
        default: `BAD_MUX_SEL;
    endcase

    unique case (cmpmux2_sel)
        cmpmux::rs2_out:  cmpmux2_out = rs2_actual;
        cmpmux::i_imm:    cmpmux2_out = i_imm;
        default: `BAD_MUX_SEL;
    endcase

end


// ================================ Signals and Intermediate Registers for RVFI ================================

// rvfi_pc_wdata
rv32i_word pc_wdata_imm1_out, pc_wdata_imm2_out, pc_wdata_imm3_in, pc_wdata_imm3_out, rvfi_pc_wdata;
register pc_wdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_id),
    .in(pc_out + 4),
    .out(pc_wdata_imm1_out)
);
register pc_wdata_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
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
    .load(~stall_ex),
    .in(pc_wdata_imm3_in),
    .out(pc_wdata_imm3_out)
);
register pc_wdata_imm4(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
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
    .load(~stall_ex),
    .in(rs1_actual),
    .out(rs1_rdata_imm1_out)
);
register rs1_rdata_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(rs1_rdata_imm1_out),
    .out(rs1_rdata_imm2_out)
);
register rs1_rdata_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_wb),
    .in(rs1_rdata_imm2_out),
    .out(rvfi_rs1_rdata)
);

// rvfi_rs2_rdata
rv32i_word rs2_rdata_imm1_out, rs2_rdata_imm2_out, rvfi_rs2_rdata;
register rs2_rdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(rs2_actual),
    .out(rs2_rdata_imm1_out)
);
register rs2_rdata_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(rs2_rdata_imm1_out),
    .out(rs2_rdata_imm2_out)
);
register rs2_rdata_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_wb),
    .in(rs2_rdata_imm2_out),
    .out(rvfi_rs2_rdata)
);

// rvfi_insn
rv32i_word insn_imm1_out, insn_imm2_out, insn_imm3_out, rvfi_insn;
register insn_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_id),
    .in(i_rdata),
    .out(insn_imm1_out)
);
register insn_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_ex),
    .in(insn_imm1_out),
    .out(insn_imm2_out)
);
register insn_imm3(
    .clk(clk),
    .rst(rst),
    .load(~stall_mem),
    .in(insn_imm2_out),
    .out(insn_imm3_out)
);
register insn_imm4(
    .clk(clk),
    .rst(rst),
    .load(~stall_wb),
    .in(insn_imm3_out),
    .out(rvfi_insn)
);


endmodule : datapath
