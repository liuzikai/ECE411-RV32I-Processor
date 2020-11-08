`define BAD_STATE $fatal("%0t %s %0d: Illegal state", $time, `__FILE__, `__LINE__)
`define BAD_OPCODE $fatal("%0t %s %0d: Illegal opcode", $time, `__FILE__, `__LINE__)
import rv32i_types::*; /* Import types defined in rv32i_types.sv */

module control_word_control
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
    output logic use_br_en,
    output alu_ops aluop,
    output branch_funct3_t cmpop,
    output logic load_mdar,

    // EX-MEM
    output logic load_data_out,
    output logic mem_read,
    output logic mem_write,
    output logic [3:0] mem_byte_enable,
    output regfilemux::regfilemux_sel_t regfilemux_sel,

    // MEM-WB
    output logic load_regfile,
    output logic [4:0] rd,

    // General registers
    input logic i_cache_resp,
    input logic d_cache_resp,
    output logic stall
);

// IF-ID
assign cmpmux_sel = IF_ID.cmpmux_sel;
assign alumux1_sel = IF_ID.alumux1_sel;
assign alumux2_sel = IF_ID.alumux2_sel;

// ID-EX
assign use_br_en = ID_EX.use_br_en;
assign aluop = ID_EX.aluop;
assign cmpop = ID_EX.cmpop;
assign load_mdar = ID_EX.load_mdar;

// EX-MEM
assign load_data_out = EX_MEM.load_data_out;
assign mem_read = EX_MEM.mem_read;
assign mem_write = EX_MEM.mem_write;
assign mem_byte_enable = EX_MEM.mem_byte_enable;
assign regfilemux_sel = EX_MEM.regfilemux_sel;

// MEM-WB
assign load_regfile = MEM_WB.load_regfile;
assign rd = MEM_WB.rd;

assign stall = (!i_cache_resp) || (!d_ready_next);

rv32i_control_word IF_ID, ID_EX, EX_MEM, MEM_WB, FLUSH;
logic [3:0] flush_list;
logic d_ready, d_ready_next;

assign flush_list = 4'b0000;

always_comb begin
    FLUSH.opcode = op_none;
    FLUSH.cmpmux_sel = cmpmux'(1'b0);
    FLUSH.alumux1_sel = alumux::alumux1_sel_t'(1'b0);
    FLUSH.alumux2_sel = alumux::alumux2_sel_t'(3'b000);
    FLUSH.use_br_en = 1'b0;
    FLUSH.aluop = alu_ops'(3'b000);
    FLUSH.cmpop = branch_funct3_t'(3'b000);
    FLUSH.load_mdar = 1'b0;
    FLUSH.load_data_out = 1'b0;
    FLUSH.mem_read = 1'b0;
    FLUSH.mem_write = 1'b0;
    FLUSH.mem_byte_enable = 4'b0000;
    FLUSH.regfilemux_sel = regfilemux_sel_t'(4'b0000);
    FLUSH.load_regfile = 1'b0;
    FLUSH.rd = 5'b00000;
end

always_comb begin
    d_ready_next = d_ready;
    if (!EX_MEM.d_read && !EX_MEM.d_write) begin
        d_ready_next = 1'b1;
    end
    else if (d_cache_resp) begin
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
    end
    else if (stall) begin
        IF_ID <= IF_ID;
        ID_EX <= ID_EX;
        EX_MEM <= EX_MEM;
        MEM_WB <= MEM_WB;
        d_ready <= d_ready_next;
    end
    else begin
        IF_ID <= (flush_list[0]) ? FLUSH : new_control_word;
        ID_EX <= (flush_list[1]) ? FLUSH : IF_ID;
        EX_MEM <= (flush_list[2]) ? FLUSH : ID_EX;
        MEM_WB <= (flush_list[3]) ? FLUSH : EX_MEM;
        d_ready <= 1'b0;
    end
end

endmodule : control_word_control
