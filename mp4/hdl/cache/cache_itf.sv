package datamux;
typedef enum bit {
    mem_wdata256 = 1'b0,
    ca_rdata = 1'b1
} datamux_sel_t;
endpackage

package addrmux;
typedef enum bit {
    mem_addr = 1'b0,
    tag_addr = 1'b1
} addrmux_sel_t;
endpackage