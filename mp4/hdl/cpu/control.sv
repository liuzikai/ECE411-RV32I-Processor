`define BAD_STATE $fatal("%0t %s %0d: Illegal state", $time, `__FILE__, `__LINE__)
`define BAD_OPCODE $fatal("%0t %s %0d: Illegal opcode", $time, `__FILE__, `__LINE__)
import rv32i_types::*; /* Import types defined in rv32i_types.sv */

module control
(
    input clk,
    input rst,

    // IR for control word
    input rv32i_word instruction,

    // ID
    output cmpmux::cmpmux2_sel_t cmpmux2_sel,
    output alumux::alumux1_sel_t alumux1_sel,
    output alumux::alumux2_sel_t alumux2_sel,
    output rsmux::rsmux_sel_t rs1mux_sel,
    output rsmux::rsmux_sel_t rs2mux_sel,

    // EX
    output alu_ops aluop,
    output branch_funct3_t cmpop,
    output pcmux::pcmux_sel_t pcmux_sel,
    input  logic ex_load_pc,

    // MEM
    output logic d_read,
    output logic d_write,
    output logic [3:0] d_byte_enable,
    output wbdatamux::wbdatamux_sel_t wbdatamux_sel,

    // WB
    output rv32i_reg regfile_rd,

    // Input from memory
    input logic i_resp,
    input logic d_resp,

    // Stall signals to datapath
    output logic stall_id,
    output logic stall_ex,
    output logic stall_mem,
    output logic stall_wb
);

rv32i_control_word if_id, id_ex, ex_mem, mem_wb;  // registers
rv32i_control_word FLUSH;                         // constant
rv32i_control_word new_control_word;              // internal wires

logic [3:0] flush_list;
logic stall_all, stall_decode;
logic d_ready, d_ready_next;

assign stall_id  = stall_all || stall_decode;
assign stall_ex  = stall_all;
assign stall_mem = stall_all;
assign stall_wb  = stall_all;
assign stall_all = (!i_resp) || (!d_ready_next);

function void set_defaults();
    // ID
    alumux1_sel = if_id.alumux1_sel;
    alumux2_sel = if_id.alumux2_sel;
    cmpmux2_sel = if_id.cmpmux2_sel;
    rs1mux_sel = rsmux::regfile_out;
    rs2mux_sel = rsmux::regfile_out;

    // EX
    aluop = id_ex.aluop;
    cmpop = id_ex.cmpop;
    pcmux_sel = id_ex.pcmux_sel;

    // MEM
    d_read = ex_mem.d_read;
    d_write = ex_mem.d_write;
    d_byte_enable = ex_mem.d_byte_enable;
    wbdatamux_sel = ex_mem.wbdatamux_sel;

    // WB
    regfile_rd = mem_wb.rd;

    // Internal Register
    stall_decode = 1'b0;
    flush_list = 4'b0000;
endfunction

control_rom control_rom(
    .opcode(rv32i_opcode'(instruction[6:0])),
    .funct3(instruction[14:12]),
    .funct7(instruction[31:25]),
    .rs1(instruction[19:15]),
    .rs2(instruction[24:20]),
    .rd(instruction[11:7]),
    .ctrl(new_control_word)
);

always_comb begin : FLUSH_ASSIGN
    FLUSH.opcode = op_none;
    FLUSH.alumux1_sel = alumux::alumux1_sel_t'(1'b0);
    FLUSH.alumux2_sel = alumux::alumux2_sel_t'(3'b000);
    FLUSH.cmpmux2_sel = cmpmux::cmpmux2_sel_t'(1'b0);
    FLUSH.wbdatamux_sel = wbdatamux::wbdatamux_sel_t'(4'b0000);
    FLUSH.aluop = alu_ops'(3'b000);
    FLUSH.cmpop = branch_funct3_t'(3'b000);
    FLUSH.pcmux_sel = pcmux::pc_plus4;
    FLUSH.d_read = 1'b0;
    FLUSH.d_write = 1'b0;
    FLUSH.d_byte_enable = 4'b0000;
    FLUSH.rs1 = rv32i_reg'(5'b00000);
    FLUSH.rs2 = rv32i_reg'(5'b00000);
    FLUSH.rd = rv32i_reg'(5'b00000);
