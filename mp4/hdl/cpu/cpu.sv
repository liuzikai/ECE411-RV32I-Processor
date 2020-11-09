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

    // control_rom -> control_words
    rv32i_control_word new_control_word;

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

    logic stall;

    // ================================ Modules ================================

    control_rom control_rom(
        .opcode(rv32i_opcode'(i_rdata[6:0])),
        .funct3(i_rdata[14:12]),
        .funct7(i_rdata[31:25]),
        .rd(i_rdata[11:7]),
        .ctrl(new_control_word)
    );

    control_words control_words(
        .d_byte_enable(raw_d_byte_enable),
        .*
    );

    datapath datapath(
        // Not using the following signals for now
        .opcode(),
        .funct3(),
        .funct7(),
        .rd_out(),

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
