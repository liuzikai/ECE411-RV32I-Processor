import rv32i_types::*;

module gbht #(
    parameter s_row_idx = 5,
    parameter s_row = 2**s_row_idx,
    parameter s_pc_offset = 2,
    parameter s_gbhr = 5,
    parameter s_col = 2**s_gbhr
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
    logic [s_row_idx-1:0] row;
    logic [s_gbhr-1:0] gbhr;
    state_t state;
    logic br_take;
} state_pkg_t;

state_t state_in;

state_t pht [s_row][s_col];
logic [s_gbhr-1:0] gbhr, gbhr_in;
state_pkg_t state_pkg_if, state_pkg_id, state_pkg_ex;

always_comb begin
    state_pkg_if.row = addr[s_row_idx+s_pc_offset-1:s_pc_offset];
    state_pkg_if.gbhr = gbhr;
    state_pkg_if.state = pht[state_pkg_if.row][state_pkg_if.gbhr];
    unique case(state_pkg_if.state)
        sn, wn: state_pkg_if.br_take = 1'b0;
        st, wt: state_pkg_if.br_take = 1'b1;
        default: state_pkg_if.br_take = 1'b0;
    endcase
end

assign gbhr_in = {gbhr[s_gbhr-2:0], br_en};
assign br_take = state_pkg_if.br_take;

always_comb begin : state_in_logic
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
        for (int i=0; i<s_row; i=i+1) begin
            for (int j=0; j<s_col; j=j+1) begin
                pht[i][j] <= wn;
            end
        end
        gbhr <= {s_gbhr{1'b0}};
    end else if (update) begin
        pht[state_pkg_ex.row][state_pkg_ex.ghbr] <= state_in;
        gbhr <= gbhr_in;
    end
end

always_ff @(posedge clk) begin
    state_pkg_id <= (stall_id) ? state_pkg_id : state_pkg_if;
    state_pkg_ex <= (stall_ex) ? state_pkg_ex : state_pkg_id;
end

endmodule : gbht
