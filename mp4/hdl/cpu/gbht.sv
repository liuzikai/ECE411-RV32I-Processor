import rv32i_types::*;

module gbht #(
    parameter s_row_idx = 12,
    parameter s_row = 2**s_row_idx,
    parameter s_pc_offset = 2,
    parameter s_gbhr = 5,
    parameter s_col = 2**s_gbhr,
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

enum logic [1:0] {
    sn,
    wn,
    wt,
    st
} r_state, w_state, state_in;

logic [1:0] pht [s_row][s_col];
logic [s_gbhr-1:0] gbhr, gbhr_in;
logic [s_row_idx-1:0] r_row, w_row;
logic [s_gbhr-1:0] r_col, w_col;

assign w_row = waddr[s_row_idx+s_pc_offset-1:s_pc_offset];
assign r_row = raddr[s_row_idx+s_pc_offset-1:s_pc_offset];

assign gbhr_in = {gbhr[s_gbhr-2:0], br_en};
assign w_col = gbhr;
assign r_col = (update) ? gbhr_in : gbhr;

assign w_state = pht[w_row][w_col];
assign r_state = (update & (r_row == w_row) & (r_col == w_col)) ? state_in : pht[r_row][r_col];

always_comb begin : assign_br_take
    br_take = 1'b0;
    unique case(r_state)
        sn, wn: br_take = 1'b0;
        st, wt: br_take = 1'b1;
        default: ;
    endcase
end

always_comb begin : state_in_logic
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
end

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i=0; i<s_row; i=i+1) begin
            for (int j=0; j<s_col; j=j+1) begin
                pht[i][j] <= wn;
            end
        end
        gbhr <= s_gbhr{1'b0};
    end else if (update) begin
        pht[w_row][w_col] <= state_in;
        gbhr <= gbhr_in;
    end
end

endmodule : gbht
