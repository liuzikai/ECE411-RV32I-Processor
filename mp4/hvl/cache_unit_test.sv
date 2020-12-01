module cache_unit_test();

timeunit 1ns;
timeprecision 1ns;

bit clk;
always #5 clk = clk === 1'b0;

localparam s_offset = 5;   // must be 5 to be consistent with the cacheline size
localparam s_index  = 3;
localparam way_deg = 2;    // >=1, also the number of bit(s) for way indices
localparam resp_cycle = 1;  // options: 0 or 1

logic rst;

// cpu -> bus_adapter & cache_control & cache_datapath
logic [31:0] mem_addr;

// cpu <-> bus_adapter
logic [31:0] mem_wdata;
logic [31:0] mem_rdata;
logic [3:0]  mem_byte_enable;

// cpu <-> cache_control
logic mem_read;
logic mem_write;
logic mem_resp;

// cache_datapath <-> cacheline_adapter
logic [255:0] ca_wdata; // line_i
logic [255:0] ca_rdata; // line_o
logic [31:0]  ca_addr;  // address_i

// cache_control <-> cacheline_adapter
logic ca_resp;          // resp_o
logic ca_read;          // read_i
logic ca_write;         // write_i

cache #(s_offset, s_index, way_deg, resp_cycle) dut(
    .*
);

