const vga = @import("vga.zig");
const commands = @import("../commands.zig");

pub const Key = union(enum) {
    Char: u8,
    Special: SpecialKey,
};

pub const SpecialKey = enum {
    Enter,
    Backspace,
    Escape,
    LeftShift,
    RightShift,
    LeftCtrl,
    RightCtrl,
    LeftAlt,
    RightAlt,
    Tab,
};

const LINE_BUFFER_SIZE = 256;
var line_buffer: [LINE_BUFFER_SIZE]u8 = undefined;
var buffer_pos: usize = 0;

const KEY_BUFFER_SIZE = 32;
var key_buffer: [KEY_BUFFER_SIZE]Key = undefined;
var buffer_read: usize = 0;
var buffer_write: usize = 0;

const ScancodeMapping = struct {
    scancode: u8,
    key: Key,
};

const SCANCODE_MAPPINGS = [_]ScancodeMapping{
    .{ .scancode = 0x01, .key = .{ .Special = .Escape } },
    .{ .scancode = 0x02, .key = .{ .Char = '1' } },
    .{ .scancode = 0x03, .key = .{ .Char = '2' } },
    .{ .scancode = 0x04, .key = .{ .Char = '3' } },
    .{ .scancode = 0x05, .key = .{ .Char = '4' } },
    .{ .scancode = 0x06, .key = .{ .Char = '5' } },
    .{ .scancode = 0x07, .key = .{ .Char = '6' } },
    .{ .scancode = 0x08, .key = .{ .Char = '7' } },
    .{ .scancode = 0x09, .key = .{ .Char = '8' } },
    .{ .scancode = 0x0A, .key = .{ .Char = '9' } },
    .{ .scancode = 0x0B, .key = .{ .Char = '0' } },
    .{ .scancode = 0x0C, .key = .{ .Char = '-' } },
    .{ .scancode = 0x0D, .key = .{ .Char = '=' } },
    .{ .scancode = 0x0E, .key = .{ .Special = .Backspace } },
    .{ .scancode = 0x0F, .key = .{ .Special = .Tab } },
    .{ .scancode = 0x10, .key = .{ .Char = 'q' } },
    .{ .scancode = 0x11, .key = .{ .Char = 'w' } },
    .{ .scancode = 0x12, .key = .{ .Char = 'e' } },
    .{ .scancode = 0x13, .key = .{ .Char = 'r' } },
    .{ .scancode = 0x14, .key = .{ .Char = 't' } },
    .{ .scancode = 0x15, .key = .{ .Char = 'y' } },
    .{ .scancode = 0x16, .key = .{ .Char = 'u' } },
    .{ .scancode = 0x17, .key = .{ .Char = 'i' } },
    .{ .scancode = 0x18, .key = .{ .Char = 'o' } },
    .{ .scancode = 0x19, .key = .{ .Char = 'p' } },
    .{ .scancode = 0x1A, .key = .{ .Char = '[' } },
    .{ .scancode = 0x1B, .key = .{ .Char = ']' } },
    .{ .scancode = 0x1C, .key = .{ .Special = .Enter } },
    .{ .scancode = 0x1D, .key = .{ .Special = .LeftCtrl } },
    .{ .scancode = 0x1E, .key = .{ .Char = 'a' } },
    .{ .scancode = 0x1F, .key = .{ .Char = 's' } },
    .{ .scancode = 0x20, .key = .{ .Char = 'd' } },
    .{ .scancode = 0x21, .key = .{ .Char = 'f' } },
    .{ .scancode = 0x22, .key = .{ .Char = 'g' } },
    .{ .scancode = 0x23, .key = .{ .Char = 'h' } },
    .{ .scancode = 0x24, .key = .{ .Char = 'j' } },
    .{ .scancode = 0x25, .key = .{ .Char = 'k' } },
    .{ .scancode = 0x26, .key = .{ .Char = 'l' } },
    .{ .scancode = 0x27, .key = .{ .Char = ';' } },
    .{ .scancode = 0x28, .key = .{ .Char = '\'' } },
    .{ .scancode = 0x29, .key = .{ .Char = '`' } },
    .{ .scancode = 0x2A, .key = .{ .Special = .LeftShift } },
    .{ .scancode = 0x2B, .key = .{ .Char = '\\' } },
    .{ .scancode = 0x2C, .key = .{ .Char = 'z' } },
    .{ .scancode = 0x2D, .key = .{ .Char = 'x' } },
    .{ .scancode = 0x2E, .key = .{ .Char = 'c' } },
    .{ .scancode = 0x2F, .key = .{ .Char = 'v' } },
    .{ .scancode = 0x30, .key = .{ .Char = 'b' } },
    .{ .scancode = 0x31, .key = .{ .Char = 'n' } },
    .{ .scancode = 0x32, .key = .{ .Char = 'm' } },
    .{ .scancode = 0x33, .key = .{ .Char = ',' } },
    .{ .scancode = 0x34, .key = .{ .Char = '.' } },
    .{ .scancode = 0x35, .key = .{ .Char = '/' } },
    .{ .scancode = 0x36, .key = .{ .Special = .RightShift } },
    .{ .scancode = 0x38, .key = .{ .Special = .LeftAlt } },
    .{ .scancode = 0x39, .key = .{ .Char = ' ' } },
};

