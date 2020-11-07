import rv32i_types::*;

module cpu
(
    input clk,
    input rst,

    // memory -> control
    input mem_resp,

    // memory -> datapath
    input rv32i_word mem_rdata,

    // control -> memory
    output logic mem_read,
    output logic mem_write,
    output logic [3:0] mem_byte_enable,

    // datapath -> memory
    output rv32i_word mem_address,
    output rv32i_word mem_wdata
);

/******************* Signals Needed for RVFI Monitor *************************/
logic load_pc;
logic load_regfile;
/*****************************************************************************/

/**************************** Control Signals ********************************/
// control -> datapath
logic load_ir;
logic load_mar;
logic load_mdr;
logic load_data_out;
pcmux::pcmux_sel_t pcmux_sel;
branch_funct3_t cmpop;
alumux::alumux1_sel_t alumux1_sel;
alumux::alumux2_sel_t alumux2_sel;
regfilemux::regfilemux_sel_t regfilemux_sel;
marmux::marmux_sel_t marmux_sel;
cmpmux::cmpmux_sel_t cmpmux_sel;
alu_ops aluop;
logic [1:0] mem_shift_amount;

// datapath -> control
rv32i_opcode opcode;
logic [2:0] funct3;
logic [6:0] funct7;
logic br_en;
logic [4:0] rs1;
logic [4:0] rs2;
logic [1:0] alu_out_2lsb;
/*****************************************************************************/

/* Instantiate MP 1 top level blocks here */

// Keep control named `control` for RVFI Monitor
control control(.*);

// Keep datapath named `datapath` for RVFI Monitor
datapath datapath(.*);

endmodule : cpu
