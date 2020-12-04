`include "perf_cnt_itf.sv"

module performance_counter(
    perf_cnt_itf itf
);

int br_cnt = 0;
int mispred_cnt = 0;
int flush_cnt = 0;

int total_cycles = 0;
int cycles_not_commit = 0;
int bubble_cnt = 0;
int i_stall_cnt = 0;
int d_stall_cnt = 0;

int l1_i_cache_read_cnt = 0;
int l1_i_cache_hit_cnt = 0;

int l2_i_cache_read_cnt = 0;
int l2_i_cache_read_from_l1_cnt = 0;
int l2_i_cache_hit_cnt = 0;

int l1_d_cache_read_cnt = 0;
int l1_d_cache_write_cnt = 0;
int l1_d_cache_hit_cnt = 0;

int l2_d_cache_read_cnt = 0;
int l2_d_cache_write_cnt = 0;
int l2_d_cache_read_from_l1_cnt = 0;
int l2_d_cache_write_from_l1_cnt = 0;
int l2_d_cache_hit_cnt = 0;

int pmem_read_cnt = 0;
int pmem_write_cnt = 0;

always @(posedge itf.clk) begin
    if (itf.halt) begin
        $display("[PerformanceCounter] Total cycles: %0d", total_cycles);
        $display("[PerformanceCounter] Cycles not commit: %0d", cycles_not_commit);
        $display("[PerformanceCounter] Bubbles: %0d", bubble_cnt);
        $display("[PerformanceCounter] Stall cycles waiting for inst: %0d", i_stall_cnt);
        $display("[PerformanceCounter] Stall cycles waiting for data: %0d", d_stall_cnt);
        $display("[PerformanceCounter] Flush: %0d", flush_cnt);
        $display("");
        $display("[PerformanceCounter] BR count: %0d", br_cnt);
        $display("[PerformanceCounter] Mispredict: %0d", mispred_cnt);
        $display("");
        $display("[PerformanceCounter] L1 I-Cache read count: %0d", l1_i_cache_read_cnt);
        $display("[PerformanceCounter] L1 I-Cache hit count: %0d", l1_i_cache_hit_cnt);
        $display("[PerformanceCounter] L2 I-Cache read count: %0d", l2_i_cache_read_cnt);
        $display("[PerformanceCounter] L2 I-Cache read (from L1) count: %0d", l2_i_cache_read_from_l1_cnt);
        $display("[PerformanceCounter] L2 I-Cache hit count: %0d", l2_i_cache_hit_cnt);
        $display("");
        $display("[PerformanceCounter] L1 D-Cache read count: %0d", l1_d_cache_read_cnt);
        $display("[PerformanceCounter] L1 D-Cache write count: %0d", l1_d_cache_write_cnt);
        $display("[PerformanceCounter] L1 D-Cache hit count: %0d", l1_d_cache_hit_cnt);
        $display("[PerformanceCounter] L2 D-Cache read count: %0d", l2_d_cache_read_cnt);
        $display("[PerformanceCounter] L2 D-Cache read (from L1) count: %0d", l2_d_cache_read_from_l1_cnt);
        $display("[PerformanceCounter] L2 D-Cache write count: %0d", l2_d_cache_write_cnt);
        $display("[PerformanceCounter] L2 D-Cache write (from L1) count: %0d", l2_d_cache_write_from_l1_cnt);
        $display("[PerformanceCounter] L2 D-Cache hit count: %0d", l2_d_cache_hit_cnt);
        $display("");
        $display("[PerformanceCounter] PMEM read count: %0d", pmem_read_cnt);
        $display("[PerformanceCounter] PMEM write count: %0d", pmem_write_cnt);
        $finish;
    end
end

always @(negedge itf.clk iff ~itf.rst) begin

    if (~itf.pipeline_stall_ex) begin
        if (itf.pipeline_ex_opcode === rv32i_types::op_br) begin
            br_cnt++;
        end

        if (itf.pipeline_flush) begin
            flush_cnt++;
        end

        if (itf.pipeline_flush && itf.mispred) begin
            mispred_cnt++;
        end
    end

    total_cycles++; 
    if (~itf.commit) begin
        cycles_not_commit++;
    end

    if (itf.pipeline_stall_id && ~itf.pipeline_stall_ex) begin
        bubble_cnt++;
    end

    if (itf.pipeline_stall_waiting_i) begin
        i_stall_cnt++;
    end

    if (itf.pipeline_stall_waiting_d) begin
        d_stall_cnt++;
    end

end

// L1 I-Cache
always @(posedge itf.clk iff ~itf.rst) begin
    wait (itf.l1_i_cache_read);
    l1_i_cache_read_cnt++;
    @(negedge itf.clk)
    if (itf.l1_i_cache_resp) l1_i_cache_hit_cnt++;
    @(posedge itf.clk iff itf.l1_i_cache_resp);
    wait (~itf.pipeline_stall_id);
end

// L2 I-Cache
always @(posedge itf.clk iff ~itf.rst) begin
    wait (itf.l2_i_cache_read);
    l2_i_cache_read_cnt++;
    if (itf.l2_i_cache_read_from_l1) l2_i_cache_read_from_l1_cnt++;
    @(posedge itf.clk)
    @(negedge itf.clk)
    if (itf.l2_i_cache_resp) l2_i_cache_hit_cnt++;
    @(posedge itf.clk iff itf.l2_i_cache_resp);
end

// L1 D-Cache
always @(posedge itf.clk iff ~itf.rst) begin
    wait (itf.l1_d_cache_read || itf.l1_d_cache_write);
    if (itf.l1_d_cache_read) l1_d_cache_read_cnt++;
    if (itf.l1_d_cache_write) l1_d_cache_write_cnt++;
    @(negedge itf.clk)
    if (itf.l1_d_cache_resp) l1_d_cache_hit_cnt++;
    @(posedge itf.clk iff itf.l1_d_cache_resp);
    wait (~itf.pipeline_stall_ex);
end

// L2 D-Cache
always @(posedge itf.clk iff ~itf.rst) begin
    wait (itf.l2_d_cache_read || itf.l2_d_cache_write);
    if (itf.l2_d_cache_read) l2_d_cache_read_cnt++;
    if (itf.l2_d_cache_write) l2_d_cache_write_cnt++;
    if (itf.l2_d_cache_read_from_l1) l2_d_cache_read_from_l1_cnt++;
    if (itf.l2_d_cache_write_from_l1) l2_d_cache_write_from_l1_cnt++;
    @(posedge itf.clk)
    @(negedge itf.clk)
    if (itf.l2_d_cache_resp) l2_d_cache_hit_cnt++;
    @(posedge itf.clk iff itf.l2_d_cache_resp);
end

// ParamMemory
always @(posedge itf.clk iff ~itf.rst) begin
    wait (itf.pmem_read || itf.pmem_write);
    if (itf.pmem_read) pmem_read_cnt++;
    if (itf.pmem_write) pmem_write_cnt++;
    @(posedge itf.clk iff itf.pmem_resp);
end

endmodule