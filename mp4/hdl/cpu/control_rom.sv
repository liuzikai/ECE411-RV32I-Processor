import rv32i_types::*;

module control_rom (   

    // Inputs
    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,

    // Output control word
    output rv32i_control_word ctrl
);


function void set_defaults();

    ctrl.opcode = opcode;

    // MUX and function selections
    ctrl.alumux1_sel = alumux::rs1_out;
    ctrl.alumux2_sel = alumux::i_imm;
    ctrl.wbdatamux_sel = wbdatamux::alu_out;
    ctrl.cmpmux1_sel = cmpmux::rs1_out;
    ctrl.cmpmux2_sel = cmpmux::rs2_out;
    ctrl.mwdrmux_sel = mwdrmux::rs2_out;
    ctrl.use_cmp = 1'b0;
    ctrl.use_cmp_output = 1'b0;
    ctrl.aluop = alu_ops'(funct3);
    ctrl.cmpop = branch_funct3_t'(funct3);

    // For BR/JAL/JALR instruction in EX stage
    ctrl.pcmux_sel = pcmux::pc_plus4;

    // MEM stage control signals
    ctrl.d_read = 1'b0;
    ctrl.d_write = 1'b0;
    ctrl.d_byte_enable = 4'b0000;

    // WB stage control signals
    ctrl.regfile_wb = 1'b0;
    ctrl.rs1_read = 1'b0;
    ctrl.rs2_read = 1'b0;

endfunction

function void setALU(alumux::alumux1_sel_t sel1,
                     alumux::alumux2_sel_t sel2,
                     alu_ops op = alu_add);
    ctrl.alumux1_sel = sel1;
    ctrl.alumux2_sel = sel2;
    ctrl.aluop = op;
endfunction

function automatic void setCMP(cmpmux::cmpmux2_sel_t sel, branch_funct3_t op);
    ctrl.cmpmux2_sel = sel;
    ctrl.cmpop = op;
endfunction

function void loadPC(pcmux::pcmux_sel_t sel);
    ctrl.pcmux_sel = sel;
endfunction

function void loadRegfile(wbdatamux::wbdatamux_sel_t sel);
    ctrl.regfile_wb = 1'b1;
    ctrl.wbdatamux_sel = sel;
endfunction

