const std = @import("std");
const vga = @import("drivers/vga.zig");

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
        const hex = "0123456789ABCDEF";
        var i: u5 = 28;
        while (i > 0) : (i -= 4) {
            screen.putChar(hex[(@as(u8, @truncate((base >> i) & 0xF)))]);
        }
        screen.putChar(hex[(@as(u8, @truncate(base & 0xF)))]);
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

        // Convert to u32 before shifting
        const base = @as(u32, self.base_high) << 24 |
            @as(u32, self.base_middle) << 16 |
            @as(u32, self.base_low);

        const hex = "0123456789ABCDEF";
        var i: u5 = 28;
        while (i > 0) : (i -= 4) {
            screen.putChar(hex[(@as(u8, @truncate((base >> i) & 0xF)))]);
        }
        screen.putChar(hex[(@as(u8, @truncate(base & 0xF)))]);
        screen.write("\n");

        const access = AccessFlags.fromU8(self.access);
        access.debugPrint(screen);
    }
};

pub const GdtPointer = packed struct {
    limit: u16,
    base: u32,
};

const GDT_ENTRIES = 5;
var gdt: [GDT_ENTRIES]GdtEntry = undefined;
var gdt_pointer: GdtPointer = undefined;

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

fn verifyGDT() void {
    const screen = vga.getScreen();
    screen.write("\n=== GDT Verification ===\n");

    for (gdt, 0..) |entry, i| {
        entry.debugPrint(screen, i);
    }

    screen.write("=== End GDT Verification ===\n\n");
}

fn printHex(screen: *vga.Screen, value: u8) void {
    const hex = "0123456789ABCDEF";
    screen.putChar(hex[(value >> 4) & 0xF]);
    screen.putChar(hex[value & 0xF]);
}

pub fn initGDT() void {
    const screen = vga.getScreen();
    screen.write("[GDT] Initializing...\n");

    screen.write("[GDT] Setting null descriptor\n");
    gdt[0] = GdtEntry.init(0, 0, AccessFlags{ .present = false, .descriptor_type = false }, GranularityFlags{ .big = false, .granularity = false });

    screen.write("[GDT] Setting kernel code segment\n");
    gdt[1] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = true,
        .privilege_level = 0,
    }, GranularityFlags{});

    screen.write("[GDT] Setting kernel data segment\n");
    gdt[2] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = false,
        .privilege_level = 0,
    }, GranularityFlags{});

    screen.write("[GDT] Setting user code segment\n");
    gdt[3] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = true,
        .privilege_level = 3,
    }, GranularityFlags{});

    screen.write("[GDT] Setting user data segment\n");
    gdt[4] = GdtEntry.init(0, 0xFFFFFFFF, AccessFlags{
        .present = true,
        .read_write = true,
        .executable = false,
        .privilege_level = 3,
    }, GranularityFlags{});

    gdt_pointer = GdtPointer{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };

    screen.write("[GDT] Loading...\n");
    loadGDT(&gdt_pointer);
    screen.write("[GDT] Load complete\n");
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
