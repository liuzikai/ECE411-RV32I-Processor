import rv32i_types::*;

module cpu (
    input clk,
    input rst,

    // Signals to I-Cache (aligned)
    output rv32i_word i_addr,
    input  rv32i_word i_rdata,
    output logic      i_read,
    input  logic      i_resp,

    // Signals to D-Cache (aligned)
    output rv32i_word  d_addr,
    input  rv32i_word  d_rdata,
    output rv32i_word  d_wdata,
    output logic [3:0] d_byte_enable,
    output logic       d_read,
    output logic       d_write,
    input  logic       d_resp
);

// ================================ Internal Wires ================================

// Unaligned data channel signals, datapath <-> d_align
rv32i_word  raw_d_addr;
rv32i_word  raw_d_rdata;
rv32i_word  raw_d_wdata;
logic [3:0] raw_d_byte_enable;

// Instruction channel must be aligned

// control_words -> datapath

cmpmux::cmpmux_sel_t cmpmux_sel;
alumux::alumux1_sel_t alumux1_sel;
alumux::alumux2_sel_t alumux2_sel;

alu_ops aluop;
branch_funct3_t cmpop;
pcmux::pcmux_sel_t pcmux_sel;

// d_read, d_write, d_byte_enable directly linked to output
regfilemux::regfilemux_sel_t regfilemux_sel;

logic regfile_wb;
rv32i_reg regfile_rd;
logic br_en;

logic stall_ID;
logic stall_EX;
logic stall_MEM;
logic stall_WB;

// ================================ Modules ================================

control control(
    .instruction(i_rdata),
    .d_byte_enable(raw_d_byte_enable),
    .*
);

datapath datapath(
    // Unaligned data channel
    .d_addr(raw_d_addr),
    .d_rdata(raw_d_rdata),
    .d_wdata(raw_d_wdata),

    .*
);

mem_align d_align(
    .raw_addr(raw_d_addr),
    .raw_rdata(raw_d_rdata),
    .raw_wdata(raw_d_wdata),
    .raw_byte_enable(raw_d_byte_enable),
    .mem_addr(d_addr),
    .mem_rdata(d_rdata),
    .mem_wdata(d_wdata),
    .mem_byte_enable(d_byte_enable)
);

assign i_read = 1'b1;

// ================================ Signals and Intermediate Registers for RVFI ================================

// rvfi_pc_rdata
rv32i_word pc_imm2_out, pc_imm3_out, rvfi_pc_rdata;
register pc_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(datapath.pc_imm1_out),
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
    .in(pdatapath.pc_out + 4),
    .out(pc_wdata_imm1_out)
);
register pc_wdata_imm2(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(pc_wdata_imm1_out),
    .out(pc_wdata_imm2_out)
);
unique case (pcmux_sel)
    pcmux::pc_plus4: pc_wdata_imm3_in = pc_wdata_imm2_out;
    pcmux::br:       pc_wdata_imm3_in = (br_en ? pcmux_out : pc_wdata_imm2_out);
    default:         pc_wdata_imm3_in = pcmux_out;
endcase
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

// rvfi_d_addr
rv32i_word rvfi_d_addr;
register d_addr_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(d_addr),  // use aligned value
    .out(rvfi_d_addr)
);

// rvfi_d_rdata
rv32i_word rvfi_d_rdata;
register d_rdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(d_rdata),  // use aligned value
    .out(rvfi_d_rdata)
);

// rvfi_d_wdata
rv32i_word rvfi_d_wdata;
register d_wdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(d_wdata),  // use aligned value
    .out(rvfi_d_wdata)
);

// rvfi_d_rmask
logic [3:0] rvfi_d_rmask;
register d_rmask_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(d_read ? d_byte_enable : 4'b0),  // use aligned value
    .out(rvfi_d_rmask)
);

// rvfi_d_wmask
logic [3:0] rvfi_d_wmask;
register d_wmask_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(d_write ? d_byte_enable : 4'b0),  // use aligned value
    .out(rvfi_d_wmask)
);

// rvfi_rd_addr
rv32i_reg rvfi_rd_addr;
assign rvfi_rd_addr = (regfile_wb ? regfile_rd : 5'b0);

// rvfi_rd_wdata
rv32i_word rvfi_rd_wdata;
assign rvfi_rd_wdata = regfile_in;

// rvfi_rs1_rdata
rv32i_word rs1_rdata_imm1_out, rs1_rdata_imm2_out, rvfi_rs1_rdata;
register rs1_rdata_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_EX),
    .in(datapath.rs1_out),
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
    .in(datapath.rs2_out),
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

// rvfi_rs1_addr, rvfi_rs2_addr
rv32i_reg rvfi_rs1_addr, rvfi_rs2_addr;
assign rvfi_rs1_addr = control.MEM_WB_reg.rs1;
assign rvfi_rs2_addr = control.MEM_WB_reg.rs2;

// rvfi_valid
logic rvfi_valid;
assign rvfi_valid = (control.MEM_WB.opcode != rv32i_opcode::op_none) && ~stall_WB;

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



endmodule : cpu
