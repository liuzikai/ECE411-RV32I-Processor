# Written by Kerui Zhu on Nov 15th, 2020

import sys

class Opcode:
    op_lui   = 0b0110111
    op_auipc = 0b0010111
    op_jal   = 0b1101111
    op_jalr  = 0b1100111
    op_br    = 0b1100011
    op_load  = 0b0000011
    op_store = 0b0100011
    op_imm   = 0b0010011
    op_reg   = 0b0110011
    op_csr   = 0b1110011
    op_none  = 0b0000000


def decode(inst):
    opcode = 0b01111111 & inst
    if opcode == Opcode.op_lui:
        rd = (inst >> 7) & 0b011111
        imm = inst >> 12
        print('lui, decode your self')
    elif opcode == Opcode.op_auipc:
        rd = (inst >> 7) & 0b011111
        imm = inst >> 12
        print('auipc, decode your self')
    elif opcode == Opcode.op_jal:
        print('jal, decode your self')
    elif opcode == Opcode.op_jalr:
        print('jalr, decode your self')
    elif opcode == Opcode.op_br:
        funct3 = (inst >> 12) & 0b0111
        rs1 = (inst >> 15) & 0b011111
        rs2 = (inst >> 20) & 0b011111
        imm11 = (inst >> 7) & 0b01
        imm4_1 = (inst >> 8) & 0b01111
        imm10_5 = (inst >> 25) & 0b0111111
        imm12 = (inst >> 31) & 0b01
        imm = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1)
        if funct3 == 0:
            print('beq x' + str(rs1) + ' x' + str(rs2) + ' ' + str(imm))
        elif funct3 == 1:
            print('bne x' + str(rs1) + ' x' + str(rs2) + ' ' + str(imm))
        elif funct3 == 4:
            print('blt x' + str(rs1) + ' x' + str(rs2) + ' ' + str(imm))
        elif funct3 == 5:
            print('bge x' + str(rs1) + ' x' + str(rs2) + ' ' + str(imm))
        elif funct3 == 6:
            print('bltu x' + str(rs1) + ' x' + str(rs2) + ' ' + str(imm))
        elif funct3 == 7:
            print('bgeu x' + str(rs1) + ' x' + str(rs2) + ' ' + str(imm))
        else:
            print('br, decode your self')
    elif opcode == Opcode.op_load:
        rd = (inst >> 7) & 0b011111
        funct3 = (inst >> 12) & 0b0111
        rs1 = (inst >> 15) & 0b011111
        imm = inst >> 20
        if funct3 == 0:
            print('lb x' + str(rd) + ' ' + str(imm) + '(x' + str(rs1) + ')')
        elif funct3 == 1:
            print('lh x' + str(rd) + ' ' + str(imm) + '(x' + str(rs1) + ')')
        elif funct3 == 2:
            print('lw x' + str(rd) + ' ' + str(imm) + '(x' + str(rs1) + ')')
        elif funct3 == 4:
            print('lbu x' + str(rd) + ' ' + str(imm) + '(x' + str(rs1) + ')')
        elif funct3 == 5:
            print('lhu x' + str(rd) + ' ' + str(imm) + '(x' + str(rs1) + ')')
        else:
            print('load, decode your self')
    elif opcode == Opcode.op_store:
        rs1 = (inst >> 15) & 0b011111
        rs2 = (inst >> 20) & 0b011111
        imm = ((inst >> 25) << 5) | ((inst >> 7) & 0b011111)
        funct3 = (inst >> 12) & 0b0111
        if funct3 == 0:
            print('sb x' + str(rs1) + ' ' + str(imm) + '(x' + str(rs2) + ')')
        elif funct3 == 1:
            print('sh x' + str(rs1) + ' ' + str(imm) + '(x' + str(rs2) + ')')
        elif funct3 == 2:
            print('sw x' + str(rs1) + ' ' + str(imm) + '(x' + str(rs2) + ')')
        else:
            print('store, decode your self')
    elif opcode == Opcode.op_imm:
        rd = (inst >> 7) & 0b011111
        funct3 = (inst >> 12) & 0b0111
        rs1 = (inst >> 15) & 0b011111
        imm = inst >> 20
        if funct3 == 0:
            print('addi x' + str(rd) + ' x' + str(rs1) + ' ' + str(imm))
        elif funct3 == 2:
            print('slti x' + str(rd) + ' x' + str(rs1) + ' ' + str(imm))
        elif funct3 == 3:
            print('sltiu x' + str(rd) + ' x' + str(rs1) + ' ' + str(imm))
        elif funct3 == 4:
            print('xori x' + str(rd) + ' x' + str(rs1) + ' ' + str(imm))
        elif funct3 == 6:
            print('ori x' + str(rd) + ' x' + str(rs1) + ' ' + str(imm))
        elif funct3 == 7:
            print('andi x' + str(rd) + ' x' + str(rs1) + ' ' + str(imm))
        else:
            print('imm, decode your self')
    elif opcode == Opcode.op_reg:
        rd = (inst >> 7) & 0b011111
        funct3 = (inst >> 12) & 0b0111
        rs1 = (inst >> 15) & 0b011111
        rs2 = (inst >> 20) & 0b011111
        imm = inst >> 25
        if funct3 == 0:
            if imm == 0:
                print('add x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
            else:
                print('sub x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        elif funct3 == 1:
            print('sll x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        elif funct3 == 2:
            print('slt x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        elif funct3 == 3:
            print('sltu x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        elif funct3 == 4:
            print('xor x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        elif funct3 == 5:
            if imm == 0:
                print('srl x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
            else:
                print('sra x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        elif funct3 == 6:
            print('or x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        elif funct3 == 7:
            print('and x' + str(rd) + ' x' + str(rs1) + ' x' + str(rs2))
        else:
            print('reg, decode your self')
    elif opcode == Opcode.op_csr:
        print('csr, decode your self')
    elif opcode == Opcode.op_none:
        print("none")
    else:
        print("Unrecognized opcode")

if __name__ == '__main__':
    decode(int(sys.argv[1], 16))