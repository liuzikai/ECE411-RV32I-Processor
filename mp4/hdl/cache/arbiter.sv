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

enum int unsigned {
    /* List of states */
    idle, r_instruction, rw_data
} state, next_states;

function void set_defaults();
    i_data=256'b0;
    i_resp=1'b0;
    d_rdata=256'b0;
    d_resp=1'b0;
    mem_write=1'b0;
    mem_read=1'b0;
    cacheline_adaptor_address=32'b0;
    cacheline_adaptor_wdata=256'b0;
endfunction

always_comb
begin : state_actions
    /* Default output assignments */
    set_defaults();
    /* Actions for each state */
    unique case (state)
        idle:begin
            // do nothing, wait for signal to transition
        end         
        r_instruction:begin
            // we need to supply the address 
            mem_read=i_read;
            cacheline_adaptor_address=i_addr;
            i_data=cacheline_adaptor_rdata;
            i_resp=cacheline_adaptor_resp;
        end 
        rw_data:begin
            // no matter it is a read or write, we need to supply the resp signal
            // also, we need to supply address signal
            d_resp=cacheline_adaptor_resp;
            cacheline_adaptor_address=d_addr;
            if(d_read)begin // if it is d_read
                mem_read=d_read;
                d_rdata=cacheline_adaptor_rdata;
            end 
            else if(d_write) begin  // if it is d_write
                mem_write=d_write;
                cacheline_adaptor_wdata=d_wdata;
            end
        end
    endcase
end

always_comb
begin : next_state_logic
    /* Next state information and conditions (if any)
     * for transitioning between states */
    unique case (state)
        idle:begin
            if(d_read||d_write) next_states=rw_data;
            if(r_instruction) next_states=r_instruction;
            else next_states=idle;
        end
        r_instruction:begin
            if(cacheline_adaptor_resp) next_states=idle;
            else next_states=r_instruction;
        end
        rw_data:begin
            if(cacheline_adaptor_resp) next_states=idle;
            else next_states=rw_data;
        end
    endcase
end

always_ff @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    if (rst) begin
        state <= idle;
    end
    else begin 
        state <= next_states;
    end
end

endmodule:arbiter
