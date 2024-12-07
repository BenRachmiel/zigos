const vga = @import("../drivers/vga.zig");
const gdt = @import("../gdt.zig");
const tss = @import("../tss.zig");

pub fn verifyGdtTss(args: []const u8) void {
    const screen = vga.getScreen();
    _ = args;

    screen.write("\n=== Starting GDT & TSS Verification ===\n\n");

    // Store original color
    const original_color = screen.color;

    // Verify GDT size and pointer
    screen.write("Checking GDT pointer... ");
    const gdt_ptr = @as(*const gdt.GdtPointer, @ptrFromInt(@intFromPtr(&gdt.gdt_pointer)));
    if (gdt_ptr.limit != (@sizeOf(@TypeOf(gdt.gdt)) - 1)) {
        screen.setColor(.Red, .Black);
        screen.write("ERROR: Invalid GDT limit\n");
        screen.setColor(.White, .Black);
        screen.write("  Expected: ");
        printHex16(@as(u16, @truncate(@sizeOf(@TypeOf(gdt.gdt)) - 1)));
        screen.write("\n  Got:      ");
        printHex16(gdt_ptr.limit);
        screen.write("\n");
    } else {
        screen.setColor(.Green, .Black);
        screen.write("OK\n");
    }
    screen.setColor(.LightGrey, .Black);

    // Verify each GDT entry
    screen.write("\nVerifying GDT entries:\n");

    // Null descriptor
    screen.write("\n[Entry 0] Null Descriptor ");
    verifyNullDescriptor();

    // Kernel code segment
    screen.write("\n[Entry 1] Kernel Code Segment ");
    verifyCodeSegment(1, 0);

    // Kernel data segment
    screen.write("\n[Entry 2] Kernel Data Segment ");
    verifyDataSegment(2, 0);

    // User code segment
    screen.write("\n[Entry 3] User Code Segment ");
    verifyCodeSegment(3, 3);

    // User data segment
    screen.write("\n[Entry 4] User Data Segment ");
    verifyDataSegment(4, 3);

    // TSS entry
    screen.write("\n[Entry 5] TSS Segment ");
    verifyTssSegment();

    // Verify TSS
    screen.write("\nVerifying TSS: ");
    verifyTssFields();

    screen.color = original_color;
    screen.write("\n=== GDT & TSS Verification Complete ===\n> ");
}

fn verifyNullDescriptor() void {
    const screen = vga.getScreen();
    const entry = gdt.gdt[0];

    var valid = true;
    if (entry.limit_low != 0) valid = false;
    if (entry.base_low != 0) valid = false;
    if (entry.base_middle != 0) valid = false;
    if (entry.access != 0) valid = false;
    if (entry.granularity != 0) valid = false;
    if (entry.base_high != 0) valid = false;

    if (valid) {
        screen.setColor(.Green, .Black);
        screen.write("  Status: OK\n");
    } else {
        screen.setColor(.Red, .Black);
        screen.write("  Status: ERROR - Non-zero values in null descriptor\n");
        printGdtEntry(0);
    }
    screen.setColor(.LightGrey, .Black);
}

fn verifyCodeSegment(index: usize, ring: u2) void {
    const screen = vga.getScreen();
    const entry = gdt.gdt[index];
    var valid = true;

    // Base should be 0
    if (entry.base_low != 0 or entry.base_middle != 0 or entry.base_high != 0) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Non-zero base address\n");
    }

    // Limit should be 0xFFFFF (full 4GB)
    const full_limit = (@as(u32, entry.granularity & 0x0F) << 16) | entry.limit_low;
    if (full_limit != 0xFFFFF) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid limit\n");
    }

    // Verify access rights
    const access = gdt.AccessFlags.fromU8(entry.access);
    if (!access.present or !access.executable or access.privilege_level != ring) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid access rights\n");
    }

    if (valid) {
        screen.setColor(.Green, .Black);
        screen.write("  Status: OK\n");
    } else {
        printGdtEntry(index);
    }
    screen.setColor(.LightGrey, .Black);
}

