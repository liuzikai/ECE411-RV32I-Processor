// Align half-word/byte R/W to 4-byte aligned access
// Memory accesses must be aligned itself (4-byte aligned for l/sw(u), 2-byte aligned for l/sh(u))

import rv32i_types::*;

module mem_align (

    // Unaligned signals from upstream
    input  rv32i_word  raw_addr,
    output rv32i_word  raw_rdata,
    input  rv32i_word  raw_wdata,
    input  logic [3:0] raw_byte_enable,

    // Aligned signals to downstream
    output rv32i_word  mem_addr,
    input  rv32i_word  mem_rdata,
    output rv32i_word  mem_wdata,
    output logic [3:0] mem_byte_enable
);

assign mem_addr = {raw_addr[31:2], 2'b00};  // align by 4 bytes

always_comb begin
    unique case (raw_addr[1:0])  
    2'b00: begin
        mem_wdata = raw_wdata;
        mem_byte_enable = raw_byte_enable;
        raw_rdata = mem_rdata;
    end
    2'b01: begin
        // Under the assumption of no unaligned memmory access, this offset must results from l/sb(u)
        // Here we simply preserve as many bytes as we can
        mem_wdata = {raw_wdata[23:0], 8'b0};
        mem_byte_enable = {raw_byte_enable[2:0], 1'b0};
        raw_rdata = {8'b0, mem_rdata[31:8]};
    end
    2'b10: begin
        mem_wdata = {raw_wdata[15:0], 16'b0};
        mem_byte_enable = {raw_byte_enable[1:0], 2'b0};
        raw_rdata = {16'b0, mem_rdata[31:16]};
    end
    2'b11: begin
        mem_wdata = {raw_wdata[7:0], 24'b0};
        mem_byte_enable = {raw_byte_enable[0], 3'b0};
        raw_rdata = {24'b0, mem_rdata[31:24]};
    end
endcase
end

endmodule : mem_align