const MAGIC: u32 = 0x1BADB002;
const ALIGN: u32 = 1 << 0; // Align modules on page boundaries
const MEMINFO: u32 = 1 << 1; // Provide memory map
const FLAGS: u32 = ALIGN | MEMINFO; // Combine flags
const CHECKSUM: u32 = 0 -% (MAGIC + FLAGS);

export var multiboot_header align(4) linksection(".multiboot") = [_]u32{
    MAGIC,
    FLAGS,
    CHECKSUM,
};

var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

const VGA_MEMORY = @as([*]volatile u16, @ptrFromInt(0xB8000));
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;

const VGA_COLOR_BLACK = 0;
const VGA_COLOR_LIGHT_GREY = 7;

fn makeVgaAttribute(fg: u8, bg: u8) u8 {
    return fg | (bg << 4);
}

fn makeVgaEntry(c: u8, color: u8) u16 {
    const char = @as(u16, c);
    const col = @as(u16, color);
    return char | (col << 8);
}

export fn kmain() noreturn {
    const hello = "Liba quick, get the camera! We're booting a zig-compiled os ;)";
    const color = makeVgaAttribute(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);

    var i: usize = 0;
    while (i < hello.len) : (i += 1) {
        VGA_MEMORY[i] = makeVgaEntry(hello[i], color);
    }

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
