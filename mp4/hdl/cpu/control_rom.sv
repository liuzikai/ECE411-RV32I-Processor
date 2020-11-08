import rv32i_types::*;

module control_rom
(   
    // per document requirement, the input should only have below 3 terms
    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input rv32i_word instruction, 
    // we only output control word
    output rv32i_control_word ctrl
);
// some function used by later code
function void set_defaults();
    // datapath signal
    ctrl.opcode = opcode;
    ctrl.load_pc = 1'b0;
    ctrl.load_ir = 1'b0;
    ctrl.load_regfile = 1'b0;
    ctrl.load_mdar = 1'b0;
    // ctrl.load_mddr = 1'b0;
    ctrl.load_data_out = 1'b0;
    ctrl.pcmux_sel = pcmux::pc_plus4;
    ctrl.alumux1_sel = alumux::rs1_out;
    ctrl.alumux2_sel = alumux::i_imm;
    ctrl.regfilemux_sel = regfilemux::alu_out;
    ctrl.marmux_sel = marmux::pc_out;
    ctrl.cmpmux_sel = cmpmux::rs2_out;
    ctrl.aluop = alu_ops'(funct3);
    ctrl.cmpop = branch_funct3_t'(funct3);
    // memory signal
    ctrl.i_read =1'b1;
    ctrl.d_read = 1'b0;
    ctrl.d_write = 1'b0;
    ctrl.mem_read =1'b0;
    ctrl.mem_write =1'b0;
    // ctrl.rs1=
    // ctrl.rs2=
    ctrl.rd=instruction[11:7];
    // internal register control signal
    // ctrl.alu_in1_ld = 1'b0;
    // ctrl.alu_in2_ld = 1'b0;
    // ctrl.cmp_in1_ld = 1'b0;
    // ctrl.cmp_in2_ld = 1'b0;    
    // ctrl.regfile_load_in = 1'b0;
endfunction

