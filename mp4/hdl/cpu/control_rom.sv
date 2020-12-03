import rv32i_types::*;

module control_rom (   

    // Inputs
    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input rv32i_reg rs1,
    input rv32i_reg rs2,
    input rv32i_reg rd,

    // Output control word
    output rv32i_control_word ctrl
);


function void set_defaults();

    // Common
    ctrl.opcode = opcode;

    // ID
    ctrl.alumux1_sel = alumux::rs1_out;
    ctrl.alumux2_sel = alumux::i_imm;
    ctrl.cmpmux2_sel = cmpmux::rs2_out;
    ctrl.rs1 = rv32i_reg'(5'b00000);
    ctrl.rs2 = rv32i_reg'(5'b00000);

    // EX
    ctrl.aluop = alu_ops'(funct3);
    ctrl.cmpop = branch_funct3_t'(funct3);
    // For BR/JAL/JALR instruction in EX stage
    ctrl.expcmux_sel = expcmux::none;

    // MEM
    ctrl.d_read = 1'b0;
    ctrl.d_write = 1'b0;
    ctrl.d_byte_enable = 4'b0000;
    ctrl.wbdatamux_sel = wbdatamux::alu_out;

    // WB
    ctrl.rd = rv32i_reg'(5'b00000);

endfunction

function void set_alu(alumux::alumux1_sel_t sel1,
                      alumux::alumux2_sel_t sel2,
                      alu_ops op = alu_add);
    ctrl.alumux1_sel = sel1;
    ctrl.alumux2_sel = sel2;
    ctrl.aluop = op;
endfunction

function automatic void set_cmp(cmpmux::cmpmux2_sel_t sel, branch_funct3_t op);
    ctrl.cmpmux2_sel = sel;
    ctrl.cmpop = op;
endfunction

function void load_pc_at_ex(expcmux::expcmux_sel_t sel);
    ctrl.expcmux_sel = sel;
endfunction

function void load_regfile(wbdatamux::wbdatamux_sel_t sel);
    ctrl.rd = rd;
    ctrl.wbdatamux_sel = sel;
endfunction

always_comb begin

    // Default assignments
    set_defaults();

    // Assign control signals based on opcode
    unique case (opcode)
        op_auipc: begin  // add upper immediate PC (U type)
            set_alu(alumux::pc_out, alumux::u_imm, alu_add);
            load_regfile(wbdatamux::alu_out);
        end
        op_lui: begin  // load upper immediate (U type)
            load_regfile(wbdatamux::u_imm);
        end
        op_jal: begin  // jump and link (J type)
            set_alu(alumux::pc_out, alumux::j_imm, alu_add); 
            load_pc_at_ex(expcmux::alu_out);
            load_regfile(wbdatamux::pc_plus4);
        end
        op_jalr: begin  // jump and link register (I type)
            set_alu(alumux::rs1_out, alumux::i_imm, alu_add); 
            load_pc_at_ex(expcmux::alu_mod2);
            load_regfile(wbdatamux::pc_plus4);
            ctrl.rs1 = rs1;
        end
        op_br: begin  // branch (B type)
            set_alu(alumux::pc_out, alumux::b_imm, alu_add);
            load_pc_at_ex(expcmux::br);
            ctrl.rs1 = rs1;
            ctrl.rs2 = rs2;
        end
        op_load: begin  // load (I type)
            set_alu(alumux::rs1_out, alumux::i_imm, alu_add); 
            ctrl.d_read = 1'b1;
            // TODO: may optimize out this mux by rearranging mux literals
            unique case(load_funct3_t'(funct3))
                lb:  load_regfile(wbdatamux::lb);
                lh:  load_regfile(wbdatamux::lh);
                lw:  load_regfile(wbdatamux::lw);
                lbu: load_regfile(wbdatamux::lbu);
                lhu: load_regfile(wbdatamux::lhu);
                default: ;//$fatal("%0t %s %0d: Illegal load_funct3", $time, `__FILE__, `__LINE__);
            endcase
            unique case(load_funct3_t'(funct3))
                lb, lbu:  ctrl.d_byte_enable = 4'b0001; 
                lh, lhu:  ctrl.d_byte_enable = 4'b0011;
                lw:       ctrl.d_byte_enable = 4'b1111;
                default:;// $fatal("%0t %s %0d: Illegal load_funct3", $time, `__FILE__, `__LINE__);
            endcase
            ctrl.rs1 = rs1;
        end
        op_store: begin  // store (S type)
            set_alu(alumux::rs1_out, alumux::s_imm, alu_add);
            ctrl.d_write = 1'b1; 
            unique case(store_funct3_t'(funct3))
                sb : ctrl.d_byte_enable = 4'b0001; 
                sh : ctrl.d_byte_enable = 4'b0011;
                sw : ctrl.d_byte_enable = 4'b1111;
                default:;// $fatal("%0t %s %0d: Illegal store_funct3", $time, `__FILE__, `__LINE__);
            endcase
            ctrl.rs1 = rs1;
            ctrl.rs2 = rs2;
        end
        op_imm: begin  // arith ops with register/immediate operands (I type)
            // TODO: these nested muxes may be too long
            unique case (arith_funct3_t'(funct3))
                slt: begin
                    set_cmp(cmpmux::i_imm, blt);
                    load_regfile(wbdatamux::br_en);
                end
                sltu: begin
                    set_cmp(cmpmux::i_imm, bltu);
                    load_regfile(wbdatamux::br_en);
                end
                sr: begin
                    if (funct7 == 7'b0100000) begin  // if this is SRA
                        set_alu(alumux::rs1_out, alumux::i_imm, alu_sra);
                        load_regfile(wbdatamux::alu_out);
                    end else begin
                        set_alu(alumux::rs1_out, alumux::i_imm, alu_srl);
                        load_regfile(wbdatamux::alu_out);
                    end
                end
                default: begin
                    set_alu(alumux::rs1_out, alumux::i_imm, alu_ops'(funct3));
                    load_regfile(wbdatamux::alu_out);
                end
            endcase
            ctrl.rs1 = rs1;
        end
        op_reg: begin  // arith ops with register operands (R type)
            // TODO: these nested muxes may be too long
            unique case (arith_funct3_t'(funct3))
                add: begin
                    if (funct7 == 7'b0100000) begin  // sub
                        set_alu(alumux::rs1_out, alumux::rs2_out, alu_sub);
                        load_regfile(wbdatamux::alu_out);
                    end else begin  // add
                        set_alu(alumux::rs1_out, alumux::rs2_out, alu_add);
                        load_regfile(wbdatamux::alu_out);
                    end
                end
                sr: begin
                    if (funct7 == 7'b0100000) begin  // arithmetic
                        set_alu(alumux::rs1_out, alumux::rs2_out, alu_sra);
                        load_regfile(wbdatamux::alu_out);
                    end else begin  // logic
                        set_alu(alumux::rs1_out, alumux::rs2_out, alu_srl);
                        load_regfile(wbdatamux::alu_out);
                    end
                end
                slt: begin
                    set_cmp(cmpmux::rs2_out, blt);
                    load_regfile(wbdatamux::br_en);
                end
                sltu: begin
                    set_cmp(cmpmux::rs2_out, bltu);
                    load_regfile(wbdatamux::br_en);
                end
                default: begin
                    set_alu(alumux::rs1_out, alumux::rs2_out, alu_ops'(funct3));
                    load_regfile(wbdatamux::alu_out);
                end
            endcase
            ctrl.rs1 = rs1;
            ctrl.rs2 = rs2;
        end
        default: ;  // use default control word
    endcase
end

endmodule : control_rom