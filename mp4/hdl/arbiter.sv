import rv32i_types::*;
module arbiter ( 

    input clk,
    input rst,

    // Signal between i_cache and the arbiter
    input  i_read,
    input  logic [31:0]  i_addr,
    output logic [255:0] i_data,
    output i_resp,

    // Signal between d_cache and the arbiter
    input  d_read,
    input  d_write,
    input  logic [31:0]  d_addr,
    input  logic [255:0] d_wdata,
    output logic [255:0] d_rdata,
    output d_resp,

    // Signal between cacheline adaptor and the arbiter
    output logic ca_write,
    output logic ca_read,
    output logic [31:0] ca_addr,
    input  logic[255:0] ca_rdata,
    output logic[255:0] ca_wdata,
    input  logic ca_resp
);


always_comb begin
    if (d_read || d_write) begin  // if there is access from d-cache
        i_data = 256'bX;
        i_resp = 1'b0;

        ca_read = d_read;
        ca_write = d_write;
        d_rdata = ca_rdata;
        d_resp = ca_resp;
        ca_addr = d_addr;
        ca_wdata = d_wdata;
    end else begin
        i_data = ca_rdata;
        i_resp = ca_resp;
        ca_read = i_read;
        ca_write = 1'b0;
        d_rdata = 256'bX;
        d_resp = 1'b0;
        ca_addr = i_addr;
        ca_wdata = 256'bX;
    end
end

endmodule : arbiter
