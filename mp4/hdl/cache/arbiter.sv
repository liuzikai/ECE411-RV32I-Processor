import rv32i_types::*;
module arbiter( 
    input clk,
    input rst,
    // signal between i_cache and the arbiter
    input i_read,
    input logic [31:0] i_addr,
    output logic [255:0] i_data,
    output i_resp,

    // signal between d_cache and the arbiter
    input d_read,
    input d_write,
    input logic [255:0] d_wdata,
    input logic [31:0] d_addr,
    output logic [255:0] d_rdata,
    output d_resp,

    // signal between cacheline adaptor and the arbiter
    input cacheline_adaptor_resp,
    output mem_write,
    output mem_read,
    output logic [31:0] cacheline_adaptor_address,
    input logic[255:0] cacheline_adaptor_rdata,
    output logic[255:0] cacheline_adaptor_wdata,
);

// function void set_defaults();
//     i_data=256'b0;
//     i_resp=1'b0;
//     d_rdata=256'b0;
//     d_resp=1'b0;
//     mem_write=1'b0;
//     mem_read=1'b0;
//     cacheline_adaptor_address=32'b0;
//     cacheline_adaptor_wdata=256'b0;
// endfunction

always_comb
begin: 
    /* Default output assignments */
    // set_defaults();
    /* Actions for each state */
    if(d_read|| d_write)begin // if it is d_read
        i_data = 256'b0;
        i_resp = 1'b0;
        mem_read = d_read;
        mem_write = d_write;
        d_rdata = cacheline_adaptor_rdata;
        d_resp = cacheline_adaptor_resp;
        cacheline_adaptor_address = d_addr;
        cacheline_adaptor_wdata = d_wdata;
        end
    else begin
        i_data = cacheline_adaptor_rdata;
        i_resp = cacheline_adaptor_resp;
        mem_read = i_read;
        mem_write = 1'b0;
        d_rdata=256'b0;
        d_resp=1'b0;
        cacheline_adaptor_address = i_addr;
        cacheline_adaptor_wdata=256'b0;
    end
end

endmodule:arbiter
