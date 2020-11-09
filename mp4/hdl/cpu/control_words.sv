`define BAD_STATE $fatal("%0t %s %0d: Illegal state", $time, `__FILE__, `__LINE__)
`define BAD_OPCODE $fatal("%0t %s %0d: Illegal opcode", $time, `__FILE__, `__LINE__)
import rv32i_types::*; /* Import types defined in rv32i_types.sv */

module control_words
(
    input clk,
    input rst,

    // New control word
    input rv32i_control_word new_control_word,

    // IF-ID
    output cmpmux::cmpmux_sel_t cmpmux_sel,
    output alumux::alumux1_sel_t alumux1_sel,
    output alumux::alumux2_sel_t alumux2_sel,

    // ID-EX
    output alu_ops aluop,
    output branch_funct3_t cmpop,
    output pcmux::pcmux_sel_t pcmux_sel,

    // EX-MEM
    output logic d_read,
    output logic d_write,
    output logic [3:0] d_byte_enable,
    output regfilemux::regfilemux_sel_t regfilemux_sel,

    // MEM-WB
    output logic regfile_wb,
    output logic [4:0] regfile_rd,

    // General registers
    input logic i_resp,
    input logic d_resp,

    output logic stall
);

rv32i_control_word IF_ID, ID_EX, EX_MEM, MEM_WB;  // control word register
rv32i_control_word FLUSH;  // constant

// IF-ID
assign cmpmux_sel = IF_ID.cmpmux_sel;
assign alumux1_sel = IF_ID.alumux1_sel;
assign alumux2_sel = IF_ID.alumux2_sel;

// ID-EX
assign aluop = ID_EX.aluop;
assign cmpop = ID_EX.cmpop;
assign pcmux_sel = ID_EX.pcmux_sel;

// EX-MEM
assign d_read = EX_MEM.d_read;
assign d_write = EX_MEM.d_write;
assign d_byte_enable = EX_MEM.d_byte_enable;
assign regfilemux_sel = EX_MEM.regfilemux_sel;

// MEM-WB
assign regfile_wb = MEM_WB.regfile_wb;
assign regfile_rd = MEM_WB.regfile_rd;

assign stall = (!i_cache_resp) || (!d_ready_next);

logic [3:0] flush_list;
logic d_ready, d_ready_next;

assign flush_list = 4'b0000;

always_comb begin
    FLUSH.opcode = op_none;
    FLUSH.alumux1_sel = alumux::alumux1_sel_t'(1'b0);
    FLUSH.alumux2_sel = alumux::alumux2_sel_t'(3'b000);
    FLUSH.regfilemux_sel = regfilemux_sel_t'(4'b0000);
    FLUSH.cmpmux_sel = cmpmux'(1'b0);
    FLUSH.aluop = alu_ops'(3'b000);
    FLUSH.cmpop = branch_funct3_t'(3'b000);
    FLUSH.pcmux_sel = pcmux::pc_plus4;
    FLUSH.d_read = 1'b0;
    FLUSH.d_write = 1'b0;
    FLUSH.d_byte_enable = 4'b0000;
    FLUSH.regfile_wb = 1'b0;
    FLUSH.regfile_rd = 5'b00000;
end

always_comb begin
    d_ready_next = d_ready;
    if (!EX_MEM.d_read && !EX_MEM.d_write) begin
        d_ready_next = 1'b1;
    end else if (d_resp) begin
        d_ready_next = 1'b1;
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        IF_ID <= FLUSH;
        ID_EX <= FLUSH;
        EX_MEM <= FLUSH;
        MEM_WB <= FLUSH;
        d_ready <= 1'b0;
    end else if (stall) begin
        IF_ID <= IF_ID;
        ID_EX <= ID_EX;
        EX_MEM <= EX_MEM;
        MEM_WB <= MEM_WB;
        d_ready <= d_ready_next;
    end else begin
        IF_ID <= (flush_list[0]) ? FLUSH : new_control_word;
        ID_EX <= (flush_list[1]) ? FLUSH : IF_ID;
        EX_MEM <= (flush_list[2]) ? FLUSH : ID_EX;
        MEM_WB <= (flush_list[3]) ? FLUSH : EX_MEM;
        d_ready <= 1'b0;  // FIXME: synchronized? Must stall for at least one cycle?
    end
end

endmodule : control_words
