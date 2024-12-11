const vga = @import("../drivers/vga.zig");

pub fn execute(args: []const u8) void {
    _ = args;
    const screen = vga.getScreen();
    screen.clear();
    screen.showBanner();
}
