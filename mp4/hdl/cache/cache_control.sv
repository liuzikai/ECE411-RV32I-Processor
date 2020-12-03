`define BAD_STATE $fatal("%0t %s %0d: Illegal state", $time, `__FILE__, `__LINE__)

module cache_control #(
    parameter s_offset = 5,   // must be 5 to be consistent with the cacheline size
    parameter s_index  = 3,
    parameter way_deg = 1,    // >=1, also the number of bit(s) for way indices
    parameter resp_cycle = 0  // options: 0 or 1
)
(
    input clk,
    input rst,

    // cpu <-> cache_control
    input  logic [31:0] mem_addr,
    input  logic mem_read,
    input  logic mem_write,
    output logic mem_resp,

    // cache_control <-> cacheline_adapter
    input  logic ca_resp,
    output logic ca_read,
    output logic ca_write,

    // datapath -> control
    input logic hit,
    input logic [way_deg-1:0] hit_way,

    input logic [way_deg-1:0] lru_way,
    input logic lru_dirty,

    // control -> datapath
    output logic load_tag[2**way_deg],

    output logic set_valid[2**way_deg],

    // N way(s) take N-1 pseudo LRU bits
    input  logic [2**way_deg-2:0] lru_out,  
    output logic [2**way_deg-2:0] lru_in,
    output logic load_lru,

    output logic dirty_in[2**way_deg],
    output logic load_dirty[2**way_deg],

    output datamux::datamux_sel_t datamux_sel,
    output logic load_data[2**way_deg],

    output addrmux::addrmux_sel_t addrmux_sel
);

localparam s_tag    = 32 - s_offset - s_index;
localparam s_mask   = 2**s_offset;
localparam s_line   = 8*s_mask;
localparam num_sets = 2**s_index;

// ================================ State Transfer Logic ================================

enum logic [1:0] {
    s_idle,   // not used for 0-resp-cycle cache
    s_match,  // may wait for more than one cycle
    s_writeback,
    s_load
} state, next_state;


generate
    if (resp_cycle == 0) begin
        // Use s_match only

        always_comb begin : next_state_logic
            unique case (state)
                s_match: begin
                    if ((mem_read | mem_write) & ~hit) begin
                        if (~lru_dirty) next_state = s_load;
                        else            next_state = s_writeback;
                    end else begin
                        next_state = s_match;
                    end
                end
                s_writeback: next_state = (ca_resp ? s_load : s_writeback);
                s_load:      next_state = (ca_resp ? s_match : s_load);
                default: next_state = state;
            endcase
        end

        always_ff @(posedge clk) begin: next_state_assignment
            if (rst) state <= s_match;
            else     state <= next_state;
        end
        
    end else if (resp_cycle == 1) begin
        // Use both s_idle and s_match (transfer in 1 cycle)

        always_comb begin : next_state_logic
            unique case (state)
                s_idle: next_state = ((mem_read || mem_write) ? s_match : s_idle);
                s_match: begin
                    if (hit) next_state = s_idle;
                    else begin
                        if (~lru_dirty) next_state = s_load;
                        else            next_state = s_writeback;
                    end
                end
                s_writeback: next_state = (ca_resp ? s_load : s_writeback);
                s_load:      next_state = (ca_resp ? s_match : s_load);
                default: next_state = state;
            endcase
        end

        always_ff @(posedge clk) begin: next_state_assignment
            if (rst) state <= s_idle;
            else     state <= next_state;
        end
    end
endgenerate


// ================================ State Operation Logic ================================

generate
    if (way_deg == 1) assign lru_in = ~hit_way;
    else if (way_deg == 2) begin
        always_comb begin
            // 4 way
            lru_in[0] = ~hit_way[1];
            lru_in[1] = (hit_way[1] == 1'b0) ? ~hit_way[0] : lru_out[1];
            lru_in[2] = (hit_way[1] == 1'b1) ? ~hit_way[0] : lru_out[2];
        end
    end else if (way_deg == 3) begin
        always_comb begin
            // 8 way
            lru_in[0] = ~hit_way[2];
            lru_in[1] = (hit_way[2] == 1'b0) ? ~hit_way[1] : lru_out[1];
            lru_in[2] = (hit_way[2] == 1'b1) ? ~hit_way[1] : lru_out[2];
            lru_in[3] = (hit_way[2:1] == 2'b00) ? ~hit_way[0] : lru_out[3];
            lru_in[4] = (hit_way[2:1] == 2'b01) ? ~hit_way[0] : lru_out[4];
            lru_in[5] = (hit_way[2:1] == 2'b10) ? ~hit_way[0] : lru_out[5];
            lru_in[6] = (hit_way[2:1] == 2'b11) ? ~hit_way[0] : lru_out[6];
        end
    end
endgenerate

always_comb begin : state_operation_logic
    
    // Default values
    for (int i = 0; i < 2**way_deg; ++i) begin
        load_tag[i] = 1'b0;
        set_valid[i] = 1'b0;
        dirty_in[i] = 1'b0;
        load_dirty[i] = 1'b0;
        load_data[i] = 1'b0;
    end
    load_lru = 1'b0;
    datamux_sel = datamux::ca_rdata;
    addrmux_sel = addrmux::mem_addr;
    
    mem_resp = 1'b0;
    ca_read = 1'b0;
    ca_write = 1'b0;


    unique case (state)
        s_match: begin

            // hit will ba available sometime after entering this stage

            // Update LRU, for both read and write
            // See above for generation of lru_in                  
            load_lru = hit;     // only update if hit

            // Feed hit data to upstream
            mem_resp = (mem_read | mem_write) & hit;
            // Otherwise, do nothing (keep mem_resp = 0) and wait for state change

            // For mem_write

            // Update dirty bit
            dirty_in[hit_way] = 1'b1;  // set anyway, won't take effect unless load_dirty
            load_dirty[hit_way] = hit & mem_write;

            // Write data
            datamux_sel = datamux::mem_wdata256;  // set anyway, won't take effect unless load_data
            load_data[hit_way] = hit & mem_write;

        end
        s_writeback: begin

            // Sanity check
            // if (~lru_dirty) $fatal("%0t %s %0d: LRU way is not dirty but in s_writeback", $time, `__FILE__, `__LINE__);

            // Writeback the dirty LRU way
            ca_write = 1'b1;
            addrmux_sel = addrmux::tag_addr;

        end
        s_load: begin
            
            // Load data from memory
            ca_read = 1'b1;
            datamux_sel = datamux::ca_rdata;
            load_data[lru_way] = ca_resp;

            // Update tag
            load_tag[lru_way] = 1'b1;

            // Update valid bit
            set_valid[lru_way] = 1'b1;
            
            // Update dirty bit
            dirty_in[lru_way] = 1'b0;
            load_dirty[lru_way] = 1'b1;

            // After the tag and valid bit is updated at posedge, hit and hit_way will be valid

        end
        default: ;
    endcase
end

endmodule : cache_control
