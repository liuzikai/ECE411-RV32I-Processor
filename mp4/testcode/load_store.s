load_store.s:
.align 4
.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    lw  x5, testaddr
    lw  x4, testdata

    # Store x4 to testaddr using sb
    sb x4, 0(x5)    
    srli x4, x4, 8
    sb x4, 1(x5)    
    srli x4, x4, 8
    sb x4, 2(x5)    
    srli x4, x4, 8
    sb x4, 3(x5)  
    srli x4, x4, 8  

    sh x4, 0(x5)
    sh x4, 2(x5)

    sw x4, 0(x5)

    lb x3, 0(x5)
    lb x3, 1(x5)
    lb x3, 2(x5)
    lb x3, 3(x5)

    lbu x3, 0(x5)
    lbu x3, 1(x5)
    lbu x3, 2(x5)
    lbu x3, 3(x5)

    lh x3, 0(x5)
    lh x3, 2(x5)

    lhu x3, 0(x5)
    lhu x3, 2(x5)

    lw x3, 0(x5)

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
