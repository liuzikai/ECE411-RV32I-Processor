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

rv32i_types::rv32i_word pc_wb;
rv32i_types::rv32i_word rs1_rdata_ex, rs1_rdata_mem, rs1_rdata_wb;
rv32i_types::rv32i_word rs2_rdata_ex, rs2_rdata_mem, rs2_rdata_wb;
rv32i_types::rv32i_word insn_id, insn_ex, insn_mem, insn_wb;
rv32i_types::rv32i_word pc_wdata_id, pc_wdata_ex, pc_wdata_mem, pc_wdata_wb;
rv32i_types::rv32i_word d_addr_wb, d_rdata_wb, d_wdata_wb, d_rmask_wb, d_wmask_wb;

always_ff @(posedge itf.clk) begin : SAMPLING

    if (~dut.cpu.stall_wb) pc_wb <= dut.cpu.datapath.pc_mem_out;

    if (~dut.cpu.stall_ex) rs1_rdata_ex <= dut.cpu.datapath.rs1_actual;
    if (~dut.cpu.stall_mem) rs1_rdata_mem <= rs1_rdata_ex;
    if (~dut.cpu.stall_wb) rs1_rdata_wb <= rs1_rdata_mem;

    if (~dut.cpu.stall_ex) rs2_rdata_ex <= dut.cpu.datapath.rs2_actual;
    if (~dut.cpu.stall_mem) rs2_rdata_mem <= rs2_rdata_ex;
    if (~dut.cpu.stall_wb) rs2_rdata_wb <= rs2_rdata_mem;

    if (~dut.cpu.stall_id) insn_id <= dut.cpu.datapath.i_rdata;
    if (~dut.cpu.stall_ex) insn_ex <= insn_id;
    if (~dut.cpu.stall_mem) insn_mem <= insn_ex;
    if (~dut.cpu.stall_wb) insn_wb <= insn_mem;

    if (~dut.cpu.stall_id) pc_wdata_id <= (dut.cpu.datapath.pc_out + 4);
    if (~dut.cpu.stall_ex) pc_wdata_ex <= pc_wdata_id;
    if (~dut.cpu.stall_mem) pc_wdata_mem <= (dut.cpu.datapath.ex_load_pc ? dut.cpu.datapath.pc_in : pc_wdata_ex);
    if (~dut.cpu.stall_wb) pc_wdata_wb <= pc_wdata_mem;

    if (~dut.cpu.stall_wb) d_addr_wb <= dut.cpu.d_addr;
    if (~dut.cpu.stall_wb) d_rdata_wb <= dut.cpu.d_rdata;
    if (~dut.cpu.stall_wb) d_wdata_wb <= dut.cpu.d_wdata;
    if (~dut.cpu.stall_wb) d_rmask_wb <= dut.cpu.d_read ? 4'b1111 : 4'b0;
    if (~dut.cpu.stall_wb) d_wmask_wb <= dut.cpu.d_write ? dut.cpu.d_byte_enable : 4'b0;
end

assign rvfi.commit = (dut.cpu.control.mem_wb.opcode != rv32i_types::op_none) && ~dut.cpu.stall_wb; // Set high when a valid instruction is modifying regfile or PC
assign rvfi.halt = (rvfi.commit && insn_wb === 32'h00000063);   // Set high when you detect an infinite loop
initial rvfi.order = 0;
always @(posedge itf.clk iff rvfi.commit) rvfi.order <= rvfi.order + 1; // Modify for OoO

// Instruction and trap
assign rvfi.inst = insn_wb;
assign rvfi.trap = 1'b0;

// Regfile
assign rvfi.rs1_addr = dut.cpu.control.mem_wb.rs1;
assign rvfi.rs2_addr = dut.cpu.control.mem_wb.rs2;
assign rvfi.rs1_rdata = rs1_rdata_wb;
assign rvfi.rs2_rdata = rs2_rdata_wb;
assign rvfi.load_regfile = (dut.cpu.datapath.regfile_rd != rv32i_types::rv32i_reg'(5'b00000));
assign rvfi.rd_addr = dut.cpu.datapath.regfile_rd;
assign rvfi.rd_wdata = dut.cpu.datapath.regfile_in;  // will be masked by rvfi.load_regfile

// PC
assign rvfi.pc_rdata = pc_wb;
assign rvfi.pc_wdata = pc_wdata_wb;

// Memory
assign rvfi.mem_addr = d_addr_wb;
assign rvfi.mem_rmask = d_rmask_wb;
assign rvfi.mem_wmask = d_wmask_wb;
assign rvfi.mem_rdata = d_rdata_wb;
assign rvfi.mem_wdata = d_wdata_wb;

/**************************** End RVFIMON signals ****************************/

/********************* Assign Shadow Memory Signals Here *********************/

// i-cache signals
assign itf.inst_read = dut.i_read;
assign itf.inst_addr = dut.i_addr;
assign itf.inst_resp = dut.i_resp;
assign itf.inst_rdata = dut.i_rdata;

// d-cache signals
assign itf.data_read = dut.d_read;
assign itf.data_write = dut.d_write;
assign itf.data_mbe = dut.d_byte_enable;
assign itf.data_addr = dut.d_addr;
assign itf.data_wdata = dut.d_wdata;
assign itf.data_resp = dut.d_resp;
assign itf.data_rdata = dut.d_rdata;


/*********************** End Shadow Memory Assignments ***********************/

// Set this to the proper value
assign itf.registers = '{default: '0};

/*********************** Instantiate your design here ************************/

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
