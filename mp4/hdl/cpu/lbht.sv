import rv32i_types::*;

module lbht #(
    parameter s_pc_idx = 12,
    parameter s_row = 2**s_pc_idx,
    parameter s_pc_offset = 2,
    parameter s_bhr = 2,
    parameter s_col = 2**s_bhr,
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
} state, next_state;

logic [1:0] predictors [s_row][s_col];
logic [s_bhr-1:0] bhr [s_row];
logic [s_pc_idx-1:0] r_row, w_row;
logic [s_bhr-1:0] r_col, w_col;

assign r_row = i_addr[s_pc_idx+s_pc_offset-1:s_pc_offset];
assign w_row = i_addr_update[s_pc_idx+s_pc_offset-1:s_pc_offset];
assign r_col = bhr[r_row];
assign w_col = bhr[w_row];

always_comb begin : assign_br_take
    br_take = 1'b0;
    unique case(state)
        sn, wn: br_take = 1'b0;
        st, wt: br_take = 1'b1;
        default: ;
    endcase
end

always_comb begin : next_state_logic
    next_state = state;
    if (update) begin
        unique case(state)
            sn: begin
                if (br_en) next_state = wn;
                else next_state = sn;
            end
            wn: begin
                if (br_en) next_state = wt;
                else next_state = sn;
            end
            wt: begin
                if (br_en) next_state = st;
                else next_state = wn;
            end
            st: begin
                if (br_en) next_state = st;
                else next_state = wt;
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
            bhr[i] <= s_bhr{1'b0};
        end
    end else if (update) begin
        predictors[w_row][w_col] <= next_state;
        bhr[w_row] <= {bhr[w_row][s_bhr-2:0], br_en};
    end else begin
        for (int i=0; i<s_row; i=i+1) begin
            for (int j=0; j<s_col; j=j+1) begin
                predictors[i][j] <= predictors[i][j];
            end
            bhr[i] <= bhr[i];
        end
    end
end

endmodule : lbht
