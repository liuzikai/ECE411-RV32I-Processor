module arbiter( 
    input logic clk,
    input logic rst,
    // signal between i_cache and the arbiter
    input logic i_read,
    input logic [31:0] i_addr,
    output logic [255:0] i_data,
    output logic i_resp,

    // signal between d_cache and the arbiter
    input logic d_read,
    input logic d_write,
    input logic [255:0] d_wdata,
    input logic [31:0] d_addr,
    output logic [255:0] d_rdata,
    output logic d_resp,

    // signal between cacheline adaptor and the arbiter
    input logic ca_resp,
    output logic ca_write,
    output logic ca_read,
    output logic [31:0] ca_addr,
    input logic[255:0] ca_rdata,
    output logic[255:0] ca_wdata
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
    ca_write=1'b0;
    ca_read=1'b0;
    ca_addr=32'b0;
    ca_wdata=256'b0;
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
            ca_read=i_read;
            ca_addr=i_addr;
            i_data=ca_rdata;
            i_resp=ca_resp;
        end 
        rw_data:begin
            // no matter it is a read or write, we need to supply the resp signal
            // also, we need to supply address signal
            d_resp=ca_resp;
            ca_addr=d_addr;
            if(d_read)begin // if it is d_read
                ca_read=d_read;
                d_rdata=ca_rdata;
            end 
            else if(d_write) begin  // if it is d_write
                ca_write=d_write;
                ca_wdata=d_wdata;
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
            else if(i_read) next_states=r_instruction;
            else next_states=idle;
        end
        r_instruction:begin
            if(ca_resp) next_states=idle;
            else next_states=r_instruction;
        end
        rw_data:begin
            if(ca_resp) next_states=idle;
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