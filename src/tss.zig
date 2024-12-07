const vga = @import("drivers/vga.zig");

pub const TSS = packed struct {
    prev_tss: u32 = 0, // Previous TSS - not used for hardware task switching
    esp0: u32 = 0, // Stack pointer for ring 0
    ss0: u32 = 0, // Stack segment for ring 0
    esp1: u32 = 0, // Stack pointer for ring 1
    ss1: u32 = 0, // Stack segment for ring 1
    esp2: u32 = 0, // Stack pointer for ring 2
    ss2: u32 = 0, // Stack segment for ring 2
    cr3: u32 = 0, // Page directory base register
    eip: u32 = 0, // Instruction pointer
    eflags: u32 = 0, // Flags register
    eax: u32 = 0, // General purpose registers
    ecx: u32 = 0,
    edx: u32 = 0,
    ebx: u32 = 0,
    esp: u32 = 0,
    ebp: u32 = 0,
    esi: u32 = 0,
    edi: u32 = 0,
    es: u32 = 0, // Segment registers
    cs: u32 = 0,
    ss: u32 = 0,
    ds: u32 = 0,
    fs: u32 = 0,
    gs: u32 = 0,
    ldt: u32 = 0, // Local Descriptor Table segment selector
    trap: u16 = 0, // Debug trap flag
    iomap_base: u16 = @sizeOf(TSS), // I/O map base address - set to size of TSS to indicate no I/O permission map
};

var MAIN_TSS: TSS = TSS{};

pub fn getTSS() *TSS {
    return &MAIN_TSS;
}

pub fn initTSS(kernel_stack: u32) void {
    const screen = vga.getScreen();
    screen.write("[TSS] Initializing Task State Segment...\n");

    // Set up ring 0 stack
    MAIN_TSS.ss0 = 0x10; // Kernel data segment
    MAIN_TSS.esp0 = kernel_stack;

    // Initialize segment registers with null selector
    MAIN_TSS.cs = 0;
    MAIN_TSS.ss = 0;
    MAIN_TSS.ds = 0;
    MAIN_TSS.es = 0;
    MAIN_TSS.fs = 0;
    MAIN_TSS.gs = 0;

    // Debug output
    screen.write("[TSS] Configuration complete.\n");
}