fn verifyDataSegment(index: usize, ring: u2) void {
    const screen = vga.getScreen();
    const entry = gdt.gdt[index];
    var valid = true;

    // Base should be 0
    if (entry.base_low != 0 or entry.base_middle != 0 or entry.base_high != 0) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Non-zero base address\n");
    }

    // Limit should be 0xFFFFF (full 4GB)
    const full_limit = (@as(u32, entry.granularity & 0x0F) << 16) | entry.limit_low;
    if (full_limit != 0xFFFFF) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid limit\n");
    }

    // Verify access rights
    const access = gdt.AccessFlags.fromU8(entry.access);
    if (!access.present or access.executable or access.privilege_level != ring) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid access rights\n");
    }

    if (valid) {
        screen.setColor(.Green, .Black);
        screen.write("  Status: OK\n");
    } else {
        printGdtEntry(index);
    }
    screen.setColor(.LightGrey, .Black);
}

fn verifyTssSegment() void {
    const screen = vga.getScreen();
    const entry = gdt.gdt[5];
    var valid = true;

    // Get TSS base from entry
    const base = @as(u32, entry.base_high) << 24 |
        @as(u32, entry.base_middle) << 16 |
        entry.base_low;

    // Verify base points to our TSS
    if (base != @intFromPtr(tss.getTSS())) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid TSS base address\n");
        screen.write("  Expected: ");
        printHex32(@intFromPtr(tss.getTSS()));
        screen.write("\n  Got:      ");
        printHex32(base);
        screen.write("\n");
    }

    // Verify limit matches TSS size
    const full_limit = (@as(u32, entry.granularity & 0x0F) << 16) | entry.limit_low;
    if (full_limit != @sizeOf(tss.TSS)) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid TSS limit\n");
        screen.write("  Expected: ");
        printHex32(@sizeOf(tss.TSS));
        screen.write("\n  Got:      ");
        printHex32(full_limit);
        screen.write("\n");
    }

    if (valid) {
        screen.setColor(.Green, .Black);
        screen.write("  Status: OK\n");
    } else {
        printGdtEntry(5);
    }
    screen.setColor(.LightGrey, .Black);
}

fn verifyTssFields() void {
    const screen = vga.getScreen();
    const tss_ptr = tss.getTSS();
    var valid = true;

    // Verify SS0 is kernel data segment
    if (tss_ptr.ss0 != 0x10) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid SS0 value\n");
        screen.write("  Expected: 0x10\n  Got:      ");
        printHex32(tss_ptr.ss0);
        screen.write("\n");
    }

    // ESP0 should not be 0
    if (tss_ptr.esp0 == 0) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: ESP0 is zero\n");
    }

    // IOPB offset should be TSS size to indicate no I/O permission map
    if (tss_ptr.iomap_base != @sizeOf(tss.TSS)) {
        valid = false;
        screen.setColor(.Red, .Black);
        screen.write("  ERROR: Invalid IOPB offset\n");
        screen.write("  Expected: ");
        printHex16(@as(u16, @truncate(@sizeOf(tss.TSS))));
        screen.write("\n  Got:      ");
        printHex16(tss_ptr.iomap_base);
        screen.write("\n");
    }

    if (valid) {
        screen.setColor(.Green, .Black);
        screen.write("  Status: OK\n");
    }
    screen.setColor(.LightGrey, .Black);
}

fn printGdtEntry(index: usize) void {
    const screen = vga.getScreen();
    const entry = gdt.gdt[index];

    screen.write("  Details:\n");
    screen.write("    Base:  ");
    printHex32(@as(u32, entry.base_high) << 24 |
        @as(u32, entry.base_middle) << 16 |
        entry.base_low);
    screen.write("\n    Limit: ");
    printHex32(@as(u32, entry.granularity & 0x0F) << 16 |
        entry.limit_low);
    screen.write("\n    Access: ");
    printHex8(entry.access);
    screen.write("\n    Flags:  ");
    printHex8(entry.granularity);
    screen.write("\n");
}

fn printHex32(value: u32) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    var i: u5 = 28;
    while (i > 0) : (i -= 4) {
        screen.putChar(hex[(@as(u8, @truncate((value >> i) & 0xF)))]);
    }
    screen.putChar(hex[(@as(u8, @truncate(value & 0xF)))]);
}

fn printHex16(value: u16) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    var i: u4 = 12;
    while (i > 0) : (i -= 4) {
        screen.putChar(hex[(@as(u8, @truncate((value >> i) & 0xF)))]);
    }
    screen.putChar(hex[(@as(u8, @truncate(value & 0xF)))]);
}

fn printHex8(value: u8) void {
    const screen = vga.getScreen();
    const hex = "0123456789ABCDEF";
    screen.putChar(hex[(value >> 4) & 0xF]);
    screen.putChar(hex[value & 0xF]);
}
