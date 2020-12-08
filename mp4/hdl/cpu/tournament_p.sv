import rv32i_types::*;

module tournament_p #(
    parameter s_row_idx = 4,
    parameter s_row = 2**s_row_idx,
    parameter s_pc_offset = 3,
    parameter bp_type = 0
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

typedef enum logic [1:0]  {
    sl,
    wl,
    wg,
    sg
} state_t;

typedef struct packed {
    logic [s_row_idx-1:0] row;
    state_t state;
    logic br_take;
} state_pkg_t;

state_t state_in;

state_t state_table[s_row];
logic g_br_take, l_br_take, t_br_take;
logic g_mispred, l_mispred, t_mispred;
state_pkg_t state_pkg_if, state_pkg_id, state_pkg_ex;

generate
    if (bp_type == 0) begin
        assign br_take = t_br_take;
        assign mispred = t_mispred;
    end else if (bp_type == 1) begin
        assign br_take = l_br_take;
        assign mispred = l_mispred;
    end else if (bp_type == 2) begin
        assign br_take = g_br_take;
        assign mispred = g_mispred;
    end else begin
        assign br_take = 0;
        assign mispred = br_en;
    end
endgenerate

always_comb begin
    state_pkg_if.row = addr[s_row_idx+s_pc_offset-1:s_pc_offset];
    state_pkg_if.state = (update & (state_pkg_if.row == state_pkg_ex.row)) ? state_in : state_table[state_pkg_if.row];
    state_pkg_if.br_take = 1'b0;
    unique case(state_pkg_if.state)
        sl, wl: state_pkg_if.br_take = l_br_take;
        sg, wg: state_pkg_if.br_take = g_br_take;
        default: ;
    endcase
end

assign t_br_take = state_pkg_if.br_take;

gbht gbht(
    .br_take(g_br_take),
    .mispred(g_mispred),
    .*
);

lbht lbht(
    .br_take(l_br_take),
    .mispred(l_mispred),
    .*
);

always_comb begin : assign_mispred
    t_mispred = 1'b0;
    unique case(state_pkg_ex.state)
        sl, wl: t_mispred = l_mispred;
        sg, wg: t_mispred = g_mispred;
        default: ;
    endcase
    state_in = state_pkg_ex.state;
    if (update) begin
        if (l_mispred ^ g_mispred) begin
            unique case(state_pkg_ex.state)
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
        state_table[state_pkg_ex.row] <= state_in;
    end
end

always_ff @(posedge clk) begin
    state_pkg_id <= (stall_id) ? state_pkg_id : state_pkg_if;
    state_pkg_ex <= (stall_ex) ? state_pkg_ex : state_pkg_id;
end

endmodule : tournament_p
