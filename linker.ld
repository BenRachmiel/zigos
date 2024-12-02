OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)

SECTIONS {
    . = 1M;

    .text : {
        *(.multiboot)
        *(.text)
    }

    .rodata : {
        *(.rodata)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(COMMON)
        *(.bss)
    }
}