end

always_comb begin : MAIN_COMB
    set_defaults();

    // Handle branch mispredict
    if (ex_load_pc) begin
        flush_list[1:0] = 2'b11;  // flush the if_id and id_ex control words
    end

    // rs1 forwarding
    if (if_id.rs1) begin
        // rs1 should be considered

        // When equal, since rs1 is not 0, rd must be non-zero either
        if (id_ex.rd == if_id.rs1) begin
            // 1-stage forwarding

            if (id_ex.wbdatamux_sel[3] == 1'b1) begin
                // Is load function, see wbdatamux_sel_t encoding

                stall_decode = 1'b1;   // stall the update of if_id
                flush_list[1] = 1'b1;  // insert bubble to the id_ex

                // At next cycle, the 2-stage forwarding (below) will match
            end else 
                // Is not load function

                // See wbdatamux_sel_t encoding
                rs1mux_sel = rsmux_sel_t'(id_ex.wbdatamux_sel[2:0]);
            end

        end else if (ex_mem.rd == if_id.rs1) begin
            // 2-stage forwarding

            rs1mux_sel = wbdatamux_out;  // wbdatamux_sel already applied

        end else if (mem_wb.rd == if_id.rs1) begin
            // 3-stage forwarding

            rs1mux_sel = wbdata_out;  // wbdatamux_sel already applied
        end
    end

    // rs2 forwarding
    if (if_id.rs2) begin
        // rs2 should be considered

        // When equal, since rs2 is not 0, rd must be non-zero either
        if (id_ex.rd == if_id.rs2) begin
            // 1-stage forwarding

            if (id_ex.wbdatamux_sel[3] == 1'b1) begin
                // Is load function, see wbdatamux_sel_t encoding

                stall_decode = 1'b1;   // stall the update of if_id
                flush_list[1] = 1'b1;  // insert bubble to the id_ex

                // At next cycle, the 2-stage forwarding (below) will match
            end else 
                // Is not load function

                // See wbdatamux_sel_t encoding
                rs2mux_sel = rsmux_sel_t'(id_ex.wbdatamux_sel[2:0]);
            end

        end else if (ex_mem.rd == if_id.rs2) begin
            // 2-stage forwarding

            rs2mux_sel = wbdatamux_out;  // wbdatamux_sel already applied

        end else if (mem_wb.rd == if_id.rs2) begin
            // 3-stage forwarding

            rs2mux_sel = wbdata_out;  // wbdatamux_sel already applied
        end
    end

end

always_comb begin : DATA_READY_CHECK
    d_ready_next = d_ready;
    if (!ex_mem.d_read && !ex_mem.d_write) begin
        d_ready_next = 1'b1;
    end else if (d_resp) begin
        d_ready_next = 1'b1;
    end
end

always_ff @(posedge clk) begin : FF
    if (rst) begin
        if_id <= FLUSH;
        id_ex <= FLUSH;
        ex_mem <= FLUSH;
        mem_wb <= FLUSH;
        d_ready <= 1'b0;
    end else if (stall_all) begin
        if_id <= if_id;
        id_ex <= id_ex;
        ex_mem <= ex_mem;
        mem_wb <= mem_wb;
        d_ready <= d_ready_next;
    end else begin
        if_id <= (stall_decode) ? if_id : ((flush_list[0]) ? FLUSH : new_control_word);
        id_ex <= (flush_list[1]) ? FLUSH : if_id;
        ex_mem <= (flush_list[2]) ? FLUSH : id_ex;
        mem_wb <= (flush_list[3]) ? FLUSH : ex_mem;
        d_ready <= 1'b0;
    end
end

endmodule : control
