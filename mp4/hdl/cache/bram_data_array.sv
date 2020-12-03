/* A special register array specifically for your
   data arrays. This module supports a write mask to
   help you update the values in the array. */

module bram_data_array #(
    parameter s_offset = 5,
    parameter s_index = 3
)
(
    clk,
    load,
    index,
    datain,
    dataout
);

localparam s_mask   = 2**s_offset;
localparam s_line   = 8*s_mask;
localparam num_sets = 2**s_index;

input clk;
input load;
input [s_index-1:0] index;
input [s_line-1:0] datain;
output logic [s_line-1:0] dataout;

logic [s_line-1:0] data [num_sets-1:0] /* synthesis ramstyle = "M4K" */;

always_ff @(posedge clk) begin
    if (load) data[index] <= datain;
end

always_ff @(posedge clk) begin
    dataout = data[index];
end

endmodule : bram_data_array
