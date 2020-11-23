package datamux;
typedef enum bit {
    mem_wdata256 = 1'b0,
    ca_rdata = 1'b1
} datamux_sel_t;
endpackage

package addrmux;
typedef enum bit [1:0] {
    mem_addr = 2'b00,
    tag0_addr = 2'b10,
    tag1_addr = 2'b11
} addrmux_sel_t;
endpackage