task automatic test_read_miss(logic [31:0] addr, logic [255:0] feed_data, logic [31:0] expect_data, int line);
    // s_match
    if (addr[1:0] != 2'b00) $fatal("%0t %s %0d: Addr not aligned", $time, `__FILE__, line);
    mem_addr = addr; 
    mem_read = 1'b1;
    if (resp_cycle > 0) repeat(resp_cycle) @(posedge clk);
    @(negedge clk);
    if (mem_resp) $fatal("%0t %s %0d: Should not hit", $time, `__FILE__, line);
    @(posedge clk);
    // s_load
    @(negedge clk);
    if (~ca_read) $fatal("%0t %s %0d: Not reading from mem", $time, `__FILE__, line);
    if (ca_write) $fatal("%0t %s %0d: Read/write mem at the same time", $time, `__FILE__, line);
    repeat (2) @(posedge clk);
    ca_rdata = feed_data;
    ca_resp = 1'b1;
    @(posedge clk);
    ca_rdata = {256{1'bX}};
    ca_resp = 1'b0;
    @(posedge clk iff mem_resp);
    mem_read = 1'b0;
    if (mem_rdata !== expect_data) $fatal("%0t %s %0d: Data error", $time, `__FILE__, line);
    @(posedge clk);
endtask

task automatic test_read_hit(logic [31:0] addr, logic [31:0] expect_data, int line);
    // s_match
    if (addr[1:0] != 2'b00) $fatal("%0t %s %0d: Addr not aligned", $time, `__FILE__, line);
    mem_addr = addr;
    mem_read = 1'b1;
    if (resp_cycle > 0) repeat(resp_cycle) @(posedge clk);
    @(negedge clk);
    if (~mem_resp) $fatal("%0t %s %0d: Hit timeout", $time, `__FILE__, line);
    if (mem_rdata !== expect_data) $fatal("%0t %s %0d: Data error", $time, `__FILE__, line);
    if (ca_read) $fatal("%0t %s %0d: Should not read from mem", $time, `__FILE__, line);
    if (ca_write) $fatal("%0t %s %0d: Should not write to mem", $time, `__FILE__, line);
    @(posedge clk);
    mem_read = 1'b0;
    // @(posedge clk);
endtask

task automatic test_write_miss(logic [31:0] addr, logic [255:0] feed_data, logic [31:0] write_data, logic [3:0] byte_enable, int line);
    if (addr[1:0] != 2'b00) $fatal("%0t %s %0d: Addr not aligned", $time, `__FILE__, line);
    mem_addr = addr; 
    mem_write = 1'b1;
    mem_wdata = write_data;
    mem_byte_enable = byte_enable;
    if (resp_cycle > 0) repeat(resp_cycle) @(posedge clk);
    @(negedge clk);
    if (mem_resp) $fatal("%0t %s %0d: Should not hit", $time, `__FILE__, line);
    @(posedge clk);
    // s_load
    @(negedge clk);
    if (~ca_read) $fatal("%0t %s %0d: Not reading from mem", $time, `__FILE__, line);
    if (ca_write) $fatal("%0t %s %0d: Read/write mem at the same time", $time, `__FILE__, line);
    ca_rdata = feed_data;
    ca_resp = 1'b1;
    @(posedge clk);
    ca_rdata = {256{1'bX}};
    ca_resp = 1'b0;
    @(posedge clk iff mem_resp);
    mem_write = 1'b0;
    mem_wdata = {32{1'bX}};
    mem_byte_enable = {4{1'bX}};
    @(posedge clk);
endtask

task automatic test_write_hit(logic [31:0] addr, logic [31:0] write_data, logic [3:0] byte_enable, int line);
    if (addr[1:0] != 2'b00) $fatal("%0t %s %0d: Addr not aligned", $time, `__FILE__, line);
    mem_addr = addr;
    mem_wdata = write_data;
    mem_byte_enable = byte_enable;
    mem_write = 1'b1;
    if (resp_cycle > 0) repeat(resp_cycle) @(posedge clk);
    @(negedge clk);
    if (~mem_resp) $fatal("%0t %s %0d: Hit timeout", $time, `__FILE__, line);
    if (ca_read) $fatal("%0t %s %0d: Should not read from mem", $time, `__FILE__, line);
    if (ca_write) $fatal("%0t %s %0d: Should not write to mem", $time, `__FILE__, line);
    @(posedge clk);
    mem_write = 1'b0;
    mem_wdata = {32{1'bX}};
    mem_byte_enable = {4{1'bX}};
    // @(posedge clk);
endtask

task automatic test_read_miss_with_wb(logic [31:0] addr, logic [255:0] feed_data, logic [31:0] expect_data, logic [255:0] expect_wb, int line);
    // s_match
    if (addr[1:0] != 2'b00) $fatal("%0t %s %0d: Addr not aligned", $time, `__FILE__, line);
    mem_addr = addr; 
    mem_read = 1'b1;
    if (resp_cycle > 0) repeat(resp_cycle) @(posedge clk);
    @(negedge clk);
    if (mem_resp) $fatal("%0t %s %0d: Should not hit", $time, `__FILE__, line);
    @(posedge clk);
    // s_writeback
    @(negedge clk);
    if (~ca_write) $fatal("%0t %s %0d: Not writing back to mem", $time, `__FILE__, line);
    if (ca_read) $fatal("%0t %s %0d: Read/write mem at the same time", $time, `__FILE__, line);
    if (ca_wdata !== expect_wb) $fatal("%0t %s %0d: WB data error", $time, `__FILE__, line);
    ca_resp = 1'b1;
    @(posedge clk);
    ca_resp = 1'b0;
    // s_load
    repeat (2) @(posedge clk);
    if (~ca_read) $fatal("%0t %s %0d: Not reading from mem", $time, `__FILE__, line);
    if (ca_write) $fatal("%0t %s %0d: Read/write mem at the same time", $time, `__FILE__, line);
    ca_rdata = feed_data;
    ca_resp = 1'b1;
    @(posedge clk);
    ca_rdata = {256{1'bX}};
    ca_resp = 1'b0;
    // wait for complete
    @(posedge clk iff mem_resp);
    mem_read = 1'b0;
    if (mem_rdata !== expect_data) $fatal("%0t %s %0d: Data error", $time, `__FILE__, line);
    @(posedge clk);
endtask

task automatic test_write_miss_with_wb(logic [31:0] addr, logic [255:0] feed_data, logic [31:0] write_data, logic [3:0] byte_enable, logic [31:0] expect_wb_addr, logic [255:0] expect_wb_data, int line);
    // s_match
    if (addr[1:0] != 2'b00) $fatal("%0t %s %0d: Addr not aligned", $time, `__FILE__, line);
    mem_addr = addr; 
    mem_write = 1'b1;
    mem_wdata = write_data;
    mem_byte_enable = byte_enable;
    if (resp_cycle > 0) repeat(resp_cycle) @(posedge clk);
    @(negedge clk);
    if (mem_resp) $fatal("%0t %s %0d: Should not hit", $time, `__FILE__, line);
    @(posedge clk);
    // s_writeback
    @(negedge clk);
    if (~ca_write) $fatal("%0t %s %0d: Not writing back to mem", $time, `__FILE__, line);
    if (ca_read) $fatal("%0t %s %0d: Read/write mem at the same time", $time, `__FILE__, line);
    if (ca_addr != expect_wb_addr) $fatal("%0t %s %0d: WB addr error", $time, `__FILE__, line);
    if (ca_wdata !== expect_wb_data) $fatal("%0t %s %0d: WB data error", $time, `__FILE__, line);
    ca_resp = 1'b1;
    @(posedge clk);
    ca_resp = 1'b0;
    // s_load
    repeat (2) @(posedge clk);
    if (~ca_read) $fatal("%0t %s %0d: Not reading from mem", $time, `__FILE__, line);
    if (ca_write) $fatal("%0t %s %0d: Read/write mem at the same time", $time, `__FILE__, line);
    ca_rdata = feed_data;
    ca_resp = 1'b1;
    @(posedge clk);
    ca_rdata = {256{1'bX}};
    ca_resp = 1'b0;
    // wait for complete
    @(posedge clk iff mem_resp);
    mem_write = 1'b0;
    mem_wdata = {32{1'bX}};
    mem_byte_enable = {4{1'bX}};
    @(posedge clk);
endtask

initial begin : test_vectors

    dut.control.state = dut.control.s_match;  // avoid fatal
    mem_read = 1'b0;
    mem_write = 1'b0;
    mem_byte_enable = 4'b1111;
    ca_resp = 1'b0;
    
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;

    // ================================ Read Tests ================================

    // TEST: read sequence 1
    test_read_miss(
        32'h00000000,
        256'h1111111122222222333333334444444455555555666666667777777788888888,
        32'h88888888,
        `__LINE__
    );
    test_read_hit(32'h00000000, 32'h88888888, `__LINE__);
    test_read_hit(32'h00000008, 32'h66666666, `__LINE__);
    test_read_hit(32'h00000000, 32'h88888888, `__LINE__);
    test_read_hit(32'h0000001C, 32'h11111111, `__LINE__);

    // TEST: read sequence 2, with the same index as seq 1
    test_read_miss(
        32'h1000000C,
        256'h8888888899999999AAAAAAAABBBBBBBBCCCCCCCCDDDDDDDDEEEEEEEEFFFFFFFF,
        32'hCCCCCCCC,
        `__LINE__
    );
    test_read_hit(32'h10000018, 32'h99999999, `__LINE__);

    // TEST: sequence 1 should not lost
    test_read_hit(32'h0000000C, 32'h55555555, `__LINE__);
    test_read_hit(32'h00000010, 32'h44444444, `__LINE__);

    // TEST: read sequence 3, with a different index
    test_read_miss(
        32'h00000080,
        {8{32'hAAAAAAAA}},
        32'hAAAAAAAA,
        `__LINE__
    );

    // TEST: sequence 1 and 2 should not lost
    test_read_hit(32'h10000000, 32'hFFFFFFFF, `__LINE__);
    test_read_hit(32'h00000008, 32'h66666666, `__LINE__);
    // Seq 1 is last used

    // TEST: read sequence 4, with the same index as seq 1 and 2. Seq 2 should be replaced
    test_read_miss(
        32'h80000000,
        {8{32'hFFFFEEEE}},
        32'hFFFFEEEE,
        `__LINE__
    );

    // TEST: seq 1 should not miss
    test_read_hit(32'h00000000, 32'h88888888, `__LINE__);
    test_read_hit(32'h0000001C, 32'h11111111, `__LINE__);

    // TEST: seq 2 should miss, seq 4 should be replaced
    test_read_miss(
        32'h1000000C,
        256'h8888888899999999AAAAAAAABBBBBBBBCCCCCCCCDDDDDDDDEEEEEEEEFFFFFFFF,
        32'hCCCCCCCC,
        `__LINE__
    );

    // TEST: seq 4 should miss, seq 1 should be replace
    test_read_miss(
        32'h80000000,
        {8{32'hFFFFEEEE}},
        32'hFFFFEEEE,
        `__LINE__
    );

    // TEST: seq 3 should be totally unaffected
    test_read_hit(32'h00000084, 32'hAAAAAAAA, `__LINE__);

    // TEST: seq 1 should miss, seq 2 should be replace
    test_read_miss(
        32'h00000000,
        256'h1111111122222222333333334444444455555555666666667777777788888888,
        32'h88888888,
        `__LINE__
    );

    // TEST: seq 4 shoudl not miss
    test_read_hit(32'h8000000C, 32'hFFFFEEEE, `__LINE__);

    // TEST: read seq 5, with the same index as seq 3
    test_read_miss( 32'h03000080, {8{32'hBBBBBBBB}}, 32'hBBBBBBBB, `__LINE__);

    // TEST: read seq 6, with the same index as seq 3 & 5. Seq 3 should be replaced
    test_read_miss( 32'h05000080, {8{32'hCCCCCCCC}}, 32'hCCCCCCCC, `__LINE__);

    // TEST: read seq 7, with the same index as seq 6 & 5. Seq 5 should be replaced
    test_read_miss( 32'h05500080, {8{32'hDDDDDDDD}}, 32'hDDDDDDDD, `__LINE__);

    // TEST: seq 5 should miss. Seq 6 should be replaced
    test_read_miss( 32'h03000080, {8{32'hBBBBBBBB}}, 32'hBBBBBBBB, `__LINE__);

    // TEST: read a cache line using non-zero offset
    test_read_miss(
        32'h0011008C,
        {8{32'h11111111}},
        32'h11111111,
        `__LINE__
    );
    test_read_hit(32'h00110080, 32'h11111111, `__LINE__);

    // ================================ Write Tests ================================

    // Load data 1
    test_read_miss(32'hF0000000, {8{32'hDDDDDDDD}}, 32'hDDDDDDDD, `__LINE__);
    
    // TEST: hit write to offset 0
    test_write_hit(32'hF0000000, 32'hEEEEEEEE, 4'b1111, `__LINE__);

    // TEST: the data gets updated, while the other offset get unaffected
    test_read_hit(32'hF0000000, 32'hEEEEEEEE, `__LINE__);
    test_read_hit(32'hF0000004, 32'hDDDDDDDD, `__LINE__);
    test_read_hit(32'hF0000008, 32'hDDDDDDDD, `__LINE__);
    test_read_hit(32'hF000000C, 32'hDDDDDDDD, `__LINE__);
    test_read_hit(32'hF0000010, 32'hDDDDDDDD, `__LINE__);
    test_read_hit(32'hF0000014, 32'hDDDDDDDD, `__LINE__);
    test_read_hit(32'hF0000018, 32'hDDDDDDDD, `__LINE__);
    test_read_hit(32'hF000001C, 32'hDDDDDDDD, `__LINE__);

    // TEST: with bit enabled
    test_write_hit(32'hF0000004, 32'hCCCCCCCC, 4'b0001, `__LINE__);
    test_write_hit(32'hF0000008, 32'hCCCCCCCC, 4'b0010, `__LINE__);
    test_write_hit(32'hF000000C, 32'hCCCCCCCC, 4'b0100, `__LINE__);
    test_write_hit(32'hF0000010, 32'hCCCCCCCC, 4'b1000, `__LINE__);
    test_write_hit(32'hF0000014, 32'hCCCCCCCC, 4'b0011, `__LINE__);
    test_write_hit(32'hF0000018, 32'hCCCCCCCC, 4'b1100, `__LINE__);
    test_write_hit(32'hF000001C, 32'hCCCCCCCC, 4'b1001, `__LINE__);

    test_read_hit(32'hF0000004, 32'hDDDDDDCC, `__LINE__);
    test_read_hit(32'hF0000008, 32'hDDDDCCDD, `__LINE__);
    test_read_hit(32'hF000000C, 32'hDDCCDDDD, `__LINE__);
    test_read_hit(32'hF0000010, 32'hCCDDDDDD, `__LINE__);
    test_read_hit(32'hF0000014, 32'hDDDDCCCC, `__LINE__);
    test_read_hit(32'hF0000018, 32'hCCCCDDDD, `__LINE__);
    test_read_hit(32'hF000001C, 32'hCCDDDDCC, `__LINE__);

    // TEST: write miss data 2
    test_write_miss(32'hE0000000, {8{32'h00000000}}, 32'h11111111, 4'b0110, `__LINE__);
    test_read_hit(32'hE0000000, 32'h00111100, `__LINE__);
    test_read_hit(32'hE000001C, 32'h00000000, `__LINE__);

    // TEST: data 1 should not change
    test_read_hit(32'hF0000004, 32'hDDDDDDCC, `__LINE__);
    test_read_hit(32'hF0000008, 32'hDDDDCCDD, `__LINE__);
    test_read_hit(32'hF000000C, 32'hDDCCDDDD, `__LINE__);
    test_read_hit(32'hF0000010, 32'hCCDDDDDD, `__LINE__);
    test_read_hit(32'hF0000014, 32'hDDDDCCCC, `__LINE__);
    test_read_hit(32'hF0000018, 32'hCCCCDDDD, `__LINE__);
    test_read_hit(32'hF000001C, 32'hCCDDDDCC, `__LINE__);

    // TEST: write miss data 3, replacing data 2
    test_write_miss_with_wb(
        32'hD0000000, 
        {8{32'h00000000}}, 
        32'h22222222, 4'b1010, 
        32'hE0000000,
        {{7{32'h00000000}}, 32'h00111100}, 
        `__LINE__
    );

    // TEST: data 1 should not change
    test_read_hit(32'hF0000004, 32'hDDDDDDCC, `__LINE__);
    test_read_hit(32'hF000001C, 32'hCCDDDDCC, `__LINE__);

    // TEST: data 3 should be updated
    test_read_hit(32'hD0000000, 32'h22002200, `__LINE__);
    test_read_hit(32'hD0000010, 32'h00000000, `__LINE__);

    // TEST: write miss data 2, replacing data 1
    test_write_miss_with_wb(
        32'hE0000000, 
        {{7{32'h00000000}}, 32'h00111100}, 
        32'h11111111, 4'b1001, 
        32'hF0000000,
        256'hCCDDDDCCCCCCDDDDDDDDCCCCCCDDDDDDDDCCDDDDDDDDCCDDDDDDDDCCEEEEEEEE,
        `__LINE__
    );

    // TEST: LRU but not dirty
    test_read_miss(32'hE00000C0, {8{32'hAAAAAAAA}}, 32'hAAAAAAAA, `__LINE__);
    test_write_miss(32'hD00000C0, {8{32'hBBBBBBBB}}, 32'hBBBBBBBB, 4'b1111, `__LINE__);
    test_read_miss(32'hC00000C0, {8{32'hCCCCCCCC}}, 32'hCCCCCCCC, `__LINE__);

    $finish;
    
end

endmodule