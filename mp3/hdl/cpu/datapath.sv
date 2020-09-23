`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module datapath
(
    input clk,
    input rst,
    input load_mdr,
    input rv32i_word mem_rdata,
    output rv32i_word mem_wdata, // signal used by RVFI Monitor
);

/******************* Signals Needed for RVFI Monitor *************************/
rv32i_word pcmux_out;
rv32i_word mdrreg_out;
/*****************************************************************************/


/***************************** Registers *************************************/
// Keep Instruction register named `IR` for RVFI Monitor
ir IR();

register MDR(
    .clk  (clk),
    .rst (rst),
    .load (load_mdr),
    .in   (mem_rdata),
    .out  (mdrreg_out)
);

/*****************************************************************************/

/******************************* ALU and CMP *********************************/
/*****************************************************************************/

/******************************** Muxes **************************************/
always_comb begin : MUXES
    // We provide one (incomplete) example of a mux instantiated using
    // a case statement.  Using enumerated types rather than bit vectors
    // provides compile time type safety.  Defensive programming is extremely
    // useful in SystemVerilog.  In this case, we actually use 
    // Offensive programming --- making simulation halt with a fatal message
    // warning when an unexpected mux select value occurs
    unique case (pcmux_sel)
        pcmux::pc_plus4: pcumux_out = pc_out + 4;
        // etc.
        default: `BAD_MUX_SEL;
    endcase
end
/*****************************************************************************/
endmodule : datapath
