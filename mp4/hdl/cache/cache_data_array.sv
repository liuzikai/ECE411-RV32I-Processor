/* A special register array specifically for your
   data arrays. This module supports a write mask to
   help you update the values in the array. */

module cache_data_array #(
    parameter s_offset = 5,
    parameter s_index = 3,
    parameter resp_cycle = 0
)
(
    clk,
    rst,
    write_en,
    rindex,
    windex,
    datain,
    dataout
);

localparam s_mask   = 2**s_offset;
localparam s_line   = 8*s_mask;
localparam num_sets = 2**s_index;

input clk;
input rst;
input [s_mask-1:0] write_en;
input [s_index-1:0] rindex;
input [s_index-1:0] windex;
input [s_line-1:0] datain;
output logic [s_line-1:0] dataout;

logic [s_line-1:0] data [num_sets-1:0] /* synthesis ramstyle = "logic" */;

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < num_sets; ++i) data[i] <= '0;
    end else begin
        for (int i = 0; i < s_mask; i++) begin
            data[windex][8*i +: 8] <= write_en[i] ? datain[8*i +: 8] :
                                                    data[windex][8*i +: 8];
        end
    end
end

generate
    if (resp_cycle == 0) begin
        always_comb begin
            dataout = data[rindex];
        end 
    end else begin
        always_ff @(posedge clk) begin
            dataout <= data[rindex];
        end
    end
endgenerate

endmodule : cache_data_array
