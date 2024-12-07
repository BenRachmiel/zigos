const std = @import("std");
const vga = @import("drivers/vga.zig");

pub const GDT_ENTRIES = 6; // 5 original entries + TSS
const TSS_INDEX = 5;

pub const GdtError = error{
    InvalidBase,
    InvalidLimit,
    NullNotPresent,
    InvalidTSS,
};

pub const AccessFlags = packed struct {
    accessed: bool = false,
    read_write: bool = false, // readable for code, writable for data
    direction: bool = false, // conforming for code, direction for data
    executable: bool = false, // 1 for code, 0 for data
    descriptor_type: bool = true, // should be 1 for code/data segments
    privilege_level: u2 = 0, // Ring 0-3
    present: bool = true,

    pub fn toU8(self: AccessFlags) u8 {
        return @as(u8, @bitCast(self));
    }

    pub fn fromU8(value: u8) AccessFlags {
        return @as(AccessFlags, @bitCast(value));
    }

    pub fn debugPrint(self: AccessFlags, screen: *vga.Screen) void {
        screen.write("  Access Flags:\n");
        screen.write("    Present: ");
        screen.write(if (self.present) "Yes\n" else "No\n");
        screen.write("    Ring: ");
        const level: u8 = @as(u8, self.privilege_level);
        screen.putChar('0' + level);
        screen.write("\n");
        screen.write("    Type: ");
        screen.write(if (self.descriptor_type) "Code/Data\n" else "System\n");
        screen.write("    Executable: ");
        screen.write(if (self.executable) "Yes\n" else "No\n");
        screen.write("    RW: ");
        screen.write(if (self.read_write) "Yes\n" else "No\n");
    }
};

pub const GranularityFlags = packed struct {
    segment_length: u2 = 0,
    reserved: u1 = 0,
    big: bool = true, // 32-bit protected mode
    granularity: bool = true, // multiply limit by 4K

    pub fn toU8(self: GranularityFlags) u8 {
        return (@as(u8, @intFromBool(self.granularity)) << 7) |
            (@as(u8, @intFromBool(self.big)) << 6) |
            (@as(u8, self.reserved) << 5) |
            (@as(u8, self.segment_length) << 3);
    }
};

pub const SystemFlags = packed struct {
    type: u4 = 9, // 9 for TSS
    reserved: u1 = 0,
    privilege_level: u2 = 0,
    present: bool = true,

    pub fn toU8(self: SystemFlags) u8 {
        return @as(u8, @bitCast(self));
    }
};

pub const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,

    pub fn init(base: u32, limit: u32, access: AccessFlags, gran: GranularityFlags) GdtEntry {
        const screen = vga.getScreen();
        screen.write("[GDT] Creating entry: base=0x");
        printHex32(base);
        screen.write("\n");

        access.debugPrint(screen);

        return GdtEntry{
            .limit_low = @truncate(limit & 0xFFFF),
            .base_low = @truncate(base & 0xFFFF),
            .base_middle = @truncate((base >> 16) & 0xFF),
            .access = access.toU8(),
            .granularity = gran.toU8() | @as(u8, @truncate((limit >> 16) & 0x0F)),
            .base_high = @truncate((base >> 24) & 0xFF),
        };
    }

    pub fn debugPrint(self: GdtEntry, screen: *vga.Screen, index: usize) void {
        screen.write("GDT[");
        screen.putChar('0' + @as(u8, @truncate(index)));
        screen.write("]: base=0x");

        const base = @as(u32, self.base_high) << 24 |
            @as(u32, self.base_middle) << 16 |
            @as(u32, self.base_low);

        printHex32(base);
        screen.write("\n");

        const access = AccessFlags.fromU8(self.access);
        access.debugPrint(screen);
    }
};

pub const GdtPointer = packed struct {
    limit: u16,
    base: u32,
};

pub var gdt: [GDT_ENTRIES]GdtEntry = undefined;
pub var gdt_pointer: GdtPointer = undefined;

fn makeKernelCodeFlags() AccessFlags {
    return AccessFlags{
        .read_write = true,
        .executable = true,
    };
}

fn makeKernelDataFlags() AccessFlags {
    return AccessFlags{
        .read_write = true,
    };
}

fn makeUserCodeFlags() AccessFlags {
    return AccessFlags{
        .read_write = true,
        .executable = true,
        .privilege_level = 3,
    };
}

fn makeUserDataFlags() AccessFlags {
    return AccessFlags{
        .read_write = true,
        .privilege_level = 3,
    };
}

fn makeSystemDescriptor(base: u32, limit: u32, flags: SystemFlags) GdtEntry {
    const screen = vga.getScreen();
    screen.write("[GDT] Creating system descriptor at base=0x");
    printHex32(base);
    screen.write(" limit=0x");
    printHex32(limit);
    screen.write("\n");

    return GdtEntry{
        .limit_low = @truncate(limit & 0xFFFF),
        .base_low = @truncate(base & 0xFFFF),
        .base_middle = @truncate((base >> 16) & 0xFF),
        .access = flags.toU8(),
        .granularity = (@as(u8, @truncate((limit >> 16) & 0x0F))),
        .base_high = @truncate((base >> 24) & 0xFF),
    };
}

