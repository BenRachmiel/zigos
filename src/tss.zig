const vga = @import("drivers/vga.zig");
const utils = @import("utils.zig");

pub const TSS = packed struct {
    prev_tss: u32 = 0,
    esp0: u32 = 0, // Kernel stack
    ss0: u32 = 0,
    esp1: u32 = 0,
    ss1: u32 = 0,
    esp2: u32 = 0,
    ss2: u32 = 0,
    cr3: u32 = 0,
    eip: u32 = 0,
    eflags: u32 = 0,
    eax: u32 = 0,
    ecx: u32 = 0,
    edx: u32 = 0,
    ebx: u32 = 0,
    esp: u32 = 0,
    ebp: u32 = 0,
    esi: u32 = 0,
    edi: u32 = 0,
    es: u32 = 0,
    cs: u32 = 0,
    ss: u32 = 0,
    ds: u32 = 0,
    fs: u32 = 0,
    gs: u32 = 0,
    ldt: u32 = 0,
    trap: u16 = 0,
    iomap_base: u16 = @sizeOf(TSS),
    // Add IST support
    ist1: u32 = 0, // Interrupt Stack Table 1
    ist2: u32 = 0,
    ist3: u32 = 0,
    ist4: u32 = 0,
    ist5: u32 = 0,
    ist6: u32 = 0,
    ist7: u32 = 0,
};

var MAIN_TSS: TSS = TSS{};

pub fn getTSS() *TSS {
    return &MAIN_TSS;
}

pub fn initTSS(kernel_stack: u32, interrupt_stack: u32) void {
    const screen = vga.getScreen();
    screen.write("[TSS] Initializing Task State Segment...\n");

    // Set up kernel stack
    MAIN_TSS.ss0 = 0x10; // Kernel data segment
    MAIN_TSS.esp0 = kernel_stack;

    // Set up interrupt stack
    MAIN_TSS.ist1 = interrupt_stack;

    // Initialize segment registers with null selector
    MAIN_TSS.cs = 0;
    MAIN_TSS.ss = 0;
    MAIN_TSS.ds = 0;
    MAIN_TSS.es = 0;
    MAIN_TSS.fs = 0;
    MAIN_TSS.gs = 0;

    screen.write("[TSS] Stack configuration:\n");
    screen.write("  Kernel stack: 0x");
    utils.printHex32(kernel_stack);
    screen.write("\n  Interrupt stack: 0x");
    utils.printHex32(interrupt_stack);
    screen.write("\n");

    screen.write("[TSS] Configuration complete.\n");
}
