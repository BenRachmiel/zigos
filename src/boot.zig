const gdt = @import("gdt.zig");
const interrupts = @import("interrupts.zig");
const vga = @import("drivers/vga.zig");
const keyboard = @import("drivers/keyboard.zig");
const pic = @import("drivers/pic.zig");
const commands = @import("commands.zig");

const MAGIC: u32 = 0x1BADB002;
const ALIGN: u32 = 1 << 0;
const MEMINFO: u32 = 1 << 1;
const FLAGS: u32 = ALIGN | MEMINFO;
const CHECKSUM: u32 = 0 -% (MAGIC + FLAGS);

export var multiboot_header align(4) linksection(".multiboot") = [_]u32{
    MAGIC,
    FLAGS,
    CHECKSUM,
};

var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

fn enableInterrupts() void {
    asm volatile ("sti");
}

export fn kmain() noreturn {
    vga.initScreen();
    const screen = vga.getScreen();
    screen.clear();

    screen.write("Initializing GDT...\n");
    gdt.initGDT();

    screen.write("Initializing interrupts...\n");
    interrupts.initInterrupts();

    screen.write("Remapping PIC...\n");
    pic.remap(32, 40);
    screen.write("Initializing keyboard...\n");
    keyboard.initKeyboard();
    pic.unmaskIRQ(1);

    screen.write("Enabling interrupts...\n");
    enableInterrupts();

    screen.write("Initializing command system...\n");
    commands.initCommands();

    screen.clear();
    screen.showBanner();

    screen.setColor(.Green, .Black);
    screen.write("Boot complete! Start typing:\n> ");

    while (true) {
        asm volatile ("hlt");
    }
}

export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\mov %[stack_top], %%esp
        \\call kmain
        :
        : [stack_top] "r" (@intFromPtr(&stack_bytes) + stack_bytes.len),
        : "esp"
    );
}
