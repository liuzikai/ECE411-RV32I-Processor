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

cmpmux::cmpmux1_sel_t cmpmux1_sel;
cmpmux::cmpmux2_sel_t cmpmux2_sel;
alumux::alumux1_sel_t alumux1_sel;
alumux::alumux2_sel_t alumux2_sel;
mwdrmux::mwdrmux_sel_t mwdrmux_sel;

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
register #(4) d_rmask_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(d_read ? 4'b1111 : 4'b0),  // use aligned value
    .out(rvfi_d_rmask)
);

// rvfi_d_wmask
logic [3:0] rvfi_d_wmask;
register #(4) d_wmask_imm1(
    .clk(clk),
    .rst(rst),
    .load(~stall_WB),
    .in(d_write ? d_byte_enable : 4'b0),  // use aligned value
    .out(rvfi_d_wmask)
);

endmodule : cpu
