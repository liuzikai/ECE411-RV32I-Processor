`define BAD_STATE $fatal("%0t %s %0d: Illegal state", $time, `__FILE__, `__LINE__)
`define BAD_OPCODE $fatal("%0t %s %0d: Illegal opcode", $time, `__FILE__, `__LINE__)
import rv32i_types::*; /* Import types defined in rv32i_types.sv */

module control
(
    input clk,
    input rst,

    // IR for control word
    input rv32i_word instruction,

    // Branch information
    input logic br_en,

    // IF-ID
    output cmpmux::cmpmux1_sel_t cmpmux1_sel,
    output cmpmux::cmpmux2_sel_t cmpmux2_sel,
    output alumux::alumux1_sel_t alumux1_sel,
    output alumux::alumux2_sel_t alumux2_sel,
    output mwdrmux::mwdrmux_sel_t mwdrmux_sel,

    // ID-EX
    output alu_ops aluop,
    output branch_funct3_t cmpop,
    output pcmux::pcmux_sel_t pcmux_sel,

    // EX-MEM
    output logic d_read,
    output logic d_write,
    output logic [3:0] d_byte_enable,
    output wbdatamux::wbdatamux_sel_t wbdatamux_sel,

    // MEM-WB
    output logic regfile_wb,
    output rv32i_reg regfile_rd,

    // General registers
    input logic i_resp,
    input logic d_resp,

    output logic stall_id,
    output logic stall_ex,
    output logic stall_mem,
    output logic stall_wb
);

rv32i_control_word new_control_word, IF_ID, ID_EX, EX_MEM, MEM_WB;  // control word register
rv32i_reg_pack new_reg_pack, IF_ID_reg, ID_EX_reg, EX_MEM_reg, MEM_WB_reg;  // reg_pack
rv32i_control_word FLUSH;  // constant
rv32i_reg_pack FLUSH_reg;  // constant reg

logic [3:0] flush_list;
logic stall_all, stall_decode;
logic d_ready, d_ready_next;

assign stall_id = stall_all || stall_decode;
assign stall_ex = stall_all;
assign stall_mem = stall_all;
assign stall_wb = stall_all;
assign stall_all = (!i_resp) || (!d_ready_next);

function void set_defaults();
    // IF-ID
    cmpmux1_sel = IF_ID.cmpmux1_sel;
    cmpmux2_sel = IF_ID.cmpmux2_sel;
    alumux1_sel = IF_ID.alumux1_sel;
    alumux2_sel = IF_ID.alumux2_sel;
    mwdrmux_sel = IF_ID.mwdrmux_sel;

    // ID-EX
    aluop = ID_EX.aluop;
    cmpop = ID_EX.cmpop;
    pcmux_sel = ID_EX.pcmux_sel;

    // EX-MEM
    d_read = EX_MEM.d_read;
    d_write = EX_MEM.d_write;
    d_byte_enable = EX_MEM.d_byte_enable;
    wbdatamux_sel = EX_MEM.wbdatamux_sel;

    // MEM-WB
    regfile_wb = MEM_WB.regfile_wb;
    regfile_rd = MEM_WB_reg.rd;

    // Internal Register
    stall_decode = 1'b0;
    flush_list = 4'b0000;
endfunction

control_rom control_rom(
    .opcode(rv32i_opcode'(instruction[6:0])),
    .funct3(instruction[14:12]),
    .funct7(instruction[31:25]),
    .ctrl(new_control_word)
);

always_comb begin : NEW_REG_PACK_ASSIGN
    new_reg_pack.rs1 = instruction[19:15];
    new_reg_pack.rs2 = instruction[24:20];
    new_reg_pack.rd = instruction[11:7];
end

always_comb begin : FLUSH_ASSIGN
    FLUSH.opcode = op_none;
    FLUSH.alumux1_sel = alumux::alumux1_sel_t'(1'b0);
    FLUSH.alumux2_sel = alumux::alumux2_sel_t'(3'b000);
    FLUSH.wbdatamux_sel = wbdatamux::wbdatamux_sel_t'(4'b0000);
    FLUSH.cmpmux1_sel = cmpmux::cmpmux1_sel_t'(2'b00);
    FLUSH.cmpmux2_sel = cmpmux::cmpmux2_sel_t'(3'b000);
    FLUSH.mwdrmux_sel = mwdrmux::mwdrmux_sel_t'(2'b00);
    FLUSH.use_cmp = 1'b0;
    FLUSH.use_cmp_output = 1'b0;
    FLUSH.aluop = alu_ops'(3'b000);
    FLUSH.cmpop = branch_funct3_t'(3'b000);
    FLUSH.pcmux_sel = pcmux::pc_plus4;
    FLUSH.d_read = 1'b0;
    FLUSH.d_write = 1'b0;
    FLUSH.d_byte_enable = 4'b0000;
    FLUSH.regfile_wb = 1'b0;
    FLUSH.rs1_read = 1'b0;
    FLUSH.rs2_read = 1'b0;

    FLUSH_reg.rs1 = rv32i_reg'(5'b00000);
    FLUSH_reg.rs2 = rv32i_reg'(5'b00000);
    FLUSH_reg.rd = rv32i_reg'(5'b00000);
end

