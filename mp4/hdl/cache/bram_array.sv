/* A special register array specifically for your
   data arrays. This module supports a write mask to
   help you update the values in the array. */

module bram_array #(
    parameter s_index = 3,
    parameter width = 1
)
(
    clk,
    load,
    index,
    datain,
    dataout
);

localparam num_sets = 2**s_index;

input clk;
input load;
input [s_index-1:0] index;
input [width-1:0] datain;
output logic [width-1:0] dataout;

logic [width-1:0] data [num_sets-1:0];

always_ff @(posedge clk) begin
    if (load) data[index] <= datain;
end

always_ff @(posedge clk) begin
    dataout = data[index];
end

endmodule : bram_array
