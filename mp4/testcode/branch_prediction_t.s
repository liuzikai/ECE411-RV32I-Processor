branch_prediction_t.s:
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

    addi x3, x0, 20
normal_loop_test:
    beq x1, x3, dense_take_branch_test
    add x1, x1, x2
    beq x1, x1, normal_loop_test
    jal deadend

dense_take_branch_test:
take_1: beq x1, x3, take_2
    jal deadend
    jal deadend
take_2: beq x1, x3, take_3
    jal deadend
    jal deadend
take_3: beq x1, x3, take_4
    jal deadend
    jal deadend
take_4: beq x1, x3, take_5
    jal deadend
    jal deadend
take_5: beq x1, x3, take_6
    jal deadend
    jal deadend
take_6: beq x1, x3, take_7
    jal deadend
    jal deadend
take_7: beq x1, x3, dense_not_take_branch_test

dense_not_take_branch_test:
    beq x1, x2, deadend
    beq x1, x2, deadend
    beq x1, x2, deadend
    beq x1, x2, deadend
    beq x1, x2, deadend
    beq x1, x2, deadend
    beq x1, x2, deadend

branch_jal_alternate_test:
jal_1: jal branch_1
jal_2: jal branch_2
jal_3: jal branch_3
jal_4: jal branch_4
jal_5: jal branch_5
jal_6: jal branch_6
branch_1: beq x1, x3, jal_2
branch_2: beq x1, x3, jal_3
branch_3: beq x1, x3, jal_3
branch_4: beq x1, x3, jal_4
branch_5: beq x1, x3, jal_5
branch_6: beq x1, x3, jal_6


halt:                 # Infinite loop to keep the processor
    beq x0, x0, halt  # from trying to execute the data below.
                      # Your own programs should also make use
                      # of an infinite loop at the end.

deadend:
    lw x8, bad     # X8 <= 0xdeadbeef
deadloop:
    beq x8, x8, deadloop

.section .rodata

testslot:   .word 0x00000000
testaddr:   .word testslot
testdata:   .word 0xABCDEF01

bad:        .word 0xdeadbeef
threshold:  .word 0x00000040
result:     .word 0x00000000
good:       .word 0x600d600d
