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

    screen.write("\nInitializing GDT...\n");
    gdt.initGDT();

    screen.write("Initializing TSS...\n");
    tss.initTSS(@intFromPtr(&stack_bytes) + stack_bytes.len);

    screen.write("Initializing interrupts...\n");
    interrupts.initInterrupts();

    screen.write("Remapping PIC...\n");
    pic.remap(32, 40);

    screen.write("Initializing keyboard...\n");
    keyboard.initKeyboard();
    pic.unmaskIRQ(1);

    screen.write("Enabling interrupts...\n");
    asm volatile ("sti");

    screen.write("Initializing command system...\n");
    commands.initCommands();
}

fn waitForShell() void {
    const screen = vga.getScreen();
    screen.write("\nPress left-shift to continue to shell...\n");

    while (true) {
        const key = keyboard.getNextKey();
        if (key) |k| {
            screen.write("Key caught.\n");
            switch (k) {
                .Special => |special| {
                    screen.write("Special caught.\n");
                    if (special == .LeftShift) {
                        screen.write("Left-shift caught, breaking.\n");
                        break;
                    }
                },
                else => {},
            }
        }
        asm volatile ("hlt");
    }

    screen.clear();
    screen.showBanner();
    screen.setColor(.Green, .Black);
    screen.write("Boot complete! Start typing:\n> ");
}

export fn kmain(eax: u32, ebx: u32) noreturn {
    _ = eax;
    vga.initScreen();
    const screen = vga.getScreen();

    screen.write("Booting ZigOS...\n\n");

    screen.write("Debug Register Values:\n");
    screen.write("  RAW EAX: 0x");
    utils.printHex(debug_eax);
    screen.write("\n  RAW EBX: 0x");
    utils.printHex(debug_ebx);
    screen.write("\n");

    screen.write("\nMultiboot Header Location: 0x");
    utils.printHex(@intFromPtr(&multiboot_header));
    screen.write("\n");

    screen.write("Header bytes: ");
    const header_bytes = @as([*]const u8, @ptrCast(&multiboot_header));
    for (0..12) |i| {
        utils.printHex8(header_bytes[i]);
        screen.write(" ");
    }
    screen.write("\n\n");

    const header_addr = @as([*]const u8, @ptrFromInt(0x100000));
    screen.write("First bytes at 0x100000: ");
    for (0..16) |i| {
        utils.printHex8(header_addr[i]);
        screen.write(" ");
    }
    screen.write("\n");

    if (ebx == 0) {
        screen.setColor(.Red, .Black);
        screen.write("Error: Null multiboot info pointer!\n");
        hang();
    }

    const info = @as(*multiboot.MultibootInfo, @ptrFromInt(ebx));
    if (!info.isValid()) {
        screen.setColor(.Red, .Black);
        screen.write("Error: Invalid multiboot information!\n");
        hang();
    }

    boot_info = info;

    screen.setColor(.Green, .Black);
    screen.write("Multiboot information validated successfully!\n");
    screen.setColor(.White, .Black);
    info.debugPrint(screen);

    initializeKernel();
    waitForShell();
    hang();
}

fn hang() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
