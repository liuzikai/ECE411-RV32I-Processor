import rv32i_types::*;

module mp4 #(
    parameter l1_i_cache_s_index = 3,

    parameter use_l2_i_cache = 1,
    parameter l2_i_cache_s_index = 6,
    parameter l2_i_cache_way_deg = 2,

    parameter use_i_prefetcher = 1,

    parameter l1_d_cache_s_index = 3,

    parameter use_l2_d_cache = 0,
    parameter l2_d_cache_s_index = 9,
    parameter l2_d_cache_way_deg = 3,

    parameter use_d_prefetcher = 0,

    parameter bp_type = 0
)
(
    input clk,
    input rst,

    output rv32i_word       mem_addr,
    input  logic [63:0]     mem_rdata,
    output logic [63:0]     mem_wdata,
    output logic            mem_read,
    output logic            mem_write,
    input  logic            mem_resp
);

// CPU <-> L1 I-Cache & I-Bus-Adapter
rv32i_word i_addr;
rv32i_word i_rdata;
logic      i_read;
logic      i_resp;

// CPU <-> L1 D-Cache & D-Bus-Adapter
rv32i_word  d_addr;
rv32i_word  d_rdata;
rv32i_word  d_wdata;
logic [3:0] d_byte_enable;
logic       d_read;
logic       d_write;
logic       d_resp;

// I-Bus-Adapter <-> L1 I-Cache
logic [255:0] i_rdata256;

// D-Bus-Adapter <-> L1 D-Cache
logic [255:0] d_wdata256;
logic [255:0] d_rdata256;
logic [31:0]  d_byte_enable256;

// L1 I-Cache <-> prefetch OR L2 cache OR memory
logic [255:0] i_rdata256_l1_down;
rv32i_word    i_addr_l1_down;
logic         i_resp_l1_down;
logic         i_read_l1_down;

// prefetch <-> L1 I-Cache
rv32i_word    i_addr_prefetch_up;
logic         i_read_prefetch_up;
logic         i_resp_prefetch_up;

// prefetch <-> L2 I-Cache
rv32i_word    i_addr_prefetch_down;
logic         i_read_prefetch_down;
logic         i_resp_prefetch_down;

// L2 I-Cache <-> prefetch OR L1 I-Cache
logic [255:0] i_rdata256_l2_up;
rv32i_word    i_addr_l2_up;
logic         i_read_l2_up;
logic         i_resp_l2_up;

// L2 I-Cache <-> memory
logic [255:0] i_rdata256_l2_down;
rv32i_word    i_addr_l2_down;
logic         i_read_l2_down;
logic         i_resp_l2_down;

// prefetch <-> L1 I-Cache
rv32i_word    d_addr_prefetch_up;
logic         d_read_prefetch_up;
logic         d_resp_prefetch_up;

// prefetch <-> L2 I-Cache
rv32i_word    d_addr_prefetch_down;
logic         d_read_prefetch_down;
logic         d_resp_prefetch_down;

// L1 D-Cache <-> L2 D-Cache OR memory
rv32i_word    d_addr_l1_down;
logic [255:0] d_wdata256_l1_down;
logic [255:0] d_rdata256_l1_down;
logic         d_read_l1_down;
logic         d_write_l1_down;
logic         d_resp_l1_down;

// L2 D-Cache <-> L1 D-Cache
rv32i_word    d_addr_l2_up;
logic [255:0] d_wdata256_l2_up;
logic [255:0] d_rdata256_l2_up;
logic         d_read_l2_up;
logic         d_write_l2_up;
logic         d_resp_l2_up;

// L2 D-Cache <-> memory
rv32i_word    d_addr_l2_down;
logic [255:0] d_wdata256_l2_down;
logic [255:0] d_rdata256_l2_down;
logic         d_read_l2_down;
logic         d_write_l2_down;
logic         d_resp_l2_down;


// L1 I-Cache OR L2 I-Cache <-> Arbiter
logic i_a_read;
logic [31:0]  i_a_addr;
logic [255:0] i_a_rdata;
logic i_a_resp;

// L1 D-Cache OR L2 D-Cache <-> Arbiter
logic d_a_write;
logic d_a_read;
logic [31:0]  d_a_addr;
logic [255:0] d_a_rdata;
logic [255:0] d_a_wdata;
logic d_a_resp;

// Arbiter <-> Cacheline Adaptor
logic ca_write;
logic ca_read;
logic [31:0]  ca_addr;
logic [255:0] ca_rdata;
logic [255:0] ca_wdata;
logic ca_resp;

