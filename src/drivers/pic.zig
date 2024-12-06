// Command and data ports for master and slave PICs
const PIC1_COMMAND = 0x20;
const PIC1_DATA = 0x21;
const PIC2_COMMAND = 0xA0;
const PIC2_DATA = 0xA1;

// Initialization Command Words
const ICW1_ICW4 = 0x01; // ICW4 needed
const ICW1_SINGLE = 0x02; // Single (cascade) mode
const ICW1_INTERVAL4 = 0x04; // Call address interval 4
const ICW1_LEVEL = 0x08; // Level triggered mode
const ICW1_INIT = 0x10; // Initialization

const ICW4_8086 = 0x01; // 8086/88 (MCS-80/85) mode
const ICW4_AUTO = 0x02; // Auto (normal) EOI
const ICW4_BUF_SLAVE = 0x08; // Buffered mode/slave
const ICW4_BUF_MASTER = 0x0C; // Buffered mode/master
const ICW4_SFNM = 0x10; // Special fully nested

pub fn remap(offset1: u8, offset2: u8) void {
    // Save masks
    const a1 = in(u8, PIC1_DATA);
    const a2 = in(u8, PIC2_DATA);

    // Start initialization sequence
    out(u8, PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();
    out(u8, PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();

    // Set vector offsets
    out(u8, PIC1_DATA, offset1);
    io_wait();
    out(u8, PIC2_DATA, offset2);
    io_wait();

    // Tell Master PIC there is a slave PIC at IRQ2
    out(u8, PIC1_DATA, 4);
    io_wait();
    // Tell Slave PIC its cascade identity
    out(u8, PIC2_DATA, 2);
    io_wait();

    // Set 8086 mode
    out(u8, PIC1_DATA, ICW4_8086);
    io_wait();
    out(u8, PIC2_DATA, ICW4_8086);
    io_wait();

    // Restore saved masks
    out(u8, PIC1_DATA, a1);
    out(u8, PIC2_DATA, a2);
}

pub fn maskIRQ(irq: u8) void {
    if (irq >= 16) return; // Invalid IRQ number

    if (irq < 8) {
        const value = in(u8, PIC1_DATA);
        out(u8, PIC1_DATA, value | (@as(u8, 1) << @as(u3, @truncate(irq))));
    } else {
        const value = in(u8, PIC2_DATA);
        out(u8, PIC2_DATA, value | (@as(u8, 1) << @as(u3, @truncate(irq - 8))));
    }
}

pub fn unmaskIRQ(irq: u8) void {
    if (irq >= 16) return; // Invalid IRQ number

    if (irq < 8) {
        const value = in(u8, PIC1_DATA);
        out(u8, PIC1_DATA, value & ~(@as(u8, 1) << @as(u3, @truncate(irq))));
    } else {
        const value = in(u8, PIC2_DATA);
        out(u8, PIC2_DATA, value & ~(@as(u8, 1) << @as(u3, @truncate(irq - 8))));
    }
}

fn io_wait() void {
    out(u8, 0x80, 0);
}

fn out(comptime T: type, port: u16, value: T) void {
    switch (T) {
        u8 => asm volatile ("outb %[value], %[port]"
            :
            : [value] "{al}" (value),
              [port] "N{dx}" (port),
        ),
        else => @compileError("Invalid outport type: " ++ @typeName(T)),
    }
}

fn in(comptime T: type, port: u16) T {
    return switch (T) {
        u8 => asm volatile ("inb %[port], %[result]"
            : [result] "={al}" (-> u8),
            : [port] "N{dx}" (port),
        ),
        else => @compileError("Invalid inport type: " ++ @typeName(T)),
    };
}
