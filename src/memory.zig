const vga = @import("drivers/vga.zig");
const utils = @import("utils.zig");
const multiboot = @import("multiboot.zig");

pub const MemoryMapEntry = extern struct {
    // Note: size field is 4 bytes BEFORE this struct, not included here
    base_addr: u64, // offset 0, 8 bytes
    length: u64, // offset 8, 8 bytes
    type: u32, // offset 16, 4 bytes

    comptime {
        if (@sizeOf(MemoryMapEntry) != 20) {
            @compileError("MemoryMapEntry must be exactly 20 bytes");
        }
        if (@offsetOf(MemoryMapEntry, "base_addr") != 0) {
            @compileError("base_addr must be at offset 0");
        }
        if (@offsetOf(MemoryMapEntry, "length") != 8) {
            @compileError("length must be at offset 8");
        }
        if (@offsetOf(MemoryMapEntry, "type") != 16) {
            @compileError("type must be at offset 16");
        }
    }

    pub fn getSizeField(self: *const MemoryMapEntry) u32 {
        // Size field is 4 bytes before the struct
        return @as(*const u32, @ptrFromInt(@intFromPtr(self) - 4)).*;
    }

    pub fn debugPrint(self: *const MemoryMapEntry) void {
        const screen = vga.getScreen();
        screen.write("   debugPrint: Accessing base_addr...\n");
        const base = self.base_addr;
        screen.write("   debugPrint: Accessing length...\n");
        const len = self.length;

        utils.printHex0x(@as(u32, @truncate(base)));
        screen.write(" - ");
        utils.printHex0x(@as(u32, @truncate(base + len)));
        screen.write(" | ");

        screen.write("Type: ");
        switch (self.type) {
            1 => screen.write("Available"),
            2 => screen.write("Reserved"),
            3 => screen.write("ACPI Reclaimable"),
            4 => screen.write("ACPI NVS"),
            5 => screen.write("Bad RAM"),
            else => screen.write("Unknown"),
        }

        screen.write(" | Size: ");
        utils.printDec(@as(u32, @truncate(len / 1024)));
        screen.write(" KB\n");
    }
};

pub const MemoryStats = struct {
    total_memory: u64 = 0,
    available_memory: u64 = 0,
    reserved_memory: u64 = 0,
    largest_free_block: u64 = 0,
};

var memory_stats: MemoryStats = .{};

pub fn initializeMemory(mbi: *multiboot.MultibootInfo) !void {
    const screen = vga.getScreen();
    screen.write("\nInitializing Memory Management\n");
    screen.write("------------------------------\n");

    if (!mbi.hasMemoryMap()) {
        screen.write("Memory map flag check failed:\n");
        screen.write("  Required flag: 0x40 (bit 6)\n");
        screen.write("  Current flags: 0x");
        utils.printHex(mbi.flags);
        screen.write("\n");
        return error.NoMemoryMap;
    }

    if (mbi.mmap_addr < 0x1000 or mbi.mmap_addr > 0xFFFFFFFF or
        mbi.mmap_length == 0 or mbi.mmap_length > 0x10000)
    {
        screen.write("Error: Invalid memory map address or length\n");
        return error.InvalidMemoryMap;
    }

    screen.write("Multiboot Flags: ");
    utils.printHex0x(mbi.flags);
    screen.write("\nMemory Map Address: ");
    utils.printHex0x(mbi.mmap_addr);
    screen.write("\nMemory Map Length: ");
    utils.printDec(mbi.mmap_length);
    screen.write(" bytes\n\n");

    const mmap_addr = mbi.mmap_addr;
    const mmap_end = mmap_addr + mbi.mmap_length;

    screen.write("\nDebug: Memory Map Iterator\n");
    screen.write("Start Address: ");
    utils.printHex0x(mmap_addr);
    screen.write("\nEnd Address: ");
    utils.printHex0x(mmap_end);
    screen.write("\n");

    var current_addr = mmap_addr;
    while (current_addr < mmap_end) {
        screen.write("\nIterator Debug:\n");
        screen.write("current_addr: ");
        utils.printHex0x(current_addr);
        screen.write("\n");

        screen.write("1. Reading size field...\n");
        const size = @as(*const u32, @ptrFromInt(current_addr)).*;
        screen.write("   Size: ");
        utils.printDec(size);
        screen.write("\n");

        if (size < 20) {
            screen.write("Error: Invalid entry size (less than 20 bytes)\n");
            break;
        }

        screen.write("2. Getting entry pointer...\n");
        const entry = @as(*const MemoryMapEntry, @ptrFromInt(current_addr + 4));
        screen.write("   Entry at: ");
        utils.printHex0x(current_addr + 4);
        screen.write("\n");

        screen.write("3. Calling debugPrint...\n");
        entry.debugPrint();

        const len = entry.length;
        memory_stats.total_memory += len;
        switch (entry.type) {
            1 => {
                memory_stats.available_memory += len;
                if (len > memory_stats.largest_free_block) {
                    memory_stats.largest_free_block = len;
                }
            },
            else => memory_stats.reserved_memory += len,
        }

        screen.write("4. Calculating next address...\n");
        const next_addr = current_addr + size + 4;
        screen.write("   Next: ");
        utils.printHex0x(next_addr);
        screen.write("\n");

        screen.write("5. Moving to next entry...\n");
        if (next_addr <= current_addr) {
            screen.write("Error: Next address would not advance\n");
            break;
        }
        current_addr = next_addr;
    }

    screen.write("\nMemory Statistics:\n");
    screen.write("-----------------\n");
    screen.write("Total Memory:      ");
    utils.printDec(@as(u32, @truncate(memory_stats.total_memory / 1024)));
    screen.write(" KB\n");

    screen.setColor(.Green, .Black);
    screen.write("\nMemory initialization complete!\n");
    screen.setColor(.White, .Black);
}

pub fn getMemoryStats() *const MemoryStats {
    return &memory_stats;
}