// Signal used in instruction caches
generate
    if (use_l2_i_cache) begin

        // If we use instruction L2 cache
        always_comb begin
            i_rdata256_l1_down = i_rdata256_l2_up;
            i_a_addr           = i_addr_l2_down;
            i_rdata256_l2_down = i_a_rdata;
            i_a_read           = i_read_l2_down;
            i_resp_l2_down     = i_a_resp;
        end

        if (use_i_prefetcher) begin

            // If we use the prefetch for instruction between L1 and L2
            always_comb begin
                i_addr_prefetch_up   = i_addr_l1_down;
                i_read_prefetch_up   = i_read_l1_down;
                i_resp_l1_down       = i_resp_prefetch_up;
                i_addr_l2_up         = i_addr_prefetch_down;
                i_read_l2_up         = i_read_prefetch_down;
                i_resp_prefetch_down = i_resp_l2_up;
            end

        end else begin

            // If we don't use the prefetch for instruction between L1 and L2
            always_comb begin
                i_addr_l2_up    = i_addr_l1_down;
                i_read_l2_up    = i_read_l1_down;
                i_resp_l1_down  = i_resp_l2_up;
            end

        end

    end else begin

        // If we don't use L2 instruction cache
        always_comb begin
            i_a_addr           = i_addr_l1_down;
            i_rdata256_l1_down = i_a_rdata;
            i_a_read           = i_read_l1_down;
            i_resp_l1_down     = i_a_resp;
        end
    end
endgenerate


// For data caches
generate
    if (use_l2_d_cache) begin

        // If we use L2 cache
        always_comb begin
            // d_addr_l2_up       = d_addr_l1_down;
            d_wdata256_l2_up   = d_wdata256_l1_down;
            d_rdata256_l1_down = d_rdata256_l2_up;
            // d_read_l2_up       = d_read_l1_down;
            d_write_l2_up      = d_write_l1_down;
            // d_resp_l1_down     = d_resp_l2_up;

            d_a_addr           = d_addr_l2_down;
            d_a_wdata          = d_wdata256_l2_down;
            d_rdata256_l2_down = d_a_rdata;
            d_a_read           = d_read_l2_down;
            d_a_write          = d_write_l2_down;
            d_resp_l2_down     = d_a_resp;
        end

        if (use_d_prefetcher) begin

            // If we use the prefetch for data between L1 and L2
            always_comb begin
                d_addr_prefetch_up   = d_addr_l1_down;
                d_read_prefetch_up   = d_read_l1_down;
                d_resp_l1_down       = d_resp_prefetch_up;
                d_addr_l2_up         = d_addr_prefetch_down;
                d_read_l2_up         = d_read_prefetch_down;
                d_resp_prefetch_down = d_resp_l2_up;
            end

        end else begin

            // If we don't use the prefetch for data between L1 and L2
            always_comb begin
                d_addr_l2_up    = d_addr_l1_down;
                d_read_l2_up    = d_read_l1_down;
                d_resp_l1_down  = d_resp_l2_up;
            end

        end
    end else begin

        // If we don't use L2 data cache
        always_comb begin
            d_a_addr           = d_addr_l1_down;
            d_a_wdata          = d_wdata256_l1_down;
            d_rdata256_l1_down = d_a_rdata;
            d_a_read           = d_read_l1_down;
            d_a_write          = d_write_l1_down;
            d_resp_l1_down     = d_a_resp;
        end
    end
endgenerate

cpu #(.bp_type(bp_type)) cpu(
    .*
);

