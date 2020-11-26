module mp4_tb;
`timescale 1ns/10ps

/********************* Do not touch for proper compilation *******************/
// Instantiate Interfaces
tb_itf itf();
rvfi_itf rvfi(itf.clk, itf.rst);

// Instantiate Testbench
source_tb tb(
    .magic_mem_itf(itf),
    .mem_itf(itf),
    .sm_itf(itf),
    .tb_itf(itf),
    .rvfi(rvfi)
);

// For local simulation, add signal for Modelsim to display by default
// Note that this signal does nothing and is not used for anything
bit f;

/****************************** End do not touch *****************************/

/************************ Signals necessary for monitor **********************/
// This section not required until CP2

assign rvfi.commit = (dut.cpu.control.MEM_WB.opcode != rv32i_types::op_none) && ~dut.cpu.stall_wb; // Set high when a valid instruction is modifying regfile or PC
assign rvfi.halt = (rvfi.commit && dut.cpu.datapath.rvfi_insn === 32'h00000063);   // Set high when you detect an infinite loop
initial rvfi.order = 0;
always @(posedge itf.clk iff rvfi.commit) rvfi.order <= rvfi.order + 1; // Modify for OoO

// Instruction and trap
assign rvfi.inst = dut.cpu.datapath.rvfi_insn;
assign rvfi.trap = 1'b0;

// Regfile
assign rvfi.rs1_addr = dut.cpu.control.MEM_WB_reg.rs1;
assign rvfi.rs2_addr = dut.cpu.control.MEM_WB_reg.rs2;
assign rvfi.rs1_rdata = dut.cpu.datapath.regfile.data[rvfi.rs1_addr];
assign rvfi.rs2_rdata = dut.cpu.datapath.regfile.data[rvfi.rs2_addr];
assign rvfi.load_regfile = dut.cpu.datapath.regfile_wb;
assign rvfi.rd_addr = dut.cpu.datapath.rvfi_rd_addr;
assign rvfi.rd_wdata = dut.cpu.datapath.rvfi_rd_wdata;

// PC
assign rvfi.pc_rdata = dut.cpu.datapath.rvfi_pc_rdata;
assign rvfi.pc_wdata = dut.cpu.datapath.rvfi_pc_wdata;

// Memory
assign rvfi.mem_addr = dut.cpu.rvfi_d_addr;
assign rvfi.mem_rmask = dut.cpu.rvfi_d_rmask;
assign rvfi.mem_wmask = dut.cpu.rvfi_d_wmask;
assign rvfi.mem_rdata = dut.cpu.rvfi_d_rdata;
assign rvfi.mem_wdata = dut.cpu.rvfi_d_wdata;

/**************************** End RVFIMON signals ****************************/

/********************* Assign Shadow Memory Signals Here *********************/

// icache signals
assign itf.inst_read = dut.i_read;
assign itf.inst_addr = dut.i_addr;
assign itf.inst_resp = dut.i_resp;
assign itf.inst_rdata = dut.i_rdata;

// dcache signals
assign itf.data_read= dut.d_read;
assign itf.data_write= dut.d_write;
assign itf.data_mbe= dut.d_byte_enable;
assign itf.data_addr = dut.d_addr;
assign itf.data_wdata= dut.d_wdata;
assign itf.data_resp= dut.d_resp;
assign itf.data_rdata= dut.d_rdata;


/*********************** End Shadow Memory Assignments ***********************/

// Set this to the proper value
assign itf.registers = '{default: '0};

/*********************** Instantiate your design here ************************/
/*
The following signals need to be connected to your top level:
Clock and reset signals:
    itf.clk
    itf.rst

Burst Memory Ports:
    itf.mem_read
    itf.mem_write
    itf.mem_wdata
    itf.mem_rdata
    itf.mem_addr
    itf.mem_resp

Please refer to tb_itf.sv for more information.
*/

mp4 dut(
    .clk(itf.clk),
    .rst(itf.rst),

    .mem_addr(itf.mem_addr),
    .mem_rdata(itf.mem_rdata),
    .mem_wdata(itf.mem_wdata),
    .mem_read(itf.mem_read),
    .mem_write(itf.mem_write),
    .mem_resp(itf.mem_resp)
);
/***************************** End Instantiation *****************************/

endmodule
