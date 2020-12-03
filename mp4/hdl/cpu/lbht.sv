import rv32i_types::*;

module lbht #(
    parameter s_bhrt_idx = 5,
    parameter s_bhrt = 2**s_bhrt_idx,
    parameter s_pc_offset = 2,
    parameter s_bhr = 2,
    parameter s_pht = 2**s_bhr
)
(
    input logic clk,
    input logic rst,
    input logic update,
    input logic br_en,
    input rv32i_word raddr,
    input rv32i_word waddr,
    output logic br_take,
    output logic mispred
);

typedef enum logic [1:0] {
    sn,
    wn,
    wt,
    st
} state_t;
state_t w_state, state_in, r_state;

state_t pht [s_pht];
logic [s_bhr-1:0] bhrt [s_bhrt];
logic [s_bhrt_idx-1:0] r_bhrt_idx, w_bhrt_idx;
logic [s_bhr-1:0] r_bhr, w_bhr, bhr_in;

assign w_bhrt_idx = waddr[s_bhrt_idx+s_pc_offset-1:s_pc_offset];
assign r_bhrt_idx = raddr[s_bhrt_idx+s_pc_offset-1:s_pc_offset];

always_comb begin
    w_bhr = bhrt[w_bhrt_idx];
    w_state = pht[w_bhr];
    state_in = w_state;
    mispred = 1'b0;
    if (update) begin
        unique case(w_state)
            sn: begin
                if (br_en) begin
                    state_in = wn;
                    mispred = 1'b1;
                end
                else state_in = sn;
            end
            wn: begin
                if (br_en) begin 
                    state_in = wt;
                    mispred = 1'b1;
                end
                else state_in = sn;
            end
            wt: begin
                if (br_en) state_in = st;
                else begin 
                    state_in = wn;
                    mispred = 1'b1;
                end
            end
            st: begin
                if (br_en) state_in = st;
                else begin 
                    state_in = wt;
                    mispred = 1'b1;
                end
            end
            default: ;
        endcase
    end
    bhr_in = {bhrt[w_bhrt_idx][s_bhr-2:0], br_en};
    r_bhr = (update & (w_bhrt_idx == r_bhrt_idx)) ? bhr_in : bhrt[r_bhrt_idx];
    r_state = (update & (w_bhr == r_bhr)) ? state_in : pht[r_bhr];
    br_take = 1'b0;
    unique case(r_state)
        sn, wn: br_take = 1'b0;
        st, wt: br_take = 1'b1;
        default: ;
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i=0; i<s_pht; i=i+1) begin
            pht[i] <= wn;
        end
        for (int j=0; j<s_bhrt; j=j+1) begin
            bhrt[j] <= {s_bhr{1'b0}};
        end
    end else if (update) begin
        pht[w_bhr] <= state_in;
        bhrt[w_bhrt_idx] <= bhr_in;
    end
end

endmodule : lbht
