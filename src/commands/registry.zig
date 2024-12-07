const vga = @import("../drivers/vga.zig");
const verification = @import("verification.zig");

var handler: ?*const fn ([]const u8) void = null;

pub fn register(name: []const u8) bool {
    _ = name;
    handler = verification.verifyGdtTss;
    return true;
}

pub fn executeCommand(input: []const u8) void {
    const screen = vga.getScreen();

    if (handler) |h| {
        if (input.len == 6 and input[0] == 'v' and input[1] == 'e' and
            input[2] == 'r' and input[3] == 'i' and
            input[4] == 'f' and input[5] == 'y')
        {
            h("");
            return;
        }
    }
    screen.write("> ");
}
