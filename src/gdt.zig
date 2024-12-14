const std = @import("std");
const vga = @import("drivers/vga.zig");
const utils = @import("utils.zig");
const memory = @import("memory.zig");

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
        utils.printHex32(base);
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

    pub fn initSystem(base: u32, limit: u32, flags: SystemFlags, gran: GranularityFlags) GdtEntry {
        const screen = vga.getScreen();
        screen.write("[GDT] Creating system entry: base=0x");
        utils.printHex32(base);
        screen.write("\n");

        return GdtEntry{
            .limit_low = @truncate(limit & 0xFFFF),
            .base_low = @truncate(base & 0xFFFF),
            .base_middle = @truncate((base >> 16) & 0xFF),
            .access = flags.toU8(),
            .granularity = gran.toU8() | @as(u8, @truncate((limit >> 16) & 0x0F)),
            .base_high = @truncate((base >> 24) & 0xFF),
        };
    }
};
pub const GdtPointer = packed struct {
    limit: u16,
    base: u32,
};

pub var gdt: [GDT_ENTRIES]GdtEntry = undefined;
pub var gdt_pointer: GdtPointer = undefined;

pub fn makeNullFlags() AccessFlags {
    return AccessFlags{
        .present = false,
        .descriptor_type = false,
    };
}

pub fn makeKernelCodeFlags() AccessFlags {
    return AccessFlags{
        .present = true,
        .read_write = true,
        .executable = true,
        .descriptor_type = true,
        .privilege_level = 0,
    };
}

pub fn makeKernelDataFlags() AccessFlags {
    return AccessFlags{
        .present = true,
        .read_write = true,
        .executable = false,
        .descriptor_type = true,
        .privilege_level = 0,
    };
}

pub fn makeUserCodeFlags() AccessFlags {
    return AccessFlags{
        .present = true,
        .read_write = true,
        .executable = true,
        .descriptor_type = true,
        .privilege_level = 3,
    };
}

pub fn makeUserDataFlags() AccessFlags {
    return AccessFlags{
        .present = true,
        .read_write = true,
        .executable = false,
        .descriptor_type = true,
        .privilege_level = 3,
    };
}

pub fn makeTSSFlags() SystemFlags {
    return SystemFlags{
        .type = 9, // 32-bit TSS
        .privilege_level = 0,
        .present = true,
    };
}

pub fn makeNullGranularity() GranularityFlags {
    return GranularityFlags{
        .big = false,
        .granularity = false,
    };
}

pub fn makeSegmentGranularity() GranularityFlags {
    return GranularityFlags{
        .big = true,
        .granularity = true,
    };
}

pub fn initGDT() void {
    const screen = vga.getScreen();
    screen.write("[GDT] Initializing Global Descriptor Table...\n");

    const memory_stats = memory.getMemoryStats();
    const phys_limit: u32 = @truncate(memory_stats.total_memory - 1);
    screen.write("Physical Memory: ");
    utils.printDec(@truncate(memory_stats.total_memory / 1024 / 1024));
    screen.write(" MB\n");

    gdt[0] = GdtEntry.init(0, 0, makeNullFlags(), makeNullGranularity());
    gdt[1] = GdtEntry.init(0, phys_limit, makeKernelCodeFlags(), makeSegmentGranularity());
    gdt[2] = GdtEntry.init(0, phys_limit, makeKernelDataFlags(), makeSegmentGranularity());
    gdt[3] = GdtEntry.init(0, phys_limit, makeUserCodeFlags(), makeSegmentGranularity());
    gdt[4] = GdtEntry.init(0, phys_limit, makeUserDataFlags(), makeSegmentGranularity());

    screen.write("[GDT] Setting up TSS entry...\n");
    const tss = @import("tss.zig").getTSS();
    const tss_base = @intFromPtr(tss);
    const tss_limit = @sizeOf(@TypeOf(tss.*));

    screen.write("[GDT] TSS base=0x");
    utils.printHex32(tss_base);
    screen.write(" limit=0x");
    utils.printHex32(tss_limit);
    screen.write("\n");

    if (TSS_INDEX >= GDT_ENTRIES) {
        screen.write("ERROR: TSS_INDEX out of bounds!\n");
        return;
    }

    gdt[TSS_INDEX] = GdtEntry.initSystem(tss_base, tss_limit, makeTSSFlags(), GranularityFlags{
        .big = false,
        .granularity = false,
    });

    screen.write("[GDT] TSS descriptor created\n");

    gdt_pointer = GdtPointer{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };

    screen.write("[GDT] Loading GDT with TSS...\n");
    loadGDT(&gdt_pointer);

    screen.write("[GDT] Loading TSS...\n");
    loadTSS();

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
