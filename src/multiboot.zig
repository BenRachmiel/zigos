const vga = @import("drivers/vga.zig");
const utils = @import("utils.zig");

pub const MAGIC: u32 = 0x1BADB002;
pub const BOOTLOADER_MAGIC: u32 = 0x2BADB002;

pub const ALIGN: u32 = 1 << 0;
pub const MEMINFO: u32 = 1 << 1;

pub const MultibootInfo = packed struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mmap_length: u32,
    mmap_addr: u32,

    pub fn isValid(self: *const MultibootInfo) bool {
        if (self.flags & (1 << 0) == 0) {
            return false;
        }

        if (self.mem_lower > 640) {
            return false;
        }

        if (self.mem_upper == 0) {
            return false;
        }

        return true;
    }

    pub fn debugPrint(self: *const MultibootInfo, screen: *vga.Screen) void {
        screen.write("Multiboot Info:\n");
        screen.write("  Flags: 0x");
        utils.printHex(self.flags);
        screen.write("\n");

        screen.write("  Raw Values:\n");
        screen.write("    mem_lower: 0x");
        utils.printHex(self.mem_lower);
        screen.write("\n    mem_upper: 0x");
        utils.printHex(self.mem_upper);
        screen.write("\n    boot_device: 0x");
        utils.printHex(self.boot_device);
        screen.write("\n    cmdline: 0x");
        utils.printHex(self.cmdline);
        screen.write("\n    mmap_length: 0x");
        utils.printHex(self.mmap_length);
        screen.write("\n    mmap_addr: 0x");
        utils.printHex(self.mmap_addr);
        screen.write("\n");
    }
};

pub fn initializeFromInfo(info: *MultibootInfo) !void {
    const screen = vga.getScreen();

    if (!info.isValid()) {
        screen.setColor(.Red, .Black);
        screen.write("Error: Invalid multiboot information!\n");
        return error.InvalidMultibootInfo;
    }

    screen.setColor(.Green, .Black);
    screen.write("Multiboot information validated successfully!\n");
    screen.setColor(.White, .Black);
    info.debugPrint(screen);
    return;
}

fn printHex32(value: u32, screen: *vga.Screen) void {
    const hex = "0123456789ABCDEF";
    var i: u5 = 28;
    while (i > 0) : (i -= 4) {
        screen.putChar(hex[(@as(u8, @truncate((value >> i) & 0xF)))]);
    }
    screen.putChar(hex[(@as(u8, @truncate(value & 0xF)))]);
}

fn printDec(value: u32, screen: *vga.Screen) void {
    if (value == 0) {
        screen.putChar('0');
        return;
    }

    var num_buf: [10]u8 = undefined;
    var i: usize = 0;
    var n = value;

    while (n > 0) : (i += 1) {
        num_buf[i] = @as(u8, @truncate(n % 10)) + '0';
        n /= 10;
    }

    while (i > 0) {
        i -= 1;
        screen.putChar(num_buf[i]);
    }
}
