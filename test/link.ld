MEMORY
{
    RAM (rx) : ORIGIN = 0x80000000, LENGTH = 4K
    DATA (rw) : ORIGIN = 0x80001000, LENGTH = 4K
}

SECTIONS
{
    . = ORIGIN(RAM);
    .text :
    {
        KEEP(*(.text))
    }

    . = ORIGIN(DATA);
    .data :
    {
        KEEP(*(.data))
    }
}