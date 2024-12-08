OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)

SECTIONS {
    /* Start at 1MB */
    . = 1M;

    .multiboot ALIGN(4K) : {
        KEEP(*(.multiboot))
        . = ALIGN(4K);
    } :text

    .text ALIGN(4K) : {
        *(.text)
        . = ALIGN(4K);
    } :text

    .rodata ALIGN(4K) : {
        *(.rodata)
        . = ALIGN(4K);
    } :data

    .data ALIGN(4K) : {
        *(.data)
        . = ALIGN(4K);
    } :data

    .bss ALIGN(4K) (NOLOAD) : {
        *(COMMON)
        *(.bss)
        . = ALIGN(4K);
    } :data
}

PHDRS {
    text PT_LOAD FLAGS(5); /* Read + Execute */
    data PT_LOAD FLAGS(6); /* Read + Write */
}
