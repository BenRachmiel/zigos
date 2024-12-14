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
        __bss_start = .;
        
        . = ALIGN(16);
        __kernel_stack_start = .;
        *(.bss.kernel_stack)
        . = ALIGN(4K);
        __kernel_stack_end = .;
        
        . += 4K;
        
        . = ALIGN(16);
        __interrupt_stack_start = .;
        *(.bss.interrupt_stack)
        . = ALIGN(4K);
        __interrupt_stack_end = .;
        
        *(.bss .bss.*)
        . = ALIGN(4K);
        __bss_end = .;
    } :data
}

PHDRS {
    text PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}
