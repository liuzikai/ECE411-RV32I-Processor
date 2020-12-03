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
    // rs1 and rs2 must come control word, otherwise it will be checked but no forwarding is applied
    input rv32i_reg regfile_rs1,
    input rv32i_reg regfile_rs2,


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
    output rv32i_word d_wdata,
    

    // WB
    input rv32i_reg regfile_rd,
    
    // Branch Prediction Signals
    input logic bp_update,

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
rv32i_word regfile_rs1_out, regfile_rs2_out;

// Output of alu
rv32i_word alu_out;

// Output of cmp
logic br_en;
rv32i_word cmp_out;  // in 32 bits

// Output of pc and chained intermediate registers
rv32i_word pc_out, pc_id_out, pc_ex_out, pc_mem_out;

// PC value for branch prediction
rv32i_word bp_pc_in;

// Signals of branch prediction
logic br_take, mispred, bp_enable;

// Output of intermediate registers
rv32i_word regfile_in, alu_in1, alu_in2, cmp_in1, cmp_in2, alu_wb_imm_out, mwdr_ex_out;
rv32i_word u_imm_ex_out, u_imm_mem_out, cmp_wb_imm_out, cmpmux2_out;
rv32i_word alumux1_out, alumux2_out, wbdatamux_out, pc_in;

// Data after forwarding
rv32i_word rs1_actual, rs2_actual;

assign i_addr = pc_out;
assign cmp_out = {31'b0, br_en};
assign bp_pc_in = pc_out + {{20{i_rdata[31]}}, i_rdata[7], i_rdata[30:25], i_rdata[11:8], 1'b0};
assign bp_enable = i_rdata[6:0] == op_br;
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
    .rs1(rs1),
    .rs2(rs2),
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
    .in(pc_in),
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
    .load(~stall_wb),  // always load, use regfile_rd to decide whether to write
    .in(regfile_in),
    .src_a(regfile_rs1),  // from control word
    .src_b(regfile_rs2),  // from control word
    .dest(regfile_rd),    // from control word
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

tournament_p tournament_p(
    .update(bp_update & ~stall_ex),
    .raddr(pc_out),
    .waddr(pc_ex_out),
    .*
);

// ================================ MUXes ================================

always_comb begin
    // expcmux
    unique case ({expcmux_sel, mispred})
        3'b100, 3'b101: begin  // expcmux::alu_out, regardless of mis-prediction
            pc_in = alu_out; 
            ld_pc = ~stall_ex;
            ex_load_pc = 1'b1;
        end
        3'b110, 3'b111: begin  // expcmux::alu_mod2, regardless of mis-prediction
            pc_in = {alu_out[31:1], 1'b0};
            ld_pc = ~stall_ex;
            ex_load_pc = 1'b1;
        end
        3'b011: begin  // expcmux::br and mis-prediction
            pc_in = (br_en) ? alu_out : (pc_ex_out + 4);
            ld_pc = ~stall_ex;
            ex_load_pc = 1'b1;
        end
        default: begin
            pc_in = (bp_enable & br_take) ? bp_pc_in : (pc_out + 4);  // load for IF instruction
            ld_pc = ~stall_id;
            ex_load_pc = 1'b0;
        end
    endcase
end

always_comb begin
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
end

always_comb begin
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
end

always_comb begin
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
end

always_comb begin
    // alumux1
    unique case (alumux1_sel)
        alumux::rs1_out:  alumux1_out = rs1_actual;
        alumux::pc_out:   alumux1_out = pc_id_out;
        default: `BAD_MUX_SEL;
    endcase
end

always_comb begin
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
end

always_comb begin
    unique case (cmpmux2_sel)
        cmpmux::rs2_out:  cmpmux2_out = rs2_actual;
        cmpmux::i_imm:    cmpmux2_out = i_imm;
        default: `BAD_MUX_SEL;
    endcase

end

endmodule : datapath