function void setALU(alumux::alumux1_sel_t sel1,
                               alumux::alumux2_sel_t sel2,
                               logic setop = 1'b0, alu_ops op = alu_add);
    ctrl.alumux1_sel =sel1;
    ctrl.alumux2_sel =sel2;
    if (setop)
        ctrl.aluop = op; // else default value
endfunction

function automatic void setCMP(cmpmux::cmpmux_sel_t sel, branch_funct3_t op);
    ctrl.cmpmux_sel = sel;
    ctrl.cmpop = op;
endfunction

function void loadPC(pcmux::pcmux_sel_t sel);
    ctrl.load_pc = 1'b1;
    ctrl.pcmux_sel = sel;
endfunction

function void loadRegfile(regfilemux::regfilemux_sel_t sel);
    ctrl.load_regfile = 1'b1;
    ctrl.regfilemux_sel = sel;
endfunction

function void loadMAR(marmux::marmux_sel_t sel);
    ctrl.load_mdar = 1'b1;
    ctrl.marmux_sel = sel;
endfunction

function void loadMDR();
    // ctrl.load_mddr = 1'b1;
    ctrl.d_read = 1'b1;
    ctrl.mem_read=1'b1;
endfunction

always_comb
begin
    /* Default assignments */
    set_defaults();
    /* Assign control signals based on opcode */
    case(opcode)
        op_auipc: begin //add upper immediate PC (U type)
            setALU(alumux::pc_out,alumux::u_imm,1,alu_add);
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
        end

        op_lui:begin //load upper immediate (U type)
            loadPC(pcmux::pc_plus4);
            loadRegfile(regfilemux::u_imm);
        end

        op_jal:begin//jump and link (J type)
            setALU(alumux::pc_out, alumux::j_imm, 1, alu_add); 
            loadPC(pcmux::alu_out);
            loadRegfile(regfilemux::pc_plus4);
        end

        op_jalr:begin//jump and link register (I type)
            setALU(alumux::rs1_out, alumux::i_imm, 1, alu_add); 
            loadPC(pcmux::alu_mod2);
            loadRegfile(regfilemux::pc_plus4);
        end

        op_br:begin//branch (B type)
            setALU(alumux::pc_out,alumux::b_imm,1,alu_add);
            // FIXME: set the comparator correctly to generate correct br_en
            ctrl.cmpop = branch_funct3_t'(funct3); 
            ctrl.use_br_en=1'b1;
        end

        op_load:begin//load (I type)
            // FIXME: put 2 cycles together????
            loadMDR();
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add); 
            loadPC(pcmux::pc_plus4);
            unique case(load_funct3_t'(funct3))
                rv32i_types::lb: loadRegfile(regfilemux::lb);
                rv32i_types::lh: loadRegfile(regfilemux::lh);
                rv32i_types::lw: loadRegfile(regfilemux::lw);
                rv32i_types::lbu: loadRegfile(regfilemux::lbu);
                rv32i_types::lhu: loadRegfile(regfilemux::lhu);
                default:$display("op_load error!\n");
            endcase
        end

        op_store:begin//store (S type)
            ctrl.d_write=1'b1; 
            ctrl.mem_write=1'b1;
            ctrl.load_data_out=1'b1;
            setALU(alumux::rs1_out, alumux::s_imm, 1'b1, alu_add);
            loadPC(pcmux::pc_plus4);
        end


        op_imm:begin//arith ops with register/immediate operands (I type)
            loadPC(pcmux::pc_plus4);
            unique case(arith_funct3_t'(funct3))
                slt:begin
                        setCMP(cmpmux::i_imm,blt);
                        loadRegfile(regfilemux::br_en);
                    end
                sltu:begin
                        setCMP(cmpmux::i_imm,bltu);
                        loadRegfile(regfilemux::br_en);
                    end
                sr:begin
                    if(funct7 == 7'b0100000) begin// if this is SRA
                            setALU(alumux::rs1_out,alumux::i_imm,1,alu_sra);
                            loadRegfile(regfilemux::alu_out);
                        end
                    else begin
                            setALU(alumux::rs1_out,alumux::i_imm,1,alu_srl);
                            loadRegfile(regfilemux::alu_out);
                        end
                    end
                default:begin
                        setALU(alumux::rs1_out,alumux::i_imm,1,alu_ops'(funct3));
                        loadRegfile(regfilemux::alu_out);
                    end
            endcase
        end

        op_reg:begin//arith ops with register operands (R type)
            loadPC(pcmux::pc_plus4);
            unique case(arith_funct3_t'(funct3))
                add:begin
                        if(funct7 == 7'b0100000)begin// if this is sub
                                setALU(alumux::rs1_out,alumux::rs2_out,1,alu_sub);
                                loadRegfile(regfilemux::alu_out);
                            end
                        else   begin // otherwise it is a add
                                setALU(alumux::rs1_out,alumux::rs2_out,1,alu_add);
                                loadRegfile(regfilemux::alu_out);
                            end
                    end
                sr:begin
                        if(funct7 == 7'b0100000) begin// if this is arithmetic
                                setALU(alumux::rs1_out,alumux::rs2_out,1,alu_sra);
                                loadRegfile(regfilemux::alu_out);
                            end
                        else   begin // otherwise it is a logic
                                setALU(alumux::rs1_out,alumux::rs2_out,1,alu_srl);
                                loadRegfile(regfilemux::alu_out);
                            end
                    end
                slt:begin
                        setCMP(cmpmux::rs2_out,blt);
                        loadRegfile(regfilemux::br_en);
                    end
                sltu:begin
                        setCMP(cmpmux::rs2_out,bltu);
                        loadRegfile(regfilemux::br_en);
                    end
                default:begin
                        setALU(alumux::rs1_out,alumux::rs2_out,1,alu_ops'(funct3));
                        loadRegfile(regfilemux::alu_out);
                    end
            endcase
        end

        op_csr:begin //control and status register (I type)
            // we do not have to implement related instruciton
            ctrl = 0;  
        end

        default: begin
            ctrl = 0;   /* Unknown opcode, set control word to zero */
        end

    endcase
end

endmodule : control_rom