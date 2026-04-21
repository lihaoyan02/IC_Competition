#
# RISC-V 32I Assembly startup code
#

.section entry, "ax"
.globl _start
.type _start, @function

_start:
    mv s0, zero
    # Initialize stack pointer
    la sp, _stack_pointer

    # Call main
    call _trm_init

