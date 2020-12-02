import rv32i_types::*;

module tournament_p #(
    parameter s_row_idx = 5,
    parameter s_row = 2**s_row_idx,
    parameter s_pc_offset = 2
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

typedef enum logic [1:0]  {
    sl,
    wl,
    wg,
    sg
} state_t;
state_t r_state, w_state, state_in;

state_t state_table[s_row];
logic [s_row_idx-1:0] r_row, w_row;
logic g_r_br_take, l_r_br_take, g_w_br_take, l_w_br_take;
logic g_mispred, l_mispred;

assign w_row = waddr[s_row_idx+s_pc_offset-1:s_pc_offset];
assign r_row = raddr[s_row_idx+s_pc_offset-1:s_pc_offset];

assign w_state = state_table[w_row];
assign r_state = (update & (r_row == w_row)) ? state_in : state_table[r_row];

gbht gbht(
    .clk,
    .rst,
    .update,
    .br_en,
    .raddr,
    .waddr,
    .br_take(g_br_take),
    .mispred(g_mispred)
);

lbht lbht(
    .clk,
    .rst,
    .update,
    .br_en,
    .raddr,
    .waddr,
    .br_take(l_br_take),
    .mispred(l_mispred)
);



always_comb begin : assign_br_take
    br_take = 1'b0;
    unique case(r_state)
        sl, wl: br_take = l_br_take;
        sg, wg: br_take = g_br_take;
        default: ;
    endcase
end

always_comb begin : assign_mispred
    mispred = 1'b0;
    unique case(w_state)
        sl, wl: mispred = l_mispred;
        sg, wg: mispred = g_mispred;
        default: ;
    endcase
end

always_comb begin : state_in_logic
    state_in = w_state;
    if (update) begin
        if (l_mispred ^ g_mispred) begin
            unique case(w_state)
                sl: begin
                    if (l_mispred) state_in = wl;
                    else state_in = sl;
                end
                wl: begin
                    if (l_mispred) state_in = wg;
                    else state_in = sl;
                end
                wg: begin
                    if (g_mispred) state_in = wl;
                    else state_in = sg;
                end
                sg: begin
                    if (g_mispred) state_in = wg;
                    else state_in = sg;
                end
                default: ;
            endcase
        end
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i=0; i<s_row; i=i+1) begin
            state_table[i] <= wl;
        end
    end else if (update) begin
        state_table[w_row] <= state_in;
    end
end

endmodule : tournament_p
