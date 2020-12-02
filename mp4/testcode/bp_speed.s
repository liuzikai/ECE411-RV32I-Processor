bp_speed.s:
.align 4
.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    and x1, x0, x0
    addi x2, x0, 1

    # Normal loop test
    
    ld x3, loop_num
normal_loop_test:
    beq x1, x3, dense_take_branch_test
    add x1, x1, x2
    beq x1, x1, normal_loop_test
    jal deadend


halt:                 # Infinite loop to keep the processor
    beq x0, x0, halt  # from trying to execute the data below.
                      # Your own programs should also make use
                      # of an infinite loop at the end.

deadend:
    lw x8, bad     # X8 <= 0xdeadbeef
deadloop:
    beq x8, x8, deadloop

.section .rodata

loop_num:   .word 0x00000FFF
testslot:   .word 0x00000000
testaddr:   .word testslot
testdata:   .word 0xABCDEF01

bad:        .word 0xdeadbeef
threshold:  .word 0x00000040
result:     .word 0x00000000
good:       .word 0x600d600d
