pub const VGA_WIDTH = 80;
pub const VGA_HEIGHT = 25;
pub const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

// VGA cursor I/O ports
const VGA_CTRL_PORT = 0x3D4;
const VGA_DATA_PORT = 0x3D5;
const VGA_CURSOR_HIGH = 0x0E;
const VGA_CURSOR_LOW = 0x0F;

const BOOT_BANNER = [_][]const u8{
    "",
    "         _______       _____ _____          ",
    "        |___  (_)     |  _  /  ___|        ",
    "           / / _  __ _| | | \\ `--.         ",
    "          / / | |/ _` | | | |`--. \\        ",
    "        ./ /__| | (_| \\ \\_/ /\\__/ /        ",
    "        \\_____/_|\\__, |\\___/\\____/         ",
    "                  __/ |                     ",
    "                 |___/                      ",
    "",
    ".................. v0.1.0 ..................",
    "",
};

pub const Color = enum(u4) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    Yellow = 14,
    White = 15,
};

const VGA_BUFFER = @as(*volatile [VGA_SIZE]u16, @ptrFromInt(0xB8000));

pub const Screen = struct {
    color: u8,
    column: usize,
    row: usize,

    pub fn init() Screen {
        var screen = Screen{
            .color = makeColorCode(.LightGrey, .Black),
            .column = 0,
            .row = 0,
        };
        screen.clear();
        return screen;
    }

    pub fn showBanner(self: *Screen) void {
        self.displayBootBanner();
        self.row = BOOT_BANNER.len;
        self.column = 0;
        self.updateCursor();
    }

    fn displayBootBanner(self: *Screen) void {
        const original_color = self.color;

        const banner_width = 40; // Fixed width of the banner
        const start_x = (VGA_WIDTH - banner_width) / 2;

        for (BOOT_BANNER, 0..) |line, i| {
            // Set color based on line type
            if (i == 0 or i == BOOT_BANNER.len - 1 or i == BOOT_BANNER.len - 2) {
                self.setColor(.DarkGrey, .Black);
            } else if (i == 10) { // Version line
                self.setColor(.DarkGrey, .Black);
            } else if (i > 0) { // Main logo
                self.setColor(.Cyan, .Black);
            }

            // Position cursor
            self.row = i;
            self.column = start_x;

            // Write the line safely
            for (line) |char| {
                const index = self.row * VGA_WIDTH + self.column;
                if (index < VGA_SIZE) {
                    VGA_BUFFER[index] = makeVgaEntry(char, self.color);
                    self.column += 1;
                }
            }
        }

        self.color = original_color;
    }

    fn updateCursor(self: *Screen) void {
        const row = if (self.row >= VGA_HEIGHT) VGA_HEIGHT - 1 else self.row;
        const col = if (self.column >= VGA_WIDTH) VGA_WIDTH - 1 else self.column;
        const pos = row * VGA_WIDTH + col;

        out(u8, VGA_CTRL_PORT, VGA_CURSOR_HIGH);
        out(u8, VGA_DATA_PORT, @truncate((pos >> 8) & 0xFF));
        out(u8, VGA_CTRL_PORT, VGA_CURSOR_LOW);
        out(u8, VGA_DATA_PORT, @truncate(pos & 0xFF));
    }

    pub fn clear(self: *Screen) void {
        const blank = makeVgaEntry(' ', self.color);
        for (0..VGA_HEIGHT) |y| {
            for (0..VGA_WIDTH) |x| {
                VGA_BUFFER[y * VGA_WIDTH + x] = blank;
            }
        }
        self.column = 0;
        self.row = 0;
        self.updateCursor();
    }

    pub fn write(self: *Screen, text: []const u8) void {
        for (text) |char| {
            self.putChar(char);
        }
    }

    pub fn setColor(self: *Screen, fg: Color, bg: Color) void {
        self.color = makeColorCode(fg, bg);
    }

    fn newLine(self: *Screen) void {
        self.column = 0;
        if (self.row < VGA_HEIGHT - 1) {
            self.row += 1;
        } else {
            self.scroll();
        }
        self.updateCursor();
    }

    fn scroll(self: *Screen) void {
        // Move everything up one line
        for (1..VGA_HEIGHT) |y| {
            for (0..VGA_WIDTH) |x| {
                VGA_BUFFER[(y - 1) * VGA_WIDTH + x] = VGA_BUFFER[y * VGA_WIDTH + x];
            }
        }

        // Clear the last line
        const blank = makeVgaEntry(' ', self.color);
        for (0..VGA_WIDTH) |x| {
            VGA_BUFFER[(VGA_HEIGHT - 1) * VGA_WIDTH + x] = blank;
        }

        self.row = VGA_HEIGHT - 1;
        self.updateCursor();
    }

    pub fn backspace(self: *Screen) void {
        if (self.column > 0) {
            self.column -= 1;
            const index = self.row * VGA_WIDTH + self.column;
            VGA_BUFFER[index] = makeVgaEntry(' ', self.color);
        } else if (self.row > 0) {
            self.row -= 1;
            self.column = VGA_WIDTH - 1;
            const index = self.row * VGA_WIDTH + self.column;
            VGA_BUFFER[index] = makeVgaEntry(' ', self.color);
        }
        self.updateCursor();
    }

    pub fn putChar(self: *Screen, c: u8) void {
        switch (c) {
            '\n' => {
                self.newLine();
            },
            '\r' => {
                self.column = 0;
                self.updateCursor();
            },
            else => {
                if (self.column >= VGA_WIDTH) {
                    self.newLine();
                }
                const index = self.row * VGA_WIDTH + self.column;
                if (index < VGA_SIZE) {
                    VGA_BUFFER[index] = makeVgaEntry(c, self.color);
                    self.column += 1;
                }
                self.updateCursor();
            },
        }
    }
};

fn makeColorCode(fg: Color, bg: Color) u8 {
    const foreground = @as(u8, @intFromEnum(fg));
    const background = @as(u8, @intFromEnum(bg));
    return foreground | (background << 4);
}

fn makeVgaEntry(c: u8, color: u8) u16 {
    const char = @as(u16, c);
    const col = @as(u16, color);
    return char | (col << 8);
}

fn out(comptime T: type, port: u16, value: T) void {
    switch (T) {
        u8 => asm volatile ("outb %[value], %[port]"
            :
            : [value] "{al}" (value),
              [port] "N{dx}" (port),
        ),
        else => @compileError("Invalid outport type: " ++ @typeName(T)),
    }
}

var SCREEN: Screen = undefined;

pub fn initScreen() void {
    SCREEN = Screen.init();
}

pub fn getScreen() *Screen {
    return &SCREEN;
}
