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

    // cache_datapath <-> cacheline_adapter
    output logic [255:0] ca_wdata,    // line_i
    input  logic [255:0] ca_rdata,    // line_o
    output logic [31:0]  ca_address,  // address_i

    // cache_control <-> cacheline_adapter
    input  logic ca_resp,          // resp_o
    output logic ca_read,          // read_i
    output logic ca_write          // write_i
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

logic set_valid[2];

logic lru_in;
logic load_lru;

logic dirty_in[2];
logic load_dirty[2];

datamux::datamux_sel_t datamux_sel;
logic load_data[2];

addrmux::addrmux_sel_t addrmux_sel;

cache_control control (
    .*
);

cache_datapath datapath (
    .*
);

bus_adapter bus_adapter (
    .address(mem_address),
    .*
);

endmodule : cache
