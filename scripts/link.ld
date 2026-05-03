/*
 * RISC-V 32I Linker Script
 */
ENTRY(_start)
MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 0x00008000 /* 32 KB RAM */
}

SECTIONS
{
    .text :
    {
        *(entry)
        *(.text)
    } > RAM

    .rodata :
    {
        *(.rodata)
        *(.srodata*)
    } > RAM

    .data :
    {
        *(.data)
        *(.sdata*)
    } > RAM

    .bss :
    {
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(.scommon)
        _bss_end = .;
    } > RAM

    /* Stack - grows downward from end of RAM */
    . = ORIGIN(RAM) + LENGTH(RAM);
    _stack_pointer = .;
}
