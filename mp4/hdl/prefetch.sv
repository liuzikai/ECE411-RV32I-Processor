module prefetch(
    input logic clk,
    input logic rst,
    // design a generic prefetcher such that it does not know whether it is 
    // interfacing with data cache or instruction cache,
    // so it should two instance for each cache to prefecth
    // it is only handling the reading prefetch
    // think this module as sitting between CPU and cache
    
    // interface with the CPU 
    input logic [31:0] mem_addr_from_cpu,    // the address for last memory access
    input logic mem_read_from_cpu,
    output logic cpu_resp,
    // interface with the cache
    output logic [31:0] mem_addr_out,
    output logic cache_read,
    input  logic cache_resp
    
);
// during normal read we just pass through
// use register to store the address
enum int unsigned {
    /* List of states */
    prefetch, normal_read
} state, next_state;
logic [31:0] mem_addr_to_prefetch_out;
register addr_to_prefetch(
    .clk(clk),
    .rst(rst),
    .load(mem_read_from_cpu && state==normal_read), // prefetch && a new read come
    .in(mem_addr_from_cpu+32'h0020),
    .out(mem_addr_to_prefetch_out)
);

// TODO: potential issue, blocking the desired memory access from CPU if the next line access 
// is not the correct one

function void set_defaults();
    cache_read=mem_read_from_cpu;
    cpu_resp=cache_resp;
    mem_addr_out=mem_addr_from_cpu;
endfunction

always_comb
begin : state_actions
    set_defaults();
    case(state)
        normal_read:begin
            // cache_read=mem_read_from_cpu;
            // let CPU signal go through, do nothing here
        end
        prefetch:begin
            cache_read=1'b1;
            // cpu should not be aware of the read the data
            // so it must be set to 0 all the time
            cpu_resp=1'b0;
            mem_addr_out=mem_addr_to_prefetch_out;
        end
    endcase
end

always_comb
begin : next_state_logic
    next_state=state;
    unique case(state)
        normal_read: begin
            if(mem_read_from_cpu && cache_resp)begin // after reading the current line, read next line
                next_state=prefetch;
            end
            else begin
                next_state=normal_read;
            end
        end
        prefetch:begin
            if(cache_resp)begin
                next_state=normal_read;
            end
            else begin
                next_state=prefetch;
            end
        end
    endcase
end

always_ff @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    if(rst)
        state=normal_read;
    else
        state=next_state;
end

endmodule: prefetch