pub const Keyboard = struct {
    shift_pressed: bool,
    ctrl_pressed: bool,
    alt_pressed: bool,

    pub fn init() Keyboard {
        buffer_pos = 0;
        return Keyboard{
            .shift_pressed = false,
            .ctrl_pressed = false,
            .alt_pressed = false,
        };
    }

    pub fn handleKey(self: *Keyboard, key: Key) void {
        const next_write = (buffer_write + 1) % KEY_BUFFER_SIZE;
        if (next_write != buffer_read) {
            key_buffer[buffer_write] = key;
            buffer_write = next_write;
        }

        const screen = vga.getScreen();
        switch (key) {
            .Char => |c| {
                if (buffer_pos < LINE_BUFFER_SIZE - 1) {
                    const char = if (self.shift_pressed) shiftChar(c) else c;
                    line_buffer[buffer_pos] = char;
                    buffer_pos += 1;
                    screen.putChar(char);
                }
            },
            .Special => |special| switch (special) {
                .LeftShift, .RightShift => self.shift_pressed = true,
                .LeftCtrl, .RightCtrl => self.ctrl_pressed = true,
                .LeftAlt, .RightAlt => self.alt_pressed = true,
                .Enter => {
                    line_buffer[buffer_pos] = 0; // Null terminate
                    screen.putChar('\n');
                    handleCommand(line_buffer[0..buffer_pos]);
                    buffer_pos = 0;
                },
                .Backspace => {
                    if (buffer_pos > 0) {
                        buffer_pos -= 1;
                        screen.backspace();
                    }
                },
                .Escape => {
                    while (buffer_pos > 0) : (buffer_pos -= 1) {
                        screen.backspace();
                    }
                },
                .Tab => {
                    var i: usize = 0;
                    while (i < 4 and buffer_pos < LINE_BUFFER_SIZE - 1) : (i += 1) {
                        line_buffer[buffer_pos] = ' ';
                        buffer_pos += 1;
                        screen.putChar(' ');
                    }
                },
            },
        }
    }

    pub fn handleKeyRelease(self: *Keyboard, key: Key) void {
        switch (key) {
            .Special => |special| switch (special) {
                .LeftShift, .RightShift => self.shift_pressed = false,
                .LeftCtrl, .RightCtrl => self.ctrl_pressed = false,
                .LeftAlt, .RightAlt => self.alt_pressed = false,
                else => {},
            },
            else => {},
        }
    }
};

pub fn getNextKey() ?Key {
    if (buffer_read == buffer_write) {
        return null;
    }

    const key = key_buffer[buffer_read];
    buffer_read = (buffer_read + 1) % KEY_BUFFER_SIZE;
    return key;
}

var KEYBOARD: Keyboard = undefined;

pub fn initKeyboard() void {
    buffer_read = 0;
    buffer_write = 0;
    KEYBOARD = Keyboard.init();
}

pub fn getKeyboard() *Keyboard {
    return &KEYBOARD;
}

pub fn translateScancode(scancode: u8) ?Key {
    if (scancode & 0x80 != 0) {
        const released_scancode = scancode & 0x7F;
        for (SCANCODE_MAPPINGS) |mapping| {
            if (mapping.scancode == released_scancode) {
                KEYBOARD.handleKeyRelease(mapping.key);
                break;
            }
        }
        return null;
    }

    for (SCANCODE_MAPPINGS) |mapping| {
        if (mapping.scancode == scancode) {
            return mapping.key;
        }
    }
    return null;
}

fn shiftChar(c: u8) u8 {
    return switch (c) {
        'a'...'z' => c - 32, // Convert to uppercase
        '1' => '!',
        '2' => '@',
        '3' => '#',
        '4' => '$',
        '5' => '%',
        '6' => '^',
        '7' => '&',
        '8' => '*',
        '9' => '(',
        '0' => ')',
        '-' => '_',
        '=' => '+',
        '[' => '{',
        ']' => '}',
        ';' => ':',
        '\'' => '"',
        ',' => '<',
        '.' => '>',
        '/' => '?',
        '`' => '~',
        '\\' => '|',
        else => c,
    };
}

fn handleCommand(command: []const u8) void {
    commands.executeCommand(command);
}
