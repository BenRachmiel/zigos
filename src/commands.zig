const registry = @import("commands/registry.zig");
const vga = @import("drivers/vga.zig");

pub fn initCommands() void {
    vga.getScreen().write("Starting command initialization...\n");
    _ = registry.register("echo");
    vga.getScreen().write("Command initialization complete\n");
}

pub const executeCommand = registry.executeCommand;
