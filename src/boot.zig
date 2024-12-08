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

const MULTIBOOT_MAGIC = 0x1BADB002;
const MULTIBOOT_FLAGS = (multiboot.ALIGN | multiboot.MEMINFO);
const MULTIBOOT_CHECKSUM = 0 -% (MULTIBOOT_MAGIC + MULTIBOOT_FLAGS);

export var multiboot_header align(4) linksection(".multiboot") = [_]u32{
    MULTIBOOT_MAGIC,
    MULTIBOOT_FLAGS,
    MULTIBOOT_CHECKSUM,
};

var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
var boot_info: ?*multiboot.MultibootInfo = null;

export var debug_eax: u32 = undefined;
export var debug_ebx: u32 = undefined;

export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\mov %%eax, (debug_eax)
        \\mov %%ebx, (debug_ebx)
        \\mov %[stack_ptr], %%esp
        \\push %%ebx
        \\push %%eax
        \\call kmain
        :
        : [stack_ptr] "r" (@intFromPtr(&stack_bytes) + stack_bytes.len),
        : "memory"
    );
}

fn initializeKernel() void {
    const screen = vga.getScreen();

    screen.write("\nInitializing kernel components...\n");

    screen.write("- Global Descriptor Table... ");
    gdt.initGDT();
    screen.write("OK\n");

    screen.write("- Task State Segment... ");
    tss.initTSS(@intFromPtr(&stack_bytes) + stack_bytes.len);
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
