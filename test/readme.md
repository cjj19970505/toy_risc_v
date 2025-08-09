# Simple Test for toy_risc_v project

# Prerequisite
- WSL

# Compile test program:
Compile the test program, and check if instructions in dump files are currectly implemented in HDL project.
```bash
riscv32-unknown-elf-as -march=rv32i -mabi=ilp32 -o test1.o test1.S
riscv32-unknown-elf-ld -m elf32lriscv -T link.ld -o test1.elf test1.o
riscv32-unknown-elf-objdump -d test1.elf > test1.dump
```

# Run test program in QEMU environment
```bash
qemu-system-riscv32 -machine virt -nographic -bios none -serial stdio -monitor telnet:127.0.0.1:1234,server,nowait -kernel test1.elf
```

And then in another terminal run
```bash
telnet 127.0.0.1 1234
# After entering telnet console
# Use the following command to check DATA section memory.
xp /1wx 0x80001000
```

# Link File
Currently all program are linked using the following link file:
```
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
```
