`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

module cache_datapath #(
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

    // cpu <-> cache_datapath
    input  logic [31:0] mem_address,

    // bus_adapter <-> cache_datapath
    input  logic [255:0] mem_wdata256,
    output logic [255:0] mem_rdata256,
    input  logic [31:0]  mem_byte_enable256,

    // cache_datapath <-> cacheline_adapter
    output logic [255:0] ca_wdata,
    input  logic [255:0] ca_rdata,
    output logic [31:0]  ca_address,

    // datapath -> control
    output logic hit,
    output logic hit_way,

    output logic lru_way,
    output logic lru_dirty,

    // control -> datapath
    input logic load_tag[2],

    input logic set_valid[2],

    input logic lru_in,
    input logic load_lru,

    input logic dirty_in[2],
    input logic load_dirty[2],

    input datamux::datamux_sel_t datamux_sel,
    input logic load_data[2],

    input addrmux::addrmux_sel_t addrmux_sel
);

// ================================ Common ================================

// Get set index from mem_address
logic [s_index-1:0] set_index;
assign set_index = mem_address[s_index+s_offset-1:s_offset];

// Get tag from mem_address
logic [s_tag-1:0] tag;
assign tag = mem_address[31 -: s_tag];

// ================================ Arrays ================================

logic [s_tag-1:0] tag_out[2];
logic valid_out[2];
logic dirty_out[2];
logic [s_line-1:0] data_in;
logic [s_line-1:0] data_out[2];
logic lru_out;
logic [31:0] data_write_en[2];

genvar i;
generate
    for (i = 0; i < 2; ++i) begin : array_block

        // Arrays will be reset to all 0 with rst

        comb_array #(s_index, s_tag) tag_array (
            .clk(clk),
            .rst(rst),
            .load(load_tag[i]),
            .rindex(set_index),
            .windex(set_index),
            .datain(tag),
            .dataout(tag_out[i])
        );

        comb_array #(s_index, 1) valid_array (
            .clk(clk),
            .rst(rst),
            .load(set_valid[i]),
            .rindex(set_index),
            .windex(set_index),
            .datain(1'b1),  // no case that we want to clear valid bit
            .dataout(valid_out[i])
        );

        comb_array #(s_index, 1) dirty_array (
            .clk(clk),
            .rst(rst),
            .load(load_dirty[i]),
            .rindex(set_index),
            .windex(set_index),
            .datain(dirty_in[i]),
            .dataout(dirty_out[i])
        );

        comb_data_array #(s_offset, s_index) data_array (
            .clk(clk),
            .rst(rst),
            .write_en(data_write_en[i]),
            .rindex(set_index),
            .windex(set_index),
            .datain(data_in),
            .dataout(data_out[i])
        );
    end 
endgenerate

comb_array #(s_index, 1) lru_array (
    .clk(clk),
    .rst(rst),
    .load(load_lru),
    .rindex(set_index),
    .windex(set_index),
    .datain(lru_in),
    .dataout(lru_out)
);


// ================================ Matching Logic ================================

logic way_matched[2];

always_comb begin : match_logic

    // Match address with tag (if valid)
    way_matched[0] = valid_out[0] && (tag === tag_out[0]);
    way_matched[1] = valid_out[1] && (tag === tag_out[1]);
    hit = way_matched[0] || way_matched[1];
    hit_way = way_matched[1];  // (way_matched[0] ? 1'b0 : 1'b1)

    // Check whether the LRU way is dirty
    lru_way = lru_out;
    lru_dirty = dirty_out[lru_out];

end : match_logic

// ================================ Muxes ================================

always_comb begin : muxes

    // Data array input mux
    unique case (datamux_sel)
        datamux::mem_wdata256: data_in = mem_wdata256;
        datamux::ca_rdata: data_in = ca_rdata;
        default: data_in = {s_line{1'bX}};
    endcase

    // Load data control
    for (int i = 0; i < 2; ++i) begin
        unique case ({load_data[i], datamux_sel})
            2'b10: data_write_en[i] = mem_byte_enable256;  // write only the enabled bytes
            2'b11: data_write_en[i] = {32{1'b1}};  // read the full cache line
            default: data_write_en[i] = {32{1'b0}};
        endcase
    end

    // Upstream data output
    mem_rdata256 = data_out[hit_way];  // set anyway, won't take effect unless mem_resp
    
    // Downstream data output
    ca_wdata = data_out[lru_way];

    // Address output to cacheline adapter
    // Align mem_address to 32 bytes and pass to cacheline adapter
    unique case (addrmux_sel)
        addrmux::mem_addr: ca_address = {mem_address[31:s_offset], 5'b00000};
        addrmux::tag0_addr: ca_address = {tag_out[0], set_index, 5'b00000};
        addrmux::tag1_addr: ca_address = {tag_out[1], set_index, 5'b00000};
        default: ca_address = {32{1'bX}};
    endcase

end : muxes
    
endmodule : cache_datapath
