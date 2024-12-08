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

    mods_count: u32,
    mods_addr: u32,

    sym_num: u32,
    sym_size: u32,
    sym_addr: u32,
    sym_shndx: u32,

    mmap_length: u32,
    mmap_addr: u32,

    drives_length: u32,
    drives_addr: u32,
    config_table: u32,
    boot_loader_name: u32,
    apm_table: u32,
    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,

    pub fn isValid(self: *const MultibootInfo) bool {
        if (self.flags & (1 << 0) == 0) return false;

        if (self.mem_lower > 640) return false;

        if (self.mem_upper == 0) return false;

        return true;
    }

    pub fn debugPrint(self: *const MultibootInfo) void {
        const screen = vga.getScreen();

        screen.write("Multiboot Information:\n");
        screen.write("  Flags: 0x");
        utils.printHex(self.flags);
        screen.write(" (");

        // Print individual flags
        if (self.flags & (1 << 0) != 0) screen.write("MEM ");
        if (self.flags & (1 << 1) != 0) screen.write("BOOT_DEVICE ");
        if (self.flags & (1 << 2) != 0) screen.write("CMDLINE ");
        if (self.flags & (1 << 3) != 0) screen.write("MODS ");
        if (self.flags & (1 << 4) != 0) screen.write("AOUT ");
        if (self.flags & (1 << 5) != 0) screen.write("ELF ");
        if (self.flags & (1 << 6) != 0) screen.write("MMAP ");
        screen.write(")\n");

        screen.write("  Raw values:\n");
        screen.write("    mem_lower: 0x");
        utils.printHex(self.mem_lower);
        screen.write("\n    mem_upper: 0x");
        utils.printHex(self.mem_upper);
        screen.write("\n    mmap_addr: 0x");
        utils.printHex(self.mmap_addr);
        screen.write("\n    mmap_length: 0x");
        utils.printHex(self.mmap_length);
        screen.write("\n");

        screen.write("  Formatting lower memory...\n");
        const lower_kb = self.mem_lower;
        screen.write("  Lower memory = ");
        utils.printDec(lower_kb);
        screen.write(" KB\n");
    }

    pub fn getMemorySize(self: *const MultibootInfo) u64 {
        return (@as(u64, self.mem_upper) * 1024) + (@as(u64, self.mem_lower) * 1024);
    }

    pub fn hasMemoryMap(self: *const MultibootInfo) bool {
        const MMAP_FLAG = 1 << 6;
        if ((self.flags & MMAP_FLAG) == 0) return false;

        if (self.mmap_addr < 0x100000) return false; // Should be above 1MB
        if (self.mmap_length == 0) return false;
        if (self.mmap_length > 0x10000) return false; // Arbitrary reasonable max

        return true;
    }
};
