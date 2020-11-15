import rv32i_types::*;

module mp4(
    input clk,
    input rst,

    output rv32i_word  mem_addr,
    input  rv32i_word  mem_rdata,
    output rv32i_word  mem_wdata,
    output logic       mem_read,
    output logic       mem_write,
    input  logic       mem_resp
);

// CPU <-> I-Cache
rv32i_word i_addr;
rv32i_word i_rdata;
logic      i_read;
logic      i_resp;

// CPU <-> D-Cache
rv32i_word  d_addr;
rv32i_word  d_rdata;
rv32i_word  d_wdata;
logic [3:0] d_byte_enable;
logic       d_read;
logic       d_write;
logic       d_resp;

// I-Cache <-> Arbiter
logic i_a_read;
logic [31:0]  i_a_addr;
logic [255:0] i_a_rdata;
logic i_a_resp;

// D-Cache <-> Arbiter
logic d_a_write;
logic d_a_read;
logic [31:0]  d_a_addr;
logic [255:0] d_a_rdata;
logic [255:0] d_a_wdata;
logic d_a_resp;

// Arbiter <-> Cacheline Adaptor
logic ca_write;
logic ca_read;
logic [31:0]  ca_addr;
logic [255:0] ca_rdata;
logic [255:0] ca_wdata;
logic ca_resp;

cpu cpu(
    .*
);

cache i_cache(
    .clk(clk),
    .rst(rst),
    .mem_addr(i_addr),
    .mem_wdata(32'bX),
    .mem_rdata(i_rdata),
    .mem_byte_enable(4'b1111);
    .mem_read(i_read),
    .mem_write(1'b0),
    .mem_resp(i_resp),
    .ca_wdata(),
    .ca_rdata(i_a_rdata),
    .ca_addr(i_a_addr),
    .ca_resp(i_a_resp),
    .ca_read(i_a_read),
    .ca_write()
);

cache d_cache(
    .clk(clk),
    .rst(rst),
    .mem_addr(d_addr),
    .mem_wdata(d_wdata),
    .mem_rdata(d_rdata),
    .mem_byte_enable(d_byte_enable);
    .mem_read(d_read),
    .mem_write(d_write),
    .mem_resp(d_resp),
    .ca_wdata(d_a_wdata),
    .ca_rdata(d_a_rdata),
    .ca_addr(d_a_addr),
    .ca_resp(d_a_resp),
    .ca_read(d_a_read),
    .ca_write(d_a_write)
);

arbiter arbiter(
    .i_read(i_a_read),
    .i_addr(i_a_addr),
    .i_data(i_a_rdata),
    .i_resp(i_a_resp),
    .d_read(d_a_read),
    .d_write(d_a_write),
    .d_addr(d_a_addr),
    .d_wdata(d_a_wdata)
    .d_rdata(d_a_rdata),
    .d_resp(d_a_resp),
    .*
)

cacheline_adaptor cacheline_adaptor (
    .clk(clk),
    .reset_n(~rst),

    .line_i(ca_wdata),
    .line_o(ca_rdata),
    .address_i(ca_addr),
    .resp_o(ca_resp),
    .read_i(ca_read),
    .write_i(ca_write),

    .burst_i(mem_rdata),
    .burst_o(mem_wdata),
    .address_o(mem_address),
    .read_o(mem_read),
    .write_o(mem_write),
    .resp_i(mem_resp)
);

endmodule : mp4
