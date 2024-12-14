const std = @import("std");
const gdt = @import("gdt.zig");
const tss = @import("tss.zig");
const interrupts = @import("interrupts.zig");
const vga = @import("drivers/vga.zig");
const keyboard = @import("drivers/keyboard.zig");
const pic = @import("drivers/pic.zig");
const commands = @import("commands.zig");
const multiboot = @import("multiboot.zig");
const utils = @import("utils.zig");
const memory = @import("memory.zig");

// ============= Multiboot Configuration =============
const MULTIBOOT_HEADER = struct {
    const MAGIC = 0x1BADB002;
    const FLAGS = (multiboot.ALIGN | multiboot.MEMINFO | multiboot.MMAP_INFO);
    const CHECKSUM = 0 -% (MAGIC + FLAGS);

    pub export var header align(4) linksection(".multiboot") = [_]u32{
        MAGIC, FLAGS, CHECKSUM,
    };
};

// ============= Stack Configuration =============
pub const STACK = struct {
    pub const KERNEL_SIZE = 64 * 1024; // 64KB kernel stack
    pub const INTERRUPT_SIZE = 32 * 1024; // 32KB interrupt stack

    pub export var kernel: [KERNEL_SIZE]u8 align(4096) linksection(".bss.kernel_stack") = undefined;
    pub export var interrupt: [INTERRUPT_SIZE]u8 align(4096) linksection(".bss.interrupt_stack") = undefined;

    extern const __kernel_stack_end: u8;

    pub fn getKernelBase() usize {
        return @intFromPtr(&kernel);
    }

    pub fn getKernelTop() usize {
        return getKernelBase() + KERNEL_SIZE;
    }

    pub fn getInterruptBase() usize {
        return @intFromPtr(&interrupt);
    }

    pub fn getInterruptTop() usize {
        return getInterruptBase() + INTERRUPT_SIZE;
    }

    pub fn debugPrint() void {
        const screen = vga.getScreen();
        screen.write("\nStack Configuration:\n");
        screen.write("-----------------\n");
        screen.write("Kernel stack:    0x");
        utils.printHex32(getKernelBase());
        screen.write(" - 0x");
        utils.printHex32(getKernelTop());
        screen.write("\nInterrupt stack: 0x");
        utils.printHex32(getInterruptBase());
        screen.write(" - 0x");
        utils.printHex32(getInterruptTop());
        screen.write("\n");
    }
};

// ============= Boot State =============
pub var boot_info: ?*multiboot.MultibootInfo = null;
export var debug_eax: u32 = undefined;
export var debug_ebx: u32 = undefined;

// ============= Entry Point =============
export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\.global _start
        \\mov $__kernel_stack_end, %%esp
        \\push %%ebx
        \\push %%eax
        \\call kmain
        ::: "memory");
}

// ============= Initialization Functions =============
fn initializeKernel() void {
    const screen = vga.getScreen();
    screen.write("\nInitializing kernel components...\n");

    // Memory Management
    screen.write("Initializing memory management...\n");
    memory.initializeMemory(boot_info.?) catch |err| {
        screen.setColor(.Red, .Black);
        screen.write("Error: Memory initialization failed - ");
        screen.write(@errorName(err));
        screen.write("\n");
        hang();
    };

    // GDT and TSS
    screen.write("- Global Descriptor Table... ");
    gdt.initGDT(boot_info.?);
    screen.write("OK\n");

    screen.write("- Task State Segment... ");
    STACK.debugPrint();
    tss.initTSS(STACK.getKernelTop(), STACK.getInterruptTop());
    screen.write("OK\n");

    // Interrupts and Devices
    screen.write("- Interrupt Descriptor Table... ");
    interrupts.initInterrupts();
    screen.write("OK\n");

    screen.write("- Programmable Interrupt Controller... ");
    pic.remap(32, 40);
    screen.write("OK\n");

    screen.write("- Keyboard Controller... ");
    keyboard.initKeyboard();
    pic.unmaskIRQ(1);
    screen.write("OK\n");

    screen.write("- Enabling interrupts... ");
    asm volatile ("sti");
    screen.write("OK\n");

    // Command System
    screen.write("- Command System... ");
    commands.initCommands();
    screen.write("OK\n");
}

fn verifyMultiboot(eax: u32, ebx: u32) !void {
    _ = eax;
    const screen = vga.getScreen();

    if (ebx == 0) {
        screen.setColor(.Red, .Black);
        screen.write("Error: Null multiboot info pointer!\n");
        return error.NullMultibootPointer;
    }

    const info = @as(*multiboot.MultibootInfo, @ptrFromInt(ebx));
    if (!info.isValid()) {
        screen.setColor(.Red, .Black);
        screen.write("Error: Invalid multiboot information!\n");
        return error.InvalidMultibootInfo;
    }

    boot_info = info;
    screen.setColor(.Green, .Black);
    screen.write("Multiboot information validated successfully!\n");
    screen.setColor(.White, .Black);
    info.debugPrint();
}

fn waitForShell() void {
    const screen = vga.getScreen();
    screen.write("\nPress left-shift to continue to shell...\n");

    while (true) {
        if (keyboard.getNextKey()) |k| {
            if (k == .Special and k.Special == .LeftShift) break;
        }
        asm volatile ("hlt");
    }

    screen.clear();
    screen.showBanner();
    screen.setColor(.Green, .Black);
    screen.write("Boot complete! Start typing:\n> ");
}

// ============= Main Entry =============
export fn kmain(eax: u32, ebx: u32) noreturn {
    vga.initScreen();
    const screen = vga.getScreen();

    screen.write("Booting ZigOS...\n\n");

    // Debug information
    utils.dumpRegisters(debug_eax, debug_ebx);
    utils.debugPrint("\nMultiboot Header Location: ", @intFromPtr(&MULTIBOOT_HEADER.header));
    utils.dumpBytes("Header bytes: ", @ptrCast(&MULTIBOOT_HEADER.header), 12);
    utils.dumpBytes("\nFirst bytes at 0x100000: ", @ptrFromInt(0x100000), 16);

    // Boot sequence
    verifyMultiboot(eax, ebx) catch |err| {
        screen.setColor(.Red, .Black);
        screen.write("\nFatal Error: Unable to verify multiboot information\n");
        screen.write("Error: ");
        screen.write(@errorName(err));
        screen.write("\n");
        hang();
    };

    initializeKernel();
    waitForShell();
    hang();
}

fn hang() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
