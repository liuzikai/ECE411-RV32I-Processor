`define BAD_STATE $fatal("%0t %s %0d: Illegal state", $time, `__FILE__, `__LINE__)
`define BAD_OPCODE $fatal("%0t %s %0d: Illegal opcode", $time, `__FILE__, `__LINE__)
import rv32i_types::*; /* Import types defined in rv32i_types.sv */

module control
(
    input clk,
    input rst,
    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic br_en,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input logic mem_resp,
    input logic [1:0] alu_out_2lsb,
    output pcmux::pcmux_sel_t pcmux_sel,
    output branch_funct3_t cmpop,
    output alumux::alumux1_sel_t alumux1_sel,
    output alumux::alumux2_sel_t alumux2_sel,
    output regfilemux::regfilemux_sel_t regfilemux_sel,
    output marmux::marmux_sel_t marmux_sel,
    output cmpmux::cmpmux_sel_t cmpmux_sel,
    output alu_ops aluop,
    output logic load_pc,
    output logic load_ir,
    output logic load_regfile,
    output logic load_mar,
    output logic load_mdr,
    output logic load_data_out,
    output logic mem_read,
    output logic mem_write,
    output logic [3:0] mem_byte_enable,
    output logic [1:0] mem_shift_amount
);

/***************** USED BY RVFIMON --- ONLY MODIFY WHEN TOLD *****************/
logic trap;
logic [4:0] rs1_addr, rs2_addr;
logic [3:0] rmask, wmask;

branch_funct3_t branch_funct3;
store_funct3_t store_funct3;
load_funct3_t load_funct3;
arith_funct3_t arith_funct3;

assign arith_funct3 = arith_funct3_t'(funct3);
assign branch_funct3 = branch_funct3_t'(funct3);
assign load_funct3 = load_funct3_t'(funct3);
assign store_funct3 = store_funct3_t'(funct3);
assign rs1_addr = rs1;
assign rs2_addr = rs2;

always_comb
begin : trap_check
    trap = 0;
    rmask = '0;
    wmask = '0;

    case (opcode)
        op_lui, op_auipc, op_imm, op_reg, op_jal, op_jalr:;

        op_br: begin
            case (branch_funct3)
                beq, bne, blt, bge, bltu, bgeu:;
                default: trap = 1;
            endcase
        end

        op_load: begin
            case (load_funct3)
                lw: rmask = 4'b1111;
                lh, lhu: rmask = mem_byte_enable /* Modify for MP1 Final */ ;
                lb, lbu: rmask = mem_byte_enable /* Modify for MP1 Final */ ;
                default: trap = 1;
            endcase
        end

        op_store: begin
            case (store_funct3)
                sw: wmask = 4'b1111;
                sh: wmask = mem_byte_enable /* Modify for MP1 Final */ ;
                sb: wmask = mem_byte_enable /* Modify for MP1 Final */ ;
                default: trap = 1;
            endcase
        end

        default: trap = 1;
    endcase
end
/*****************************************************************************/

enum int unsigned {
    // FETCH
    fetch1,
    fetch2,
    fetch3,
    // DECODE
    decode,
    // Register-immediate instructions
    s_imm,
    // Register-register instructions
    s_reg,
    // BR
    br,
    // Shared by LW and SW
    calc_addr,
    // LW
    ldr1,
    ldr2,
    // SW
    str1,
    str2,
    // AUIPC
    s_auipc,
    // LUI
    s_lui,
    // JAL
    s_jal,
    // JALR
    s_jalr
} state, next_state;

logic [1:0] mem_shift, next_mem_shift;

assign mem_shift_amount = mem_shift;

/************************* Function Definitions *******************************/
/**
 *  You do not need to use these functions, but it can be nice to encapsulate
 *  behavior in such a way.  For example, if you use the `loadRegfile`
 *  function, then you only need to ensure that you set the load_regfile bit
 *  to 1'b1 in one place, rather than in many.
 *
 *  SystemVerilog functions must take zero "simulation time" (as opposed to 
 *  tasks).  Thus, they are generally synthesizable, and appropraite
 *  for design code.  Arguments to functions are, by default, input.  But
 *  may be passed as outputs, inouts, or by reference using the `ref` keyword.
**/