fn verifyGDT() void {
    const screen = vga.getScreen();
    screen.write("\n=== Starting GDT Verification ===\n");

    screen.write("Verifying null descriptor...\n");
    if (gdt[0].access != 0 or gdt[0].base_low != 0 or gdt[0].base_middle != 0 or gdt[0].base_high != 0) {
        screen.write("ERROR: Null descriptor is not zero!\n");
        return;
    }
    screen.write("Null descriptor OK\n");

    var i: usize = 1;
    while (i < GDT_ENTRIES) : (i += 1) {
        screen.write("Verifying entry ");
        screen.putChar('0' + @as(u8, @truncate(i)));
        screen.write("...\n");

        // Print raw values first
        screen.write("Raw values: limit_low=0x");
        printHex16(gdt[i].limit_low);
        screen.write(" base_low=0x");
        printHex16(gdt[i].base_low);
        screen.write(" access=0x");
        printHex8(gdt[i].access);
        screen.write("\n");

        if (i < TSS_INDEX) {
            const access = AccessFlags.fromU8(gdt[i].access);
            access.debugPrint(screen);
        } else {
            screen.write("TSS entry\n");
            screen.write("base=0x");
            const base = @as(u32, gdt[i].base_high) << 24 |
                @as(u32, gdt[i].base_middle) << 16 |
                @as(u32, gdt[i].base_low);
            printHex32(base);
            screen.write("\n");
        }
        screen.write("Entry verified\n");
    }

    screen.write("=== GDT Verification Complete ===\n\n");
}

pub fn initGDT() void {
    const screen = vga.getScreen();
    screen.write("[GDT] Initializing Global Descriptor Table...\n");

    // Null descriptor
    screen.write("[GDT] Setting null descriptor\n");
    gdt[0] = GdtEntry.init(0, 0, AccessFlags{ .present = false, .descriptor_type = false }, GranularityFlags{ .big = false, .granularity = false });

    // Kernel code segment
    screen.write("[GDT] Setting kernel code segment\n");
    gdt[1] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = true,
        .privilege_level = 0,
    }, GranularityFlags{});

    // Kernel data segment
    screen.write("[GDT] Setting kernel data segment\n");
    gdt[2] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = false,
        .privilege_level = 0,
    }, GranularityFlags{});

    // User code segment
    screen.write("[GDT] Setting user code segment\n");
    gdt[3] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = true,
        .privilege_level = 3,
    }, GranularityFlags{});

    // User data segment
    screen.write("[GDT] Setting user data segment\n");
    gdt[4] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = false,
        .privilege_level = 3,
    }, GranularityFlags{});

    // TSS entry
    screen.write("[GDT] Setting up TSS entry...\n");
    const tss = @import("tss.zig").getTSS();
    const tss_base = @intFromPtr(tss);
    const tss_limit = @sizeOf(@TypeOf(tss.*));

    screen.write("[GDT] TSS base=0x");
    printHex32(tss_base);
    screen.write(" limit=0x");
    printHex32(tss_limit);
    screen.write("\n");

    if (TSS_INDEX >= GDT_ENTRIES) {
        screen.write("ERROR: TSS_INDEX out of bounds!\n");
        return;
    }

    gdt[TSS_INDEX] = makeSystemDescriptor(
        tss_base,
        tss_limit,
        SystemFlags{
            .type = 9, // 32-bit TSS
            .privilege_level = 0,
            .present = true,
        },
    );

    screen.write("[GDT] TSS descriptor created\n");

    gdt_pointer = GdtPointer{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };

    screen.write("[GDT] Loading GDT with TSS...\n");
    loadGDT(&gdt_pointer);

    // Load TSS
    screen.write("[GDT] Loading TSS...\n");
    loadTSS();

    screen.write("[GDT] Running verification...\n");
    verifyGDT();

    screen.write("[GDT] Initialization complete!\n");
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

fn loadTSS() void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (@as(u16, 0x28)),
    );
}

fn printHex32(value: u32) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    var i: u5 = 28;
    while (i > 0) : (i -= 4) {
        screen.putChar(hex[(@as(u8, @truncate((value >> i) & 0xF)))]);
    }
    screen.putChar(hex[(@as(u8, @truncate(value & 0xF)))]);
}

fn printHex8(value: u8) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    screen.putChar(hex[(value >> 4) & 0xF]);
    screen.putChar(hex[value & 0xF]);
}

fn printHex16(value: u16) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    var i: u4 = 12;
    while (i > 0) : (i -= 4) {
        screen.putChar(hex[(@as(u8, @truncate((value >> i) & 0xF)))]);
    }
    screen.putChar(hex[(@as(u8, @truncate(value & 0xF)))]);
}