always_comb begin

    // Default assignments
    set_defaults();

    // Assign control signals based on opcode
    unique case (opcode)
        op_auipc: begin  // add upper immediate PC (U type)
            setALU(alumux::pc_out, alumux::u_imm, alu_add);
            loadRegfile(wbdatamux::alu_out);
        end
        op_lui: begin  // load upper immediate (U type)
            setALU(alumux::zero, alumux::u_imm, alu_add);
            loadRegfile(wbdatamux::u_imm);
        end
        op_jal: begin  // jump and link (J type)
            setALU(alumux::pc_out, alumux::j_imm, alu_add); 
            loadPC(pcmux::alu_out);
            loadRegfile(wbdatamux::pc_plus4);
        end
        op_jalr: begin  // jump and link register (I type)
            setALU(alumux::rs1_out, alumux::i_imm, alu_add); 
            loadPC(pcmux::alu_mod2);
            loadRegfile(wbdatamux::pc_plus4);
            ctrl.rs1_read = 1'b1;
        end
        op_br: begin  // branch (B type)
            setALU(alumux::pc_out, alumux::b_imm, alu_add);
            loadPC(pcmux::br);
            ctrl.rs1_read = 1'b1;
            ctrl.rs2_read = 1'b1;
            ctrl.use_cmp = 1'b1;
        end
        op_load: begin  // load (I type)
            setALU(alumux::rs1_out, alumux::i_imm, alu_add); 
            ctrl.d_read = 1'b1;
            // TODO: may optimize out this mux by rearranging mux literals
            unique case(load_funct3_t'(funct3))
                lb:  loadRegfile(wbdatamux::lb);
                lh:  loadRegfile(wbdatamux::lh);
                lw:  loadRegfile(wbdatamux::lw);
                lbu: loadRegfile(wbdatamux::lbu);
                lhu: loadRegfile(wbdatamux::lhu);
                default: $fatal("%0t %s %0d: Illegal load_funct3", $time, `__FILE__, `__LINE__);
            endcase
            unique case(load_funct3_t'(funct3))
                lb, lbu:  ctrl.d_byte_enable = 4'b0001; 
                lh, lhu:  ctrl.d_byte_enable = 4'b0011;
                lw:       ctrl.d_byte_enable = 4'b1111;
                default: $fatal("%0t %s %0d: Illegal load_funct3", $time, `__FILE__, `__LINE__);
            endcase
            ctrl.rs1_read = 1'b1;
        end
        op_store: begin  // store (S type)
            setALU(alumux::rs1_out, alumux::s_imm, alu_add);
            ctrl.d_write = 1'b1; 
            unique case(store_funct3_t'(funct3))
                sb : ctrl.d_byte_enable = 4'b0001; 
                sh : ctrl.d_byte_enable = 4'b0011;
                sw : ctrl.d_byte_enable = 4'b1111;
                default: $fatal("%0t %s %0d: Illegal store_funct3", $time, `__FILE__, `__LINE__);
            endcase
            ctrl.rs1_read = 1'b1;
            ctrl.rs2_read = 1'b1;
        end
        op_imm: begin  // arith ops with register/immediate operands (I type)
            // TODO: these nested muxes may be too long
            unique case (arith_funct3_t'(funct3))
                slt: begin
                    setCMP(cmpmux::i_imm, blt);
                    loadRegfile(wbdatamux::br_en);
                    ctrl.use_cmp = 1'b1;
                    ctrl.use_cmp_output = 1'b1;
                end
                sltu: begin
                    setCMP(cmpmux::i_imm, bltu);
                    loadRegfile(wbdatamux::br_en);
                    ctrl.use_cmp = 1'b1;
                    ctrl.use_cmp_output = 1'b1;
                end
                sr: begin
                    if (funct7 == 7'b0100000) begin  // if this is SRA
                        setALU(alumux::rs1_out, alumux::i_imm, alu_sra);
                        loadRegfile(wbdatamux::alu_out);
                    end else begin
                        setALU(alumux::rs1_out, alumux::i_imm, alu_srl);
                        loadRegfile(wbdatamux::alu_out);
                    end
                end
                default: begin
                    setALU(alumux::rs1_out, alumux::i_imm, alu_ops'(funct3));
                    loadRegfile(wbdatamux::alu_out);
                end
            endcase
            ctrl.rs1_read = 1'b1;
        end
        op_reg: begin  // arith ops with register operands (R type)
            // TODO: these nested muxes may be too long
            unique case (arith_funct3_t'(funct3))
                add: begin
                    if (funct7 == 7'b0100000) begin  // sub
                        setALU(alumux::rs1_out, alumux::rs2_out, alu_sub);
                        loadRegfile(wbdatamux::alu_out);
                    end else begin  // add
                        setALU(alumux::rs1_out, alumux::rs2_out, alu_add);
                        loadRegfile(wbdatamux::alu_out);
                    end
                end
                sr: begin
                    if (funct7 == 7'b0100000) begin  // arithmetic
                        setALU(alumux::rs1_out, alumux::rs2_out, alu_sra);
                        loadRegfile(wbdatamux::alu_out);
                    end else begin  // logic
                        setALU(alumux::rs1_out, alumux::rs2_out, alu_srl);
                        loadRegfile(wbdatamux::alu_out);
                    end
                end
                slt: begin
                    setCMP(cmpmux::rs2_out, blt);
                    loadRegfile(wbdatamux::br_en);
                    ctrl.use_cmp = 1'b1;
                    ctrl.use_cmp_output = 1'b1;
                end
                sltu: begin
                    setCMP(cmpmux::rs2_out, bltu);
                    loadRegfile(wbdatamux::br_en);
                    ctrl.use_cmp = 1'b1;
                    ctrl.use_cmp_output = 1'b1;
                end
                default: begin
                    setALU(alumux::rs1_out, alumux::rs2_out, alu_ops'(funct3));
                    loadRegfile(wbdatamux::alu_out);
                end
            endcase
            ctrl.rs1_read = 1'b1;
            ctrl.rs2_read = 1'b1;
        end
        default: ;  // use default control word
    endcase
end

endmodule : control_rom