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

const MULTIBOOT_MAGIC = 0x1BADB002;
const MULTIBOOT_FLAGS = (multiboot.ALIGN | multiboot.MEMINFO | multiboot.MMAP_INFO);
const MULTIBOOT_CHECKSUM = 0 -% (MULTIBOOT_MAGIC + MULTIBOOT_FLAGS);

export var multiboot_header align(4) linksection(".multiboot") = [_]u32{
    MULTIBOOT_MAGIC,
    MULTIBOOT_FLAGS,
    MULTIBOOT_CHECKSUM,
};

pub var boot_info: ?*multiboot.MultibootInfo = null;

export var debug_eax: u32 = undefined;
export var debug_ebx: u32 = undefined;

pub const KERNEL_STACK_SIZE = 64 * 1024; // 64KB kernel stack
pub const INTERRUPT_STACK_SIZE = 32 * 1024; // 32KB interrupt stack

pub export var _kernel_stack: [KERNEL_STACK_SIZE]u8 align(4096) linksection(".bss.kernel_stack") = undefined;
pub export var _interrupt_stack: [INTERRUPT_STACK_SIZE]u8 align(4096) linksection(".bss.interrupt_stack") = undefined;

pub fn getKernelStackBase() usize {
    return @intFromPtr(&_kernel_stack);
}

pub fn getKernelStackTop() usize {
    return getKernelStackBase() + KERNEL_STACK_SIZE;
}

pub fn getInterruptStackBase() usize {
    return @intFromPtr(&_interrupt_stack);
}

pub fn getInterruptStackTop() usize {
    return getInterruptStackBase() + INTERRUPT_STACK_SIZE;
}

pub const kernel_stack = &_kernel_stack;
pub const interrupt_stack = &_interrupt_stack;

export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\mov $0x00148000, %%esp
        \\push %%ebx
        \\push %%eax
        \\call kmain
        ::: "memory");
}

pub export var initial_esp: u32 = undefined;

fn initializeKernel() void {
    const screen = vga.getScreen();

    screen.write("\nInitializing kernel components...\n");

    screen.write("Initializing memory management...\n");
    memory.initializeMemory(boot_info.?) catch |err| {
        screen.setColor(.Red, .Black);
        screen.write("Error: Memory initialization failed - ");
        screen.write(@errorName(err));
        screen.write("\n");
        hang();
    };

    screen.write("- Global Descriptor Table... ");
    gdt.initGDT(boot_info.?);
    screen.write("OK\n");

    screen.write("- Task State Segment... ");
    const k_stack_base = getKernelStackBase();
    const k_stack_top = getKernelStackTop();
    const i_stack_base = getInterruptStackBase();
    const i_stack_top = getInterruptStackTop();

    screen.write("\nDebug Stack Values:\n");
    screen.write("Kernel stack base: 0x");
    utils.printHex32(k_stack_base);
    screen.write("\nKernel stack top:  0x");
    utils.printHex32(k_stack_top);
    screen.write("\nInt stack base:    0x");
    utils.printHex32(i_stack_base);
    screen.write("\nInt stack top:     0x");
    utils.printHex32(i_stack_top);
    screen.write("\n");

    tss.initTSS(k_stack_top, i_stack_top);
    screen.write("OK\n");

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

    screen.write("- Command System... ");
    commands.initCommands();
    screen.write("OK\n");
}

fn waitForShell() void {
    const screen = vga.getScreen();
    screen.write("\nPress left-shift to continue to shell...\n");

    while (true) {
        if (keyboard.getNextKey()) |k| {
            if (k == .Special and k.Special == .LeftShift) {
                break;
            }
        }
        asm volatile ("hlt");
    }

    screen.clear();
    screen.showBanner();
    screen.setColor(.Green, .Black);
    screen.write("Boot complete! Start typing:\n> ");
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

export fn kmain(eax: u32, ebx: u32) noreturn {
    vga.initScreen();
    const screen = vga.getScreen();

    screen.write("Booting ZigOS...\n\n");

    utils.dumpRegisters(debug_eax, debug_ebx);
    utils.debugPrint("\nMultiboot Header Location: ", @intFromPtr(&multiboot_header));
    utils.dumpBytes("Header bytes: ", @ptrCast(&multiboot_header), 12);
    utils.dumpBytes("\nFirst bytes at 0x100000: ", @ptrFromInt(0x100000), 16);

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
