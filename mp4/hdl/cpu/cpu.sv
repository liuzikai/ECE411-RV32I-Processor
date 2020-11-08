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

    // control -> datapath
    
    alumux::alumux1_sel_t alumux1_sel;
    alumux::alumux2_sel_t alumux2_sel;
    regfilemux::regfilemux_sel_t regfilemux_sel;
    cmpmux::cmpmux_sel_t cmpmux_sel;
    pcmux::pcmux_sel_t pcmux_sel;

    alu_ops aluop;
    branch_funct3_t cmpop;
    logic load_regfile;
    rv32i_reg rd_in;

    logic use_br_en;

    // ================================ Modules ================================

    datapath datapath(

        // Not using the following signals for now
        .opcode(),
        .funct3(),
        .funct7(),
        .rd_out(),
        .br_en(),

        // Always load for now, assumping memory can keep supplying data
        .load_pc(1'b1),
        .load_ir(1'b1),
        .load_regfile_imm(1'b1),

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

endmodule : cpu
