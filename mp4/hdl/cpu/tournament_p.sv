import rv32i_types::*;

module tournament_p #(
    parameter s_pc_idx = 12,
    parameter s_row = 2**s_pc_idx,
    parameter s_pc_offset = 2,
    parameter s_gbhr = 5,
    parameter s_col = 2**s_gbhr,
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

logic g_br_take, l_br_take;

gbht gbht(
    .clk,
    .rst,
    .update,
    .br_en,
    .i_addr,
    .i_addr_update,
    .br_take(g_br_take)
);

lbht lbht(
    .clk,
    .rst,
    .update,
    .br_en,
    .i_addr,
    .i_addr_update,
    .br_take(l_br_take)
);



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
        for (int i=0; i<s_row; i=i+1) begin
            for (int j=0; j<s_col; j=j+1) begin
                predictors[i][j] <= wn;
            end
        end
        gbhr <= s_gbhr{1'b0};
    end else if (update) begin
        predictors[w_row][w_col] <= next_w_state;
        gbhr <= {gbhr[s_gbhr-2:0], br_en};
    end
end

endmodule : tournament_p
