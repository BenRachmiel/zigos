const vga = @import("../drivers/vga.zig");

pub fn execute(args: []const u8) void {
    _ = args;
    const screen = vga.getScreen();

    screen.write("\nAvailable commands:\n");
    screen.write("------------------\n");
    screen.write("verify - Verify GDT and TSS configuration\n");
    screen.write("memory - Display memory information\n");
    screen.write("clear  - Clear the screen\n");
    screen.write("help   - Show this help message\n");
}
