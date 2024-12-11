const vga = @import("../drivers/vga.zig");
const verify_command = @import("verify.zig");
const memory_command = @import("memory.zig");
const help_command = @import("help.zig");
const clear_command = @import("clear.zig");

const CommandFn = *const fn ([]const u8) void;

const StaticCommand = struct {
    name: []const u8,
    handler: CommandFn,
};

const COMMANDS = [_]StaticCommand{
    .{ .name = "help", .handler = help_command.execute },
    .{ .name = "memory", .handler = memory_command.execute },
    .{ .name = "verify", .handler = verify_command.execute },
    .{ .name = "clear", .handler = clear_command.execute },
};

pub fn executeCommand(input: []const u8) void {
    const screen = vga.getScreen();

    if (input.len == 0) {
        screen.write("> ");
        return;
    }

    // Static command matching
    inline for (COMMANDS) |cmd| {
        if (input.len == cmd.name.len) {
            var matches = true;
            for (input, 0..) |c, i| {
                if (c != cmd.name[i]) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                cmd.handler("");
                screen.write("> ");
                return;
            }
        }
    }

    screen.write("Unknown command: ");
    screen.write(input);
    screen.write("\nType 'help' for available commands\n> ");
}

pub fn register(name: []const u8) bool {
    _ = name;
    return true;
}
