`ifndef PERF_CNT_ITF
`define PERF_CNT_ITF

interface perf_cnt_itf(input clk, input rst);

    logic halt;
    

    // Caches

    logic l1_i_cache_read;
    logic l1_i_cache_resp;

    logic l2_i_cache_read;
    logic l2_i_cache_read_from_l1;
    logic l2_i_cache_resp;

    logic l1_d_cache_read;
    logic l1_d_cache_write;
    logic l1_d_cache_resp;

    logic l2_d_cache_read;
    logic l2_d_cache_read_from_l1;
    logic l2_d_cache_write;
    logic l2_d_cache_write_from_l1;
    logic l2_d_cache_resp;

    logic pmem_read;
    logic pmem_write;
    logic pmem_resp;

    // Branch prediction

    logic [6:0] pipeline_ex_opcode;
    logic mispred;

    // Pipeline stall and flush

    logic commit;

    logic pipeline_stall_id;
    logic pipeline_stall_ex;

    logic pipeline_stall_waiting_i;
    logic pipeline_stall_waiting_d;

    logic pipeline_flush;

endinterface

`endif