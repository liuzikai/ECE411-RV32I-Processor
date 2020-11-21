math_ops.s:
.align 4
.section .text
.globl _start

_start:
      # Test immediate instructions
      lw x1, zero
      addi x1, x1, 2
      slti x2, x1, 3
      slti x2, x1, 1

      lw x1, set
      xori x1, x1, 127
      lw x1, zero
      ori x1, x1, 127
      lw x1, set
      andi x1, x1, 0
      lui x1, 2
      srli x1, x1, 1
      slli x1, x1, 1

      # Test register-register instructions
      lui x1, 1
      srli x1, x1, 12
      lui x2, 2
      srli x2, x2, 12
      add x1, x1, x2
      sub x1, x1, x2

      sll x1, x1, x2

      slt x3, x1, x2
      slt x3, x2, x1
      lw x1, a
      lw x2, b
      lw x3, zero
      sltu x3, x1, x2
      sltu x3, x2, x1

      lui x2, 4
      srli x2, x2, 12
      srl x1, x1, x2
      sra x1, x1, x2

      lw x1, c
      lw x2, b
      xor x1, x1, x2
      lw x1, c
      lw x2, b
      and x1, x1, x2
done:
      beq x0, x0, done
.section .rodata
zero: .word 0x00000000
a:    .word 0xF0000000
b:    .word 0xF0000001
c:    .word 0xF000ABC1
set:  .word 0xFFFFFFFF
