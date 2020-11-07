/* MODIFY. Your cache design. It contains the cache
controller, cache datapath, and bus adapter. */

module cache #(
    parameter s_offset = 5,
    parameter s_index  = 3,
    parameter s_tag    = 32 - s_offset - s_index,
    parameter s_mask   = 2**s_offset,
    parameter s_line   = 8*s_mask,
    parameter num_sets = 2**s_index
)
(
    input clk,
    input rst,

    // cpu -> bus_adapter & cache_control & cache_datapath
    input  logic [31:0] mem_address,

    // cpu <-> bus_adapter
    input  logic [31:0] mem_wdata,
    output logic [31:0] mem_rdata,
    input  logic [3:0]  mem_byte_enable,

    // cpu <-> cache_control
    input  logic mem_read,
    input  logic mem_write,
    output logic mem_resp,

    // NOTE: cache module is connected to the cacheline_adapter instead of the
    //       param_memory, but need to accomodate the autograder...

    // cache_datapath <-> cacheline_adapter
    output logic [255:0] pmem_wdata,    // line_i
    input  logic [255:0] pmem_rdata,    // line_o
    output logic [31:0]  pmem_address,  // address_i

    // cache_control <-> cacheline_adapter
    input  logic pmem_resp,          // resp_o
    output logic pmem_read,          // read_i
    output logic pmem_write          // write_i
);

// bus_adapter <-> cache_datapath
logic [255:0] mem_wdata256;
logic [255:0] mem_rdata256;
logic [31:0]  mem_byte_enable256;

// datapath -> control
logic hit;
logic hit_way;

logic lru_way;
logic lru_dirty;

// control -> datapath
logic load_tag[2];

logic valid_in[2];
logic load_valid[2];

logic lru_in;
logic load_lru;

logic dirty_in[2];
logic load_dirty[2];

datamux::datamux_sel_t datamux_sel;
logic load_data[2];

logic upstream_way;
logic downstream_way;

addrmux::addrmux_sel_t addrmux_sel;

cache_control control (
    .ca_resp(pmem_resp),
    .ca_read(pmem_read),
    .ca_write(pmem_write),
    .*
);

cache_datapath datapath (
    .ca_wdata(pmem_wdata),
    .ca_rdata(pmem_rdata),
    .ca_addr(pmem_address),
    .*
);

bus_adapter bus_adapter (
    .address(mem_address),
    .*
);

endmodule : cache
