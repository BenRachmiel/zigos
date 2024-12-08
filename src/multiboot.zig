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
        if (self.flags & (1 << 0) == 0) return false;

        if (self.mem_lower > 640) return false;

        if (self.mem_upper == 0) return false;

        return true;
    }

    pub fn debugPrint(self: *const MultibootInfo) void {
        const screen = vga.getScreen();

        screen.write("Multiboot Information:\n");
        utils.debugPrint("  Flags:        ", self.flags);
        screen.write("  Memory Map:\n");
        utils.debugPrint("    Lower:      ", self.mem_lower);
        utils.debugPrint("    Upper:      ", self.mem_upper);
        utils.debugPrint("  Boot Device:  ", self.boot_device);
        utils.debugPrint("  Command Line: ", self.cmdline);

        if (self.flags & (1 << 6) != 0) {
            screen.write("\n  Memory Map Details:\n");
            utils.debugPrint("    Length:     ", self.mmap_length);
            utils.debugPrint("    Address:    ", self.mmap_addr);
        }
    }

    pub fn getMemorySize(self: *const MultibootInfo) u64 {
        return (@as(u64, self.mem_upper) * 1024) + (@as(u64, self.mem_lower) * 1024);
    }

    pub fn hasMemoryMap(self: *const MultibootInfo) bool {
        return (self.flags & (1 << 6)) != 0;
    }
};
