`define BAD_STATE $fatal("%0t %s %0d: Illegal state", $time, `__FILE__, `__LINE__)

module cache_control #(
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

    // cpu <-> cache_control
    input  logic [31:0] mem_address,
    input  logic mem_read,
    input  logic mem_write,
    output logic mem_resp,

    // cache_control <-> cacheline_adapter
    input  logic ca_resp,
    output logic ca_read,
    output logic ca_write,

    // datapath -> control
    input logic hit,
    input logic hit_way,

    input logic lru_way,
    input logic lru_dirty,

    // control -> datapath
    output logic load_tag[2],

    output logic set_valid[2],

    output logic lru_in,
    output logic load_lru,

    output logic dirty_in[2],
    output logic load_dirty[2],

    output datamux::datamux_sel_t datamux_sel,
    output logic load_data[2],

    output addrmux::addrmux_sel_t addrmux_sel
);

// ================================ State Transfer Logic ================================

enum logic [1:0] {
    s_match,
    s_writeback,
    s_load
} state, next_state;

always_comb begin : next_state_logic
    next_state = state;  // default
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
        default: ;
    endcase
end

always_ff @(posedge clk) begin: next_state_assignment
    if (rst) state <= s_match;
    else     state <= next_state;
end

// ================================ State Operation Logic ================================

always_comb begin : state_operation_logic
    
    // Default values
    for (int i = 0; i < 2; ++i) begin
        load_tag[i] = 1'b0;
        set_valid[i] = 1'b0;
        dirty_in[i] = 1'b0;
        load_dirty[i] = 1'b0;
        load_data[i] = 1'b0;
    end
    lru_in = 1'b0;
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
            lru_in = ~hit_way;  // the other is least recently used, set anyway
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
            addrmux_sel = addrmux::addrmux_sel_t'({1'b1, lru_way});

        end
        s_load: begin
            
            // Load data from memory
            ca_read = 1'b1;
            datamux_sel = datamux::ca_rdata;
            load_data[lru_way] = 1'b1;

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
