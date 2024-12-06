const vga = @import("../drivers/vga.zig");

const TestCommand = struct {
    name: [16]u8,
    name_len: usize,
    value: u8,
};

fn testHandler(args: []const u8) void {
    vga.getScreen().write("Handler called with: ");
    vga.getScreen().write(args);
    vga.getScreen().write("\n");
}

const MAX_COMMANDS = 32;
var command_list: [MAX_COMMANDS]TestCommand = undefined;
var handler_list: [MAX_COMMANDS]*const fn ([]const u8) void = undefined;
var command_count: usize = 0;

pub fn register(name: []const u8) bool {
    vga.getScreen().write("1. Starting register...\n");

    if (command_count >= MAX_COMMANDS or name.len >= 16) {
        return false;
    }

    vga.getScreen().write("2. Creating empty struct...\n");
    command_list[command_count] = TestCommand{
        .name = undefined,
        .name_len = 0,
        .value = 42,
    };

    vga.getScreen().write("3. Copying name...\n");
    command_list[command_count].name_len = name.len;
    @memcpy(command_list[command_count].name[0..name.len], name);

    vga.getScreen().write("4. Storing handler...\n");
    handler_list[command_count] = testHandler;

    vga.getScreen().write("5. Incrementing count...\n");
    command_count += 1;

    vga.getScreen().write("6. Done\n");
    return true;
}

pub fn executeCommand(input: []const u8) void {
    const screen = vga.getScreen();

    var cmd_end: usize = 0;
    while (cmd_end < input.len and input[cmd_end] != ' ') : (cmd_end += 1) {}

    const cmd_name = input[0..cmd_end];
    const args = if (cmd_end < input.len) input[cmd_end + 1 ..] else "";

    if (command_count > 0 and cmd_name.len > 0) {
        const stored_name = command_list[0].name[0..command_list[0].name_len];

        // Simple slice equality check
        var matches = true;
        if (stored_name.len == cmd_name.len) {
            var i: usize = 0;
            while (i < cmd_name.len) : (i += 1) {
                if (stored_name[i] != cmd_name[i]) {
                    matches = false;
                    break;
                }
            }

            if (matches) {
                handler_list[0](args);
            }
        }
    }

    screen.write("> ");
}
