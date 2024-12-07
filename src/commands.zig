const registry = @import("commands/registry.zig");
const verification = @import("commands/verification.zig");
const vga = @import("drivers/vga.zig");

pub fn initCommands() void {
    vga.getScreen().write("Starting command initialization...\n");
    _ = registry.register("verify");
    vga.getScreen().write("Command initialization complete\n");
}

pub const executeCommand = registry.executeCommand;
