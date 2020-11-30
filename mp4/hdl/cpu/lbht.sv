import rv32i_types::*;

module lbht #(
    parameter s_pc_idx = 12,
    parameter s_pc_entry = 2**s_pc_idx,
    parameter s_pc_offset = 2,
    parameter s_bhr = 2,
    parameter s_pht = 2**s_bhr,
)
(
    input logic clk,
    input logic rst,
    input logic update,
    input logic br_en,
    input rv32i_word i_addr,
    input rv32i_word i_addr_update,
    output logic br_take
);

enum logic [1:0] {
    sn,
    wn,
    wt,
    st
} w_state, next_w_state, r_state;

logic [1:0] pht [s_pht];
logic [s_bhr-1:0] bhrt [s_pc_entry];
logic [s_pc_idx-1:0] r_pc, w_pc;
logic [s_bhr-1:0] r_bhr, w_bhr;

assign r_pc = i_addr[s_pc_idx+s_pc_offset-1:s_pc_offset];
assign w_pc = i_addr_update[s_pc_idx+s_pc_offset-1:s_pc_offset];
assign r_bhr = bhrt[r_pc];
assign w_bhr = bhrt[w_pc];
assign r_state = pht[r_bhr];
assign w_state = pht[w_bhr];

always_comb begin : assign_br_take
    br_take = 1'b0;
    unique case(r_state)
        sn, wn: br_take = 1'b0;
        st, wt: br_take = 1'b1;
        default: ;
    endcase
end

always_comb begin : next_w_state_logic
    next_w_state = w_state;
    if (update) begin
        unique case(w_state)
            sn: begin
                if (br_en) next_w_state = wn;
                else next_w_state = sn;
            end
            wn: begin
                if (br_en) next_w_state = wt;
                else next_w_state = sn;
            end
            wt: begin
                if (br_en) next_w_state = st;
                else next_w_state = wn;
            end
            st: begin
                if (br_en) next_w_state = st;
                else next_w_state = wt;
            end
            default: ;
        endcase
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i=0; i<s_pht; i=i+1) begin
            pht[i] <= wn;
        end
        for (int j=0; j<s_pc_entry; j=j+1) begin
            bhrt[j] <= s_bhr{1'b0};
        end
    end else if (update) begin
        pht[w_bhr] <= next_w_state;
        bhrt[w_pc] <= {bhr[w_pc][s_bhr-2:0], br_en};
    end
end

endmodule : lbht