/**
 *  Rather than filling up an always_block with a whole bunch of default values,
 *  set the default values for controller output signals in this function,
 *   and then call it at the beginning of your always_comb block.
**/
function void set_defaults();
    load_pc = 1'b0;
    load_ir = 1'b0;
    load_regfile = 1'b0;
    load_mar = 1'b0;
    load_mdr = 1'b0;
    load_data_out = 1'b0;
    pcmux_sel = pcmux::pc_plus4;
    cmpop = branch_funct3;
    alumux1_sel = alumux::rs1_out;
    alumux2_sel = alumux::i_imm;
    regfilemux_sel = regfilemux::alu_out;
    marmux_sel = marmux::pc_out;
    cmpmux_sel = cmpmux::rs2_out;
    aluop = alu_ops'(funct3);
    mem_read = 1'b0;
    mem_write = 1'b0;
    mem_byte_enable = 4'b1111;
    next_mem_shift = mem_shift;
endfunction

/**
 *  Use the next several functions to set the signals needed to
 *  load various registers
**/
function void loadPC(pcmux::pcmux_sel_t sel);
    load_pc = 1'b1;
    pcmux_sel = sel;
endfunction

function void loadRegfile(regfilemux::regfilemux_sel_t sel);
    load_regfile = 1'b1;
    regfilemux_sel = sel;
endfunction

function void loadMAR(marmux::marmux_sel_t sel);
    load_mar = 1'b1;
    marmux_sel = sel;
endfunction

function void loadMDR();
    load_mdr = 1'b1;
endfunction

function void loadIR();
    load_ir = 1'b1;
endfunction

function void loadDataOut();
    load_data_out = 1'b1;
endfunction