always_comb begin : MAIN_COMB
    set_defaults();
    if ((ID_EX.opcode == op_br && br_en) || ID_EX.opcode == op_jal || ID_EX.opcode == op_jalr) begin
        flush_list[1:0] = 2'b11; // Flush the IF_ID and ID_EX control words
    end
    if (IF_ID.rs1_read && IF_ID_reg.rs1) begin
        // rs1 should be considered
        if (ID_EX.regfile_wb && ID_EX_reg.rd == IF_ID_reg.rs1) begin
            if (ID_EX.opcode == op_load) begin
                stall_decode = 1'b1; // Stall the update of IF_ID
                flush_list[1] = 1'b1; // Insert bubble to the ID_EX
            end else if (IF_ID.use_cmp == 1'b1) begin
                cmpmux1_sel = (ID_EX.use_cmp_output) ? cmpmux::cmpmux1_cmp_out : cmpmux::cmpmux1_alu_out;
            end else begin
                alumux1_sel = (ID_EX.use_cmp_output) ? alumux::alumux1_cmp_out : alumux::alumux1_alu_out;
            end
        end
        else if (EX_MEM.regfile_wb && EX_MEM_reg.rd == IF_ID_reg.rs1) begin
            if (IF_ID.use_cmp == 1'b1) begin
                cmpmux1_sel = cmpmux::cmpmux1_wbdatamux_out;
            end else begin
                alumux1_sel = alumux::alumux1_wbdatamux_out;
            end
        end
        else if (MEM_WB.regfile_wb && MEM_WB_reg.rd == IF_ID_reg.rs1) begin
            if (IF_ID.use_cmp == 1'b1) begin
                cmpmux1_sel = cmpmux::cmpmux1_wbdata_out;
            end else begin
                alumux1_sel = alumux::alumux1_wbdata_out;
            end
        end
    end
    if (IF_ID.rs2_read && IF_ID_reg.rs2) begin
        // rs2 should be considered
        if (ID_EX.regfile_wb && ID_EX_reg.rd == IF_ID_reg.rs2) begin
            if (ID_EX.opcode == op_load) begin
                stall_decode = 1'b1; // Stall the update of IF_ID
                flush_list[1] = 1'b1; // Insert bubble to the ID_EX
            end else if (IF_ID.use_cmp == 1'b1) begin
                cmpmux2_sel = (ID_EX.use_cmp_output) ? cmpmux::cmpmux2_cmp_out : cmpmux::cmpmux2_alu_out;
            end else if (IF_ID.opcode == op_store) begin
                mwdrmux_sel = (ID_EX.use_cmp_output) ? mwdrmux::mwdrmux_cmp_out : mwdrmux::mwdrmux_alu_out;
            end else begin
                alumux2_sel = (ID_EX.use_cmp_output) ? alumux::alumux2_cmp_out : alumux::alumux2_alu_out;
            end
        end else if (EX_MEM.regfile_wb && EX_MEM_reg.rd == IF_ID_reg.rs2) begin
            if (IF_ID.use_cmp == 1'b1) begin
                cmpmux2_sel = cmpmux::cmpmux2_wbdatamux_out;
            end else if (IF_ID.opcode == op_store) begin
                mwdrmux_sel = mwdrmux::mwdrmux_wbdatamux_out;
            end else begin
                alumux2_sel = alumux::alumux2_wbdatamux_out;
            end
        end else if (MEM_WB.regfile_wb && MEM_WB_reg.rd == IF_ID_reg.rs2) begin
            if (IF_ID.use_cmp == 1'b1) begin
                cmpmux2_sel = cmpmux::cmpmux2_wbdata_out;
            end else if (IF_ID.opcode == op_store) begin
                mwdrmux_sel = mwdrmux::mwdrmux_wbdata_out;
            end else begin
                alumux2_sel = alumux::alumux2_wbdata_out;
            end
        end
    end
end

always_comb begin : DATA_READY_CHECK
    d_ready_next = d_ready;
    if (!EX_MEM.d_read && !EX_MEM.d_write) begin
        d_ready_next = 1'b1;
    end else if (d_resp) begin
        d_ready_next = 1'b1;
    end
end

always_ff @(posedge clk) begin : FF
    if (rst) begin
        IF_ID <= FLUSH;
        ID_EX <= FLUSH;
        EX_MEM <= FLUSH;
        MEM_WB <= FLUSH;
        d_ready <= 1'b0;
        IF_ID_reg <= FLUSH_reg;
        ID_EX_reg <= FLUSH_reg;
        EX_MEM_reg <= FLUSH_reg;
        MEM_WB_reg <= FLUSH_reg;
    end else if (stall_all) begin
        IF_ID <= IF_ID;
        ID_EX <= ID_EX;
        EX_MEM <= EX_MEM;
        MEM_WB <= MEM_WB;
        d_ready <= d_ready_next;
        IF_ID_reg <= IF_ID_reg;
        ID_EX_reg <= ID_EX_reg;
        EX_MEM_reg <= EX_MEM_reg;
        MEM_WB_reg <= MEM_WB_reg;
    end else begin
        IF_ID <= (stall_decode) ? IF_ID : ((flush_list[0]) ? FLUSH : new_control_word);
        ID_EX <= (flush_list[1]) ? FLUSH : IF_ID;
        EX_MEM <= (flush_list[2]) ? FLUSH : ID_EX;
        MEM_WB <= (flush_list[3]) ? FLUSH : EX_MEM;
        d_ready <= 1'b0;
        IF_ID_reg <= (stall_decode) ? IF_ID_reg : ((flush_list[0]) ? FLUSH_reg : new_reg_pack);
        ID_EX_reg <= (flush_list[1]) ? FLUSH_reg : IF_ID_reg;
        EX_MEM_reg <= (flush_list[2]) ? FLUSH_reg : ID_EX_reg;
        MEM_WB_reg <= (flush_list[3]) ? FLUSH_reg : EX_MEM_reg;
    end
end

endmodule : control
