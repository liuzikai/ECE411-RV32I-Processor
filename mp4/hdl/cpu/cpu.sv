import rv32i_types::*;

module cpu #(
    parameter bp_type = 0
)
(
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

// control <-> datapath
alumux::alumux1_sel_t alumux1_sel;
alumux::alumux2_sel_t alumux2_sel;
cmpmux::cmpmux2_sel_t cmpmux2_sel;
rsmux::rsmux_sel_t rs1mux_sel;
rsmux::rsmux_sel_t rs2mux_sel;
rv32i_reg regfile_rs1;
rv32i_reg regfile_rs2;

alu_ops aluop;
branch_funct3_t cmpop;
expcmux::expcmux_sel_t expcmux_sel;
logic ex_load_pc;

wbdatamux::wbdatamux_sel_t wbdatamux_sel;

rv32i_reg regfile_rd;
logic bp_update;

logic stall_id;
logic stall_ex;
logic stall_mem;
logic stall_wb;

// ================================ Modules ================================

control control(
    .instruction(i_rdata),
    .d_byte_enable(raw_d_byte_enable),
    .*
);

datapath #(.bp_type(bp_type)) datapath(
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

endmodule : cpu
