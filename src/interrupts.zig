const keyboard = @import("drivers/keyboard.zig");
const vga = @import("drivers/vga.zig");

pub const InterruptFrame = packed struct {
    // Pushed by interrupt handler
    int_no: u32,
    err_code: u32,

    // Pushed by CPU
    eip: u32,
    cs: u32,
    eflags: u32,
    esp: u32,
    ss: u32,
};

const INTERRUPTS_COUNT = 256;

pub const InterruptDescriptor = packed struct {
    offset_low: u16,
    segment_selector: u16,
    reserved: u8 = 0,
    flags: u8,
    offset_high: u16,

    pub fn init(offset: u32, segment_selector: u16, flags: u8) InterruptDescriptor {
        const offset_low: u16 = @as(u16, @truncate(offset & 0xFFFF));
        const offset_high: u16 = @as(u16, @truncate((offset >> 16) & 0xFFFF));

        return InterruptDescriptor{
            .offset_low = offset_low,
            .segment_selector = segment_selector,
            .flags = flags,
            .offset_high = offset_high,
        };
    }
};

pub const IdtPointer = packed struct {
    limit: u16,
    base: u32,
};

var idt: [INTERRUPTS_COUNT]InterruptDescriptor = undefined;
var idt_pointer: IdtPointer = undefined;

extern fn isr_keyboard() void;
extern fn isr_default() void;

pub fn initInterrupts() void {
    var i: usize = 0;
    while (i < INTERRUPTS_COUNT) : (i += 1) {
        idt[i] = InterruptDescriptor.init(
            @intFromPtr(&isr_default),
            0x08, // Kernel code segment
            0x8E, // Present, Ring 0, 32-bit Interrupt Gate
        );
    }

    // Set up keyboard interrupt (IRQ1 = INT 33)
    idt[33] = InterruptDescriptor.init(
        @intFromPtr(&isr_keyboard),
        0x08,
        0x8E,
    );

    // Load the IDT
    idt_pointer = IdtPointer{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    loadIdt(&idt_pointer);
}

pub fn loadIdt(ptr: *const IdtPointer) void {
    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (ptr),
    );
}

// Actual interrupt handlers
pub export fn keyboardHandler() void {
    const scancode = in(u8, 0x60);
    if (keyboard.translateScancode(scancode)) |key| {
        keyboard.getKeyboard().handleKey(key);
    }
    // Send EOI
    out(u8, 0x20, 0x20);
}

pub export fn defaultHandler() void {
    // Send EOI
    out(u8, 0x20, 0x20);
}

// I/O port functions
pub inline fn out(comptime T: type, port: u16, value: T) void {
    switch (T) {
        u8 => asm volatile ("outb %[value], %[port]"
            :
            : [value] "{al}" (value),
              [port] "N{dx}" (port),
        ),
        else => @compileError("Invalid outport type: " ++ @typeName(T)),
    }
}

pub inline fn in(comptime T: type, port: u16) T {
    return switch (T) {
        u8 => asm volatile ("inb %[port], %[result]"
            : [result] "={al}" (-> u8),
            : [port] "N{dx}" (port),
        ),
        else => @compileError("Invalid inport type: " ++ @typeName(T)),
    };
}
