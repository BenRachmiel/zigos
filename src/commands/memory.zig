const vga = @import("../drivers/vga.zig");
const memory = @import("../memory.zig");
const utils = @import("../utils.zig");

pub fn execute(args: []const u8) void {
    _ = args;
    const screen = vga.getScreen();
    const stats = memory.getMemoryStats();

    screen.write("\nMemory Information:\n");
    screen.write("------------------\n");

    screen.write("Total Memory:    ");
    utils.printDec(@as(u32, @truncate(stats.total_memory / 1024)));
    screen.write(" KB\n");

    screen.write("Available:       ");
    utils.printDec(@as(u32, @truncate(stats.available_memory / 1024)));
    screen.write(" KB\n");

    screen.write("Reserved:        ");
    utils.printDec(@as(u32, @truncate(stats.reserved_memory / 1024)));
    screen.write(" KB\n");

    screen.write("Largest Block:   ");
    utils.printDec(@as(u32, @truncate(stats.largest_free_block / 1024)));
    screen.write(" KB\n");
}
