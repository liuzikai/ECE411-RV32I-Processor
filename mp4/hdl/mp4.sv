import rv32i_types::*;

module mp4(
    input clk,
    input rst,

    output rv32i_word       mem_addr,
    input  logic [63:0]     mem_rdata,
    output logic [63:0]     mem_wdata,
    output logic            mem_read,
    output logic            mem_write,
    input  logic            mem_resp
);

// CPU <-> instruction prefetch
rv32i_word i_addr_prefetch;
logic i_read_prefetch;
logic i_resp_prefetch;
// L1 prefetch <-> L2 cache
rv32i_word d_l1_l2_addr_prefecth;
logic d_l1_l2_read_prefecth;
logic d_l1_l2_resp_prefecth;

// CPU <-> I-Cache & I-Bus-Adapter
rv32i_word i_addr;
rv32i_word i_rdata;
logic      i_read;
logic      i_resp;

// CPU <-> D-Cache & D-Bus-Adapter
rv32i_word  d_addr;
rv32i_word  d_rdata;
rv32i_word  d_wdata;
logic [3:0] d_byte_enable;
logic       d_read;
logic       d_write;
logic       d_resp;

// I-Bus-Adapter <-> L1 I-Cache
logic [255:0] i_rdata256;

// D-Bus-Adapter <-> L1 D-Cache
logic [255:0] d_wdata256;
logic [255:0] d_rdata256;
logic [31:0]  d_byte_enable256;

// L1 D-Cache <-> L2 D-Cache
rv32i_word    d_addr_l2;
logic [255:0] d_wdata256_l2;
logic [255:0] d_rdata256_l2;
logic         d_read_l2;
logic         d_write_l2;
logic         d_resp_l2;

// L1 I-Cache <-> Arbiter
logic i_a_read;
logic [31:0]  i_a_addr;
logic [255:0] i_a_rdata;
logic i_a_resp;

// L2 D-Cache <-> Arbiter
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

bus_adapter i_bus_adapter (
    // CPU side
    .address(i_addr_prefetch),
    .mem_wdata('X),
    .mem_rdata(i_rdata),
    .mem_byte_enable(4'b111),
    // L1 I-Cache size
    .mem_wdata256(),
    .mem_rdata256(i_rdata256),
    .mem_byte_enable256()
);


cache l1_i_cache(
    .clk(clk),
    .rst(rst),
    // I-Bus-Adapter side
    .mem_addr(i_addr_prefetch),
    .mem_wdata256('X),
    .mem_rdata256(i_rdata256),
    .mem_byte_enable256(32'hFFFFFFFF),
    .mem_read(i_read_prefetch),
    .mem_write(1'b0),
    .mem_resp(i_resp_prefetch),
    // Arbiter side
    .ca_wdata(),
    .ca_rdata(i_a_rdata),
    .ca_addr(i_a_addr),
    .ca_resp(i_a_resp),
    .ca_read(i_a_read),
    .ca_write()
);

prefetch instruction_prefetch(
    .clk(clk),
    .rst(rst),
    // interface with the CPU 
    .mem_addr_from_cpu(i_addr),   
    .mem_read_from_cpu(i_read),
    .cpu_resp(i_resp),
    // interface with the cache
    .mem_addr_out(i_addr_prefetch),
    .cache_read(i_read_prefetch),
    .cache_resp(i_resp_prefetch)
);

bus_adapter d_bus_adapter (
    // CPU side
    .address(d_addr),
    .mem_wdata(d_wdata),
    .mem_rdata(d_rdata),
    .mem_byte_enable(d_byte_enable),
    // L1 D-Cache size
    .mem_wdata256(d_wdata256),
    .mem_rdata256(d_rdata256),
    .mem_byte_enable256(d_byte_enable256)
);

cache #(5, 3, 1, 0) l1_d_cache(
    .clk(clk),
    .rst(rst),
    // D-Bus-Adapter side
    .mem_addr(d_addr),
    .mem_wdata256(d_wdata256),
    .mem_rdata256(d_rdata256),
    .mem_byte_enable256(d_byte_enable256),
    .mem_read(d_read),
    .mem_write(d_write),
    .mem_resp(d_resp),
    // L2 D-Cache side
    .ca_wdata(d_wdata256_l2),
    .ca_rdata(d_rdata256_l2),
    .ca_addr(d_addr_l2),
    .ca_resp(d_resp_l2),
    .ca_read(d_read_l2),
    .ca_write(d_write_l2)
    // NOTE: no byte_enable
);

prefetch l1_l2_data_prefetch(
    .clk(clk),
    .rst(rst),
    // interface with the L1 data cache
    .mem_addr_from_cpu(d_addr_l2),   
    .mem_read_from_cpu(d_read_l2),
    .cpu_resp(d_resp_l2),
    // interface with the L2 data cache
    .mem_addr_out(d_l1_l2_addr_prefecth),
    .cache_read(d_l1_l2_read_prefecth),
    .cache_resp(d_l1_l2_resp_prefecth)
);

cache #(5, 6, 2, 1) l2_d_cache(
    .clk(clk),
    .rst(rst),
    // L1 D-Cache side
    .mem_addr(d_l1_l2_addr_prefecth),
    .mem_wdata256(d_wdata256_l2),
    .mem_rdata256(d_rdata256_l2),
    .mem_byte_enable256(32'hFFFFFFFF),
    .mem_read(d_l1_l2_read_prefecth),
    .mem_write(d_write_l2),
    .mem_resp(d_l1_l2_resp_prefecth),
    // Arbiter side
    .ca_wdata(d_a_wdata),
    .ca_rdata(d_a_rdata),
    .ca_addr(d_a_addr),
    .ca_resp(d_a_resp),
    .ca_read(d_a_read),
    .ca_write(d_a_write)
);

arbiter arbiter(
    // L1 I-Cache size
    .i_read(i_a_read),
    .i_addr(i_a_addr),
    .i_data(i_a_rdata),
    .i_resp(i_a_resp),
    // L2 D-Cache size
    .d_read(d_a_read),
    .d_write(d_a_write),
    .d_addr(d_a_addr),
    .d_wdata(d_a_wdata),
    .d_rdata(d_a_rdata),
    .d_resp(d_a_resp),
    // Cacheline Adapter side
    .*
);

cacheline_adaptor cacheline_adaptor (
    .clk(clk),
    .reset_n(~rst),
    // Arbiter side
    .line_i(ca_wdata),
    .line_o(ca_rdata),
    .address_i(ca_addr),
    .resp_o(ca_resp),
    .read_i(ca_read),
    .write_i(ca_write),
    // ParamMemory side
    .burst_i(mem_rdata),
    .burst_o(mem_wdata),
    .address_o(mem_addr),
    .read_o(mem_read),
    .write_o(mem_write),
    .resp_i(mem_resp)
);

endmodule : mp4
