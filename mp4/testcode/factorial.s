factorial.s:
.align 4
.section .text
.globl _start
_start:
    
    lw a0, input_number

    # Call the subroutine (not saving caller-saved register yet, since we won't use them)
    jal factorial

halt:                 # Infinite loop to keep the processor
    beq x0, x0, halt  # from trying to execute the data below.

.globl factorial
factorial:
	# Register a0 holds the input value
	# Register t0-t6 are caller-save, so you may use them without saving
	# Return value need to be put in register a0
	
    # a0 holds the current product (return value)
    # t0 holds the current multiplier
    # t1 holds the remaining add time

    # a0 is the first multiplicand, which is the input N 
    addi t0, a0, -1  # t0 store the first multiplier N-1
    
factorial_mult:
    beqz t0, factorial_ret  # if t0 == 0, return

    # Multiple a0 with t0 and store into a0

    mv t1, a0    # move a0 into t1
    mv t2, t0    # move t0 into t2
    mv a0, zero  # clear a0 to store the sum

    # Now calculate t1 * t2 and store the sum into a0
factorial_mult_loop:
    andi t3, t2, 0x1  # get the least significant bit of t2 into t3
    beqz t3, factorial_mult_loop_shift  # if LSB of t2 is 0, do not add
    add  a0, a0, t1
factorial_mult_loop_shift:
    slli t1, t1, 1   # t1 = t1 << 1
    srli t2, t2, 1   # t2 = t2 >> 1
    bnez t2, factorial_mult_loop  # if t2 != 0, continue multiple loop

    addi t0, t0, -1  # t0 -= 1
    j factorial_mult

factorial_ret:
	jr ra # Register ra holds the return address

.section .rodata
input_number:    .word 0xC
