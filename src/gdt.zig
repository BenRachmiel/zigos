pub const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,

    pub fn init(base: u32, limit: u32, access: u8, gran: u8) GdtEntry {
        const limit_low: u16 = @as(u16, @truncate(limit & 0xFFFF));
        const base_low: u16 = @as(u16, @truncate(base & 0xFFFF));
        const base_middle: u8 = @as(u8, @truncate((base >> 16) & 0xFF));
        const base_high: u8 = @as(u8, @truncate((base >> 24) & 0xFF));
        const granularity: u8 = (gran & 0xF0) | @as(u8, @truncate((limit >> 16) & 0x0F));

        return GdtEntry{
            .limit_low = limit_low,
            .base_low = base_low,
            .base_middle = base_middle,
            .access = access,
            .granularity = granularity,
            .base_high = base_high,
        };
    }
};

pub const GdtPointer = packed struct {
    limit: u16,
    base: u32,
};

const GDT_ENTRIES = 5;
var gdt: [GDT_ENTRIES]GdtEntry = undefined;
var gdt_pointer: GdtPointer = undefined;

pub fn initGDT() void {
    // Null descriptor
    gdt[0] = GdtEntry.init(0, 0, 0, 0);

    // Kernel code segment
    gdt[1] = GdtEntry.init(0, 0xFFFFFFFF, 0x9A, 0xCF); // Code segment

    // Kernel data segment
    gdt[2] = GdtEntry.init(0, 0xFFFFFFFF, 0x92, 0xCF); // Data segment

    // User code segment
    gdt[3] = GdtEntry.init(0, 0xFFFFFFFF, 0xFA, 0xCF); // User code segment

    // User data segment
    gdt[4] = GdtEntry.init(0, 0xFFFFFFFF, 0xF2, 0xCF); // User data segment

    gdt_pointer = GdtPointer{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };

    loadGDT(&gdt_pointer);
}

pub fn loadGDT(ptr: *const GdtPointer) void {
    asm volatile (
        \\lgdt (%[ptr])
        \\movw $0x10, %%ax  // Load kernel data segment
        \\movw %%ax, %%ds
        \\movw %%ax, %%es
        \\movw %%ax, %%fs
        \\movw %%ax, %%gs
        \\movw %%ax, %%ss
        \\ljmp $0x08, $1f  // Load kernel code segment
        \\1:
        :
        : [ptr] "r" (ptr),
        : "ax"
    );
}
