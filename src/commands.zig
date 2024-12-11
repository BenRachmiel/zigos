const registry = @import("commands/registry.zig");
const vga = @import("drivers/vga.zig");

pub fn initCommands() void {
    vga.getScreen().write("Starting command initialization...\n");
    _ = registry.register("verify");
    _ = registry.register("memory");
    _ = registry.register("help");
    vga.getScreen().write("Command initialization complete\n");
}

pub const executeCommand = registry.executeCommand;
