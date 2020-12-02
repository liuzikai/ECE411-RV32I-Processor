module cache_array #(
    parameter s_index = 3,
    parameter width = 1,
    parameter resp_cycle = 0
)
(
    clk,
    rst,
    load,
    rindex,
    windex,
    datain,
    dataout
);

localparam num_sets = 2**s_index;

input clk;
input rst;
input load;
input [s_index-1:0] rindex;
input [s_index-1:0] windex;
input [width-1:0] datain;
output logic [width-1:0] dataout;

logic [width-1:0] data [num_sets-1:0] /* synthesis ramstyle = "logic" */;

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < num_sets; ++i) data[i] <= '0;
    end else if (load) begin
        data[windex] <= datain;
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

endmodule : cache_array
