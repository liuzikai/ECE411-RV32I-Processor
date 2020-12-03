`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

module cache_datapath #(
    parameter s_offset = 5,   // must be 5 to be consistent with the cacheline size
    parameter s_index  = 3,
    parameter way_deg = 1,    // >=1, also the number of bit(s) for way indices
    parameter resp_cycle = 0
)
(
    input clk,
    input rst,

    // cpu <-> cache_datapath
    input  logic [31:0] mem_addr,

    // bus_adapter <-> cache_datapath
    input  logic [255:0] mem_wdata256,
    output logic [255:0] mem_rdata256,
    input  logic [31:0]  mem_byte_enable256,

    // cache_datapath <-> cacheline_adapter
    output logic [255:0] ca_wdata,
    input  logic [255:0] ca_rdata,
    output logic [31:0]  ca_addr,

    // datapath -> control
    output logic hit,
    output logic [way_deg-1:0] hit_way,

    output logic [way_deg-1:0] lru_way,
    output logic lru_dirty,

    // control -> datapath
    input logic load_tag[2**way_deg],

    input logic set_valid[2**way_deg],

    output logic [2**way_deg-2:0] lru_out,  
    input  logic [2**way_deg-2:0] lru_in,
    input  logic load_lru,

    input logic dirty_in[2**way_deg],
    input logic load_dirty[2**way_deg],

    input datamux::datamux_sel_t datamux_sel,
    input logic load_data[2**way_deg],

    input addrmux::addrmux_sel_t addrmux_sel
);

localparam s_tag    = 32 - s_offset - s_index;
localparam s_mask   = 2**s_offset;
localparam s_line   = 8*s_mask;
localparam num_sets = 2**s_index;
localparam way_count = 2**way_deg;

// ================================ Common ================================

// Get set index from mem_addr
logic [s_index-1:0] set_index;
assign set_index = mem_addr[s_index+s_offset-1:s_offset];

// Get tag from mem_addr
logic [s_tag-1:0] tag;
assign tag = mem_addr[31 -: s_tag];

// ================================ Arrays ================================

logic [s_tag-1:0] tag_out[way_count];
logic valid_out[way_count];
logic dirty_out[way_count];
logic [s_line-1:0] data_in;
logic [s_line-1:0] data_out[way_count];
logic [31:0] data_write_en[way_count];

genvar i;
generate
    for (i = 0; i < way_count; ++i) begin : array_block

        // Arrays will be reset to all 0 with rst

        cache_array #(s_index, s_tag) tag_array (
            .clk(clk),
            .rst(rst),
            .load(load_tag[i]),
            .rindex(set_index),
            .windex(set_index),
            .datain(tag),
            .dataout(tag_out[i])
        );

        cache_array #(s_index, 1) valid_array (
            .clk(clk),
            .rst(rst),
            .load(set_valid[i]),
            .rindex(set_index),
            .windex(set_index),
            .datain(1'b1),  // no case that we want to clear valid bit
            .dataout(valid_out[i])
        );

        cache_array #(s_index, 1) dirty_array (
            .clk(clk),
            .rst(rst),
            .load(load_dirty[i]),
            .rindex(set_index),
            .windex(set_index),
            .datain(dirty_in[i]),
            .dataout(dirty_out[i])
        );

        if (resp_cycle == 0) begin
            logic_data_array #(s_offset, s_index) data_array (
                .clk(clk),
                .rst(rst),
                .write_en(data_write_en[i]),
                .rindex(set_index),
                .windex(set_index),
                .datain(data_in),
                .dataout(data_out[i])
            );
        end else begin
            bram_data_array #(s_offset, s_index) data_array (
                .clk(clk),
                // No rst
                // No byte_enable support for bram_data_array, always load the whole cacheline
                .load(load_data[i]),
                .index(set_index),
                .datain(data_in),
                .dataout(data_out[i])
            );
        end
    end 
endgenerate

cache_array #(s_index, 2**way_deg-1) lru_array (
    .clk(clk),
    .rst(rst),
    .load(load_lru),
    .rindex(set_index),
    .windex(set_index),
    .datain(lru_in),
    .dataout(lru_out)
);


// ================================ Matching Logic ================================

always_comb begin : match_logic

    // Match address with tag (if valid)
    hit = '0;
    hit_way = '0;
    for (int i = 0; i < 2**way_deg; ++i) begin
        if (valid_out[i] && tag === tag_out[i]) begin
            hit = 1'b1;
            hit_way = i[way_deg-1:0];
        end
    end

end : match_logic


// Check whether the LRU way is dirty

generate
    if (way_deg == 1) assign lru_way = lru_out;
    else if (way_deg == 2) begin
        always_comb begin
            // 4 way, LRU tree to LRU way index
            lru_way[1] = lru_out[0];
            lru_way[0] = (lru_way[1] == 1'b0) ? lru_out[1] : lru_out[2];
        end
    end else if (way_deg == 3) begin
        always_comb begin
            // 8 way, LRU tree to LRU way index
            lru_way[2] = lru_out[0];
            lru_way[1] = (lru_way[2] == 1'b0) ? lru_out[1] : lru_out[2];
            unique case (lru_way[2:1])
                2'b00: lru_way[0] = lru_out[3];
                2'b01: lru_way[0] = lru_out[4];
                2'b10: lru_way[0] = lru_out[5];
                2'b11: lru_way[0] = lru_out[6];
            endcase
        end
    end
endgenerate

assign lru_dirty = dirty_out[lru_way];


// ================================ Muxes ================================

always_comb begin : muxes

    // Data array input mux
    unique case (datamux_sel)
        datamux::mem_wdata256: data_in = mem_wdata256;
        datamux::ca_rdata: data_in = ca_rdata;
        default: data_in = {s_line{1'bX}};
    endcase

    // Load data control
    for (int i = 0; i < way_count; ++i) begin
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
    // Align mem_addr to 32 bytes and pass to cacheline adapter
    unique case (addrmux_sel)
        addrmux::mem_addr: ca_addr = {mem_addr[31:s_offset], 5'b00000};
        addrmux::tag_addr: ca_addr = {tag_out[lru_way], set_index, 5'b00000};
        default: ca_addr = {32'b0};
    endcase

end : muxes
    
endmodule : cache_datapath