bus_adapter i_bus_adapter (
    // CPU side
    .address(i_addr),
    .mem_wdata('X),
    .mem_rdata(i_rdata),
    .mem_byte_enable(4'b111),
    // L1 I-Cache size
    .mem_wdata256(),
    .mem_rdata256(i_rdata256),
    .mem_byte_enable256()
);


cache #(5, l1_i_cache_s_index, 1, 0) l1_i_cache (
    .clk(clk),
    .rst(rst),
    // I-Bus-Adapter side
    .mem_addr(i_addr),
    .mem_wdata256('X),
    .mem_rdata256(i_rdata256),
    .mem_byte_enable256(32'hFFFFFFFF),
    .mem_read(i_read),
    .mem_write(1'b0),
    .mem_resp(i_resp),
    // Arbiter side
    .ca_wdata(),
    .ca_rdata(i_rdata256_l1_down),
    .ca_addr(i_addr_l1_down),
    .ca_resp(i_resp_l1_down),
    .ca_read(i_read_l1_down),
    .ca_write()
);

generate
    if (use_i_prefetcher) begin
        prefetch instruction_l1_l2_prefetch (
            .clk(clk),
            .rst(rst),
            // interface with the CPU 
            .mem_addr_from_cpu(i_addr_prefetch_up),   
            .mem_read_from_cpu(i_read_prefetch_up),
            .cpu_resp(i_resp_prefetch_up),
            // upterface with the cache
            .mem_addr_out(i_addr_prefetch_down),
            .cache_read(i_read_prefetch_down),
            .cache_resp(i_resp_prefetch_down)
        );
    end
endgenerate

generate
    if (use_l2_i_cache) begin
        cache #(5, l2_i_cache_s_index, l2_i_cache_way_deg, 1) l2_i_cache (
            .clk(clk),
            .rst(rst),
            // I-Bus-Adapter side
            .mem_addr(i_addr_l2_up),
            .mem_wdata256('X),
            .mem_rdata256(i_rdata256_l2_up),
            .mem_byte_enable256(32'hFFFFFFFF),
            .mem_read(i_read_l2_up),
            .mem_write(1'b0),
            .mem_resp(i_resp_l2_up),
            // Arbiter side
            .ca_wdata(),
            .ca_rdata(i_rdata256_l2_down),
            .ca_addr(i_addr_l2_down),
            .ca_resp(i_resp_l2_down),
            .ca_read(i_read_l2_down),
            .ca_write()
        );
    end
endgenerate

bus_adapter d_bus_adapter (
    // CPU side
    .address(d_addr),
    .mem_wdata(d_wdata),
    .mem_rdata(d_rdata),
    .mem_byte_enable(d_byte_enable),
    // L1 D-Cache size
    .mem_wdata256(d_wdata256),
    .mem_rdata256(d_rdata256),
    .mem_byte_enable256(d_byte_enable256)
);

cache #(5, l1_d_cache_s_index, 1, 0) l1_d_cache(
    .clk(clk),
    .rst(rst),
    // D-Bus-Adapter side
    .mem_addr(d_addr),
    .mem_wdata256(d_wdata256),
    .mem_rdata256(d_rdata256),
    .mem_byte_enable256(d_byte_enable256),
    .mem_read(d_read),
    .mem_write(d_write),
    .mem_resp(d_resp),
    // L2 D-Cache side
    .ca_wdata(d_wdata256_l1_down),
    .ca_rdata(d_rdata256_l1_down),
    .ca_addr(d_addr_l1_down),
    .ca_resp(d_resp_l1_down),
    .ca_read(d_read_l1_down),
    .ca_write(d_write_l1_down)
    // NOTE: no byte_enable
);

generate
    if (use_d_prefetcher) begin
        prefetch instruction_l1_l2_prefetch (
            .clk(clk),
            .rst(rst),
            // interface with the CPU 
            .mem_addr_from_cpu(d_addr_prefetch_up),   
            .mem_read_from_cpu(d_read_prefetch_up),
            .cpu_resp(d_resp_prefetch_up),
            // upterface with the cache
            .mem_addr_out(d_addr_prefetch_down),
            .cache_read(d_read_prefetch_down),
            .cache_resp(d_resp_prefetch_down)
        );
    end
endgenerate

generate
    if (use_l2_d_cache) begin
        cache #(5, l2_d_cache_s_index, l2_d_cache_way_deg, 1) l2_d_cache(
            .clk(clk),
            .rst(rst),
            // L1 D-Cache side
            .mem_addr(d_addr_l2_up),
            .mem_wdata256(d_wdata256_l2_up),
            .mem_rdata256(d_rdata256_l2_up),
            .mem_byte_enable256(32'hFFFFFFFF),
            .mem_read(d_read_l2_up),
            .mem_write(d_write_l2_up),
            .mem_resp(d_resp_l2_up),
            // Arbiter side
            .ca_wdata(d_wdata256_l2_down),
            .ca_rdata(d_rdata256_l2_down),
            .ca_addr(d_addr_l2_down),
            .ca_resp(d_resp_l2_down),
            .ca_read(d_read_l2_down),
            .ca_write(d_write_l2_down)
        );
        end
    endgenerate

arbiter arbiter(
    // L1 I-Cache size
    .i_read(i_a_read),
    .i_addr(i_a_addr),
    .i_data(i_a_rdata),
    .i_resp(i_a_resp),
    // L2 D-Cache size
    .d_read(d_a_read),
    .d_write(d_a_write),
    .d_addr(d_a_addr),
    .d_wdata(d_a_wdata),
    .d_rdata(d_a_rdata),
    .d_resp(d_a_resp),
    // Cacheline Adapter side
    .*
);

cacheline_adaptor cacheline_adaptor (
    .clk(clk),
    .reset_n(~rst),
    // Arbiter side
    .line_i(ca_wdata),
    .line_o(ca_rdata),
    .address_i(ca_addr),
    .resp_o(ca_resp),
    .read_i(ca_read),
    .write_i(ca_write),
    // ParamMemory side
    .burst_i(mem_rdata),
    .burst_o(mem_wdata),
    .address_o(mem_addr),
    .read_o(mem_read),
    .write_o(mem_write),
    .resp_i(mem_resp)
);

endmodule : mp4
