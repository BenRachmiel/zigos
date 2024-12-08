const vga = @import("drivers/vga.zig");
const utils = @import("utils.zig");
const multiboot = @import("multiboot.zig");

pub const MemoryMapEntry = packed struct {
    size: u32, // Size of the entry, not including 'size' field itself
    base_addr_low: u32,
    base_addr_high: u32,
    length_low: u32,
    length_high: u32,
    type: u32, // 1: Available, 2: Reserved, 3: ACPI Recl, 4: ACPI NVS, 5: Bad

    pub fn getBaseAddr(self: *const MemoryMapEntry) u64 {
        return (@as(u64, self.base_addr_high) << 32) | self.base_addr_low;
    }

    pub fn getLength(self: *const MemoryMapEntry) u64 {
        return (@as(u64, self.length_high) << 32) | self.length_low;
    }

    pub fn debugPrint(self: *const MemoryMapEntry) void {
        const screen = vga.getScreen();
        const base = self.getBaseAddr();
        const len = self.getLength();

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

    if (mbi.mmap_addr < 0x100000 or mbi.mmap_addr > 0xFFFFFFFF or
        mbi.mmap_length == 0 or mbi.mmap_length > 0x10000)
    {
        screen.setColor(.Red, .Black);
        screen.write("Error: Invalid memory map address or length\n");
        return error.InvalidMemoryMap;
    }

    screen.write("Multiboot Flags: ");
    utils.printHex0x(mbi.flags);
    screen.write("\n");

    screen.write("Memory Map Address: ");
    utils.printHex0x(mbi.mmap_addr);
    screen.write("\n");

    screen.write("Memory Map Length: ");
    utils.printDec(mbi.mmap_length);
    screen.write(" bytes\n\n");

    const mmap_addr = mbi.mmap_addr;
    const mmap_end = mmap_addr + mbi.mmap_length;

    if (mmap_end <= mmap_addr or mmap_end > 0xFFFFFFFF) {
        screen.setColor(.Red, .Black);
        screen.write("Error: Invalid memory map bounds\n");
        return error.InvalidMemoryBounds;
    }

    screen.write("Memory Map Entries:\n");
    screen.write("-----------------\n");

    var current_addr = mmap_addr;
    while (current_addr < mmap_end) {
        const entry = @as(*const MemoryMapEntry, @ptrFromInt(current_addr));

        screen.write("Entry at ");
        utils.printHex0x(current_addr);
        screen.write(": size=");
        utils.printDec(entry.size);
        screen.write(" type=");
        utils.printDec(entry.type);
        screen.write("\n");

        entry.debugPrint();

        const len = entry.getLength();
        switch (entry.type) {
            1 => { // Available memory
                memory_stats.available_memory += len;
                if (len > memory_stats.largest_free_block) {
                    memory_stats.largest_free_block = len;
                }
            },
            else => memory_stats.reserved_memory += len,
        }
        memory_stats.total_memory += len;

        current_addr += entry.size + @sizeOf(u32);
    }

    screen.write("\nMemory Statistics:\n");
    screen.write("Total Memory:      ");
    utils.printDec(@as(u32, @truncate(memory_stats.total_memory / 1024)));
    screen.write(" KB\n");

    screen.write("Available Memory:  ");
    utils.printDec(@as(u32, @truncate(memory_stats.available_memory / 1024)));
    screen.write(" KB\n");

    screen.write("Reserved Memory:   ");
    utils.printDec(@as(u32, @truncate(memory_stats.reserved_memory / 1024)));
    screen.write(" KB\n");

    screen.write("Largest Free Block: ");
    utils.printDec(@as(u32, @truncate(memory_stats.largest_free_block / 1024)));
    screen.write(" KB\n");

    screen.setColor(.Green, .Black);
    screen.write("\nMemory initialization complete!\n");
    screen.setColor(.White, .Black);
}

pub fn getMemoryStats() *const MemoryStats {
    return &memory_stats;
}
