const pic = @import("drivers/pic.zig");
const vga = @import("drivers/vga.zig");

pub fn delay() void {
    var i: u32 = 0;
    while (i < 10000000) : (i += 1) {
        pic.io_wait();
    }
}

pub fn printHex(value: usize) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    var shift: u5 = 28;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const nibble = (value >> shift) & 0xF;
        screen.putChar(hex[@as(u4, @truncate(nibble))]);
        if (shift >= 4) {
            shift -= 4;
        }
    }
}

pub fn printHex8(value: u8) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    screen.putChar(hex[(value >> 4) & 0xF]);
    screen.putChar(hex[value & 0xF]);
}

pub fn printHex16(value: u16) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    var shift: u4 = 12;
    while (shift > 0) : (shift -= 4) {
        screen.putChar(hex[@as(u4, @truncate((value >> shift) & 0xF))]);
    }
    screen.putChar(hex[@as(u4, @truncate(value & 0xF))]);
}

pub fn printHex32(value: u32) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    var i: u5 = 28;
    while (i > 0) : (i -= 4) {
        screen.putChar(hex[(@as(u8, @truncate((value >> i) & 0xF)))]);
    }
    screen.putChar(hex[(@as(u8, @truncate(value & 0xF)))]);
}

pub fn printHex0x(value: usize) void {
    const screen = vga.getScreen();
    screen.write("0x");
    printHex(value);
}

fn printDigits(screen: *vga.Screen, num: u32) void {
    if (num == 0) {
        return;
    }
    printDigits(screen, num / 10);
    const digit = @as(u8, @intCast(num % 10));
    screen.putChar(digit + '0'); 
}

pub fn printDec(value: u32) void {
    const screen = vga.getScreen();

    if (value == 0) {
        screen.putChar('0');
        return;
    }

    printDigits(screen, value);
}

pub fn debugPrint(title: []const u8, value: u32) void {
    const screen = vga.getScreen();
    screen.write(title);
    screen.write("0x");
    printHex32(value);
    screen.write("\n");
}

pub fn dumpBytes(title: []const u8, addr: [*]const u8, len: usize) void {
    const screen = vga.getScreen();
    screen.write(title);
    for (0..len) |i| {
        printHex8(addr[i]);
        screen.write(" ");
    }
    screen.write("\n");
}

pub fn dumpRegisters(eax: u32, ebx: u32) void {
    const screen = vga.getScreen();
    screen.write("Debug Register Values:\n");
    debugPrint("  RAW EAX: ", eax);
    debugPrint("  RAW EBX: ", ebx);
}