/**
 * SystemVerilog allows for default argument values in a way similar to
 *   C++.
**/
function void setALU(alumux::alumux1_sel_t sel1,
                               alumux::alumux2_sel_t sel2,
                               logic setop = 1'b0, alu_ops op = alu_add);
    alumux1_sel = sel1;
    alumux2_sel = sel2;

    if (setop)
        aluop = op; // else default value
endfunction

function automatic void setCMP(cmpmux::cmpmux_sel_t sel, branch_funct3_t op);
    cmpmux_sel = sel;
    cmpop = op;
endfunction

/*****************************************************************************/

    /* Remember to deal with rst signal */

always_comb
begin : state_actions
    /* Default output assignments */
    set_defaults();
    /* Actions for each state */
    unique case (state)
        fetch1: begin
            loadMAR(marmux::pc_out);
        end
        fetch2: begin
            loadMDR();
            mem_read = 1'b1;
        end
        fetch3: begin
            loadIR();
        end
        decode: begin
            // Do nothing
        end
        s_imm: begin;
            loadPC(pcmux::pc_plus4);
            if (arith_funct3 == slt) begin  // SLTI
                loadRegfile(regfilemux::br_en);
                setCMP(cmpmux::i_imm, blt);
            end else if (arith_funct3 == sltu) begin // SLTIU
                loadRegfile(regfilemux::br_en);
                setCMP(cmpmux::i_imm, bltu);
            end else if (arith_funct3 == sr && funct7[5] == 1'b1) begin  // SRAI
                loadRegfile(regfilemux::alu_out);
                setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_sra);
            end else begin
                loadRegfile(regfilemux::alu_out);
                setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_ops'(funct3));
            end
        end
        s_reg: begin
            loadPC(pcmux::pc_plus4);
            if (arith_funct3 == slt) begin  // SLT
                loadRegfile(regfilemux::br_en);
                setCMP(cmpmux::rs2_out, blt);
            end else if (arith_funct3 == sltu) begin // SLTU
                loadRegfile(regfilemux::br_en);
                setCMP(cmpmux::rs2_out, bltu);
            end else if (arith_funct3 == sr && funct7[5] == 1'b1) begin  // SRA
                loadRegfile(regfilemux::alu_out);
                setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sra);
            end else if (arith_funct3 == add && funct7[5] == 1'b1) begin  // SUB
                loadRegfile(regfilemux::alu_out);
                setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sub);
            end else begin
                loadRegfile(regfilemux::alu_out);
                setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_ops'(funct3));
            end
        end
        br: begin
            // Use default values for CMP
            if (br_en == 1'b1) loadPC(pcmux::alu_out);
            else loadPC(pcmux::pc_plus4);
            setALU(alumux::pc_out, alumux::b_imm, 1'b1, alu_add);
        end
        calc_addr: begin
            unique case(opcode)
                op_load:  begin
                    setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
                end
                op_store: begin
                    setALU(alumux::rs1_out, alumux::s_imm, 1'b1, alu_add);
                    loadDataOut();
                end
                default: `BAD_OPCODE;
            endcase
            loadMAR(marmux::alu_out);  // two LSBs of alu_out are masked as 0 to align by 4 bytes
            next_mem_shift = alu_out_2lsb;
        end
        ldr1: begin
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);  // maintain the ALU output
            loadMDR();
            mem_read = 1'b1;
        end
        ldr2: begin
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);  // maintain the ALU output
            unique case (load_funct3)
                lb:  loadRegfile(regfilemux::lb);
                lh:  loadRegfile(regfilemux::lh);
                lw:  loadRegfile(regfilemux::lw);
                lbu: loadRegfile(regfilemux::lbu);
                lhu: loadRegfile(regfilemux::lhu);
                // Where to put the read bytes/half-word is handled at the datapath
                default: $fatal("%0t %s %0d: Illegal load_funct3", $time, `__FILE__, `__LINE__);
            endcase
            loadPC(pcmux::pc_plus4);
        end
        str1: begin
            setALU(alumux::rs1_out, alumux::s_imm, 1'b1, alu_add);  // maintain the ALU output
            mem_write = 1'b1;
        end
        str2: begin
            setALU(alumux::rs1_out, alumux::s_imm, 1'b1, alu_add);  // maintain the ALU output
            loadPC(pcmux::pc_plus4);
        end
        s_auipc: begin
            setALU(alumux::pc_out, alumux::u_imm, 1'b1, alu_add);
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
        end
        s_lui: begin
            loadRegfile(regfilemux::u_imm);
            loadPC(pcmux::pc_plus4);
        end
        s_jal: begin
            loadRegfile(regfilemux::pc_plus4);
            loadPC(pcmux::alu_out);
            setALU(alumux::pc_out, alumux::j_imm, 1'b1, alu_add);
        end
        s_jalr: begin
            loadRegfile(regfilemux::pc_plus4);
            loadPC(pcmux::alu_mod2);
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
        end
        // default: `BAD_STATE;
    endcase

    // Shared by Loads and Stores
    unique case (funct3[1:0])
        2'b00: begin
            unique case (mem_shift)
                2'b00: mem_byte_enable = 4'b0001;
                2'b01: mem_byte_enable = 4'b0010;
                2'b10: mem_byte_enable = 4'b0100;
                2'b11: mem_byte_enable = 4'b1000;
                default: ;
            endcase
        end
        2'b01: begin
            unique case (mem_shift)
                2'b00: mem_byte_enable = 4'b0011;
                2'b10: mem_byte_enable = 4'b1100;
                default: ;
            endcase
        end
        2'b10: mem_byte_enable = 4'b1111;
        default: ;
    endcase
end

always_comb
begin : next_state_logic
    /* Next state information and conditions (if any)
     * for transitioning between states */
    next_state = state;  // default
    unique case(state)
        fetch1: next_state = fetch2;
        fetch2: next_state = (mem_resp ? fetch3 : fetch2);
        fetch3: next_state = decode;
        decode: begin
            unique case(opcode)
                op_imm:            next_state = s_imm;
                op_reg:            next_state = s_reg;
                op_br:             next_state = br;
                op_load, op_store: next_state = calc_addr;
                op_auipc:          next_state = s_auipc;
                op_lui:            next_state = s_lui;
                op_jal:            next_state = s_jal;
                op_jalr:           next_state = s_jalr;
                default: `BAD_OPCODE;
            endcase
        end
        s_imm, s_reg, br, s_auipc, s_lui, ldr2, str2, s_jal, s_jalr: next_state = fetch1;
        calc_addr: begin
            unique case(opcode)
                op_load:  next_state = ldr1;
                op_store: next_state = str1;
                default: `BAD_OPCODE;
            endcase
        end
        ldr1: next_state = (mem_resp ? ldr2 : ldr1);
        str1: next_state = (mem_resp ? str2 : str1);
        // default: `BAD_OPCODE;
    endcase
end

always_ff @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    if (rst) begin
        state <= fetch1;
        mem_shift <= 2'b00;
    end else begin
        state <= next_state;
        mem_shift <= next_mem_shift;
    end
end

endmodule : control
