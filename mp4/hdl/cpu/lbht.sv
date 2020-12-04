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
    input logic stall_id,
    input logic stall_ex,
    input logic update,
    input logic br_en,
    input rv32i_word addr,
    output logic br_take,
    output logic mispred
);

typedef enum logic [1:0] {
    sn,
    wn,
    wt,
    st
} state_t;

typedef struct packed {
    logic [s_bhrt_idx-1:0] bhrt_idx;
    logic [s_gbhr-1:0] bhr;
    state_t state;
    logic br_take;
} state_pkg_t;

state_t state_in;

state_t pht [s_pht];
logic [s_bhr-1:0] bhrt [s_bhrt];
logic [s_bhr-1:0] bhr_in;
state_pkg_t state_pkg_if, state_pkg_id, state_pkg_ex;

always_comb begin
    state_pkg_if.bhrt_idx = addr[s_row_idx+s_pc_offset-1:s_pc_offset];
    state_pkg_if.bhr = (update & (state_pkg_ex.bhrt_idx == state_pkg_if.bhrt_idx)) ? bhr_in : bhrt[state_pkg_if.bhrt_idx];
    state_pkg_if.state = (update & (state_pkg_if.bhr == state_pkg_ex.bhr)) ? state_in : pht[state_pkg_if.bhr];
    unique case(state_pkg_if.state)
        sn, wn: state_pkg_if.br_take = 1'b0;
        st, wt: state_pkg_if.br_take = 1'b1;
        default: state_pkg_if.br_take = 1'b0;
    endcase
end

assign bhr_in = {state_pkg_ex.bhr[s_bhr-2:0], br_en};
assign br_take = state_pkg_if.br_take;

always_comb begin
    state_in = state_pkg_ex.state;
    mispred = 1'b0;
    if (update) begin
        unique case(state_pkg_ex.state)
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
        pht[state_pkg_ex.bhr] <= state_in;
        bhrt[state_pkg_ex.bhrt_idx] <= bhr_in;
    end
end

always_ff @(posedge clk) begin
    state_pkg_id <= (stall_id) ? state_pkg_id : state_pkg_if;
    state_pkg_ex <= (stall_ex) ? state_pkg_ex : state_pkg_id;
end

endmodule : lbht
