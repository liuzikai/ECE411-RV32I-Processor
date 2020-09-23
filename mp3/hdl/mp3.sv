import rv32i_types::*;

module mp3
(
    input clk,
    input rst,
    input pmem_resp,
    input [63:0] pmem_rdata,
    output logic pmem_read,
    output logic pmem_write,
    output rv32i_word pmem_address,
    output [63:0] pmem_wdata
);

// Keep cpu named `cpu` for RVFI Monitor
// Note: you have to rename your mp2 module to `cpu`
cpu cpu(.*);

// Keep cache named `cache` for RVFI Monitor
cache cache(.*);

// From MP1
cacheline_adaptor cacheline_adaptor
(
);

endmodule : mp3
