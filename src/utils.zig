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

    // For 32-bit systems, we need 8 hex digits (32 bits / 4 bits per hex digit)
    var shift: u5 = 28; // Start with highest nibble (32 - 4 = 28)

    // Print each hex digit, from most significant to least significant
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        // Extract 4 bits (a nibble) by shifting right and masking
        const nibble = (value >> shift) & 0xF;
        // Convert the 4-bit value to an index into our hex digits array
        screen.putChar(hex[@as(u4, @truncate(nibble))]);
        // Move to next nibble position if not at the end
        if (shift >= 4) {
            shift -= 4;
        }
    }
}

pub fn printHex0x(value: usize) void {
    const screen = vga.getScreen();
    screen.write("0x");
    printHex(value);
}
