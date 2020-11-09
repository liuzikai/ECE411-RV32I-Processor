import rv32i_types::*;

module mp4(
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

cpu cpu(.*);

endmodule : mp4
