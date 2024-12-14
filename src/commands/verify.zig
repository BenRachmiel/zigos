const vga = @import("../drivers/vga.zig");
const utils = @import("../utils.zig");
const gdt = @import("../gdt.zig");
const tss = @import("../tss.zig");
const boot = @import("../boot.zig");
const memory = @import("../memory.zig");

fn calculateLimit(entry: gdt.GdtEntry) u32 {
    const screen = vga.getScreen();

    screen.write("\nLimit calculation:\n");
    screen.write("  granularity byte: 0x");
    utils.printHex8(entry.granularity);
    screen.write("\n  upper bits: 0x");
    utils.printHex8(entry.granularity & 0x0F);
    screen.write("\n  limit_low: 0x");
    utils.printHex16(entry.limit_low);
    screen.write("\n");

    const raw_limit = (@as(u32, entry.granularity & 0x0F) << 16) | entry.limit_low;
    return raw_limit;
}

fn verifySegmentDescriptor(entry: gdt.GdtEntry, index: usize, expected_base: u32, expected_limit: u32, expected_access: gdt.AccessFlags) void {
    const screen = vga.getScreen();

    const actual_base = @as(u32, entry.base_high) << 24 |
        @as(u32, entry.base_middle) << 16 |
        entry.base_low;

    const actual_limit = calculateLimit(entry);

    screen.write("Verifying GDT[");
    utils.printDec(@as(u32, @truncate(index)));
    screen.write("]:\n");

    screen.write("  Granularity byte: 0x");
    utils.printHex8(entry.granularity);
    screen.write(" (G=");
    screen.write(if (entry.granularity & 0x80 != 0) "1" else "0");
    screen.write(" D=");
    screen.write(if (entry.granularity & 0x40 != 0) "1" else "0");
    screen.write(")\n");

    screen.write("  Base: Expected 0x");
    utils.printHex32(expected_base);
    screen.write(", Got 0x");
    utils.printHex32(actual_base);
    if (actual_base != expected_base) {
        screen.setColor(.Red, .Black);
        screen.write(" [MISMATCH]");
        utils.delay();
        screen.setColor(.White, .Black);
    }
    screen.write("\n");

    screen.write("  Limit: Expected 0x");
    utils.printHex32(expected_limit);
    screen.write(", Got 0x");
    utils.printHex32(actual_limit);
    if (actual_limit != expected_limit) {
        screen.setColor(.Red, .Black);
        screen.write(" [MISMATCH]");
        utils.delay();
        screen.setColor(.White, .Black);
    }
    screen.write("\n");

    screen.write("  Access: Expected 0x");
    utils.printHex8(expected_access.toU8());
    screen.write(", Got 0x");
    utils.printHex8(entry.access);
    if (entry.access != expected_access.toU8()) {
        screen.setColor(.Red, .Black);
        screen.write(" [MISMATCH]");
        utils.delay();
        screen.setColor(.White, .Black);
    }
    screen.write("\n");
}

fn verifyNullDescriptor() void {
    const screen = vga.getScreen();
    screen.write("\nVerifying Null Descriptor...\n");
    const null_desc = gdt.gdt[0];

    if (null_desc.access != 0 or null_desc.base_low != 0 or
        null_desc.base_middle != 0 or null_desc.base_high != 0)
    {
        screen.setColor(.Red, .Black);
        screen.write("ERROR: Null descriptor is not zero!\n");
        utils.delay();
        screen.setColor(.White, .Black);
    } else {
        screen.setColor(.Green, .Black);
        screen.write("Null descriptor OK\n");
        screen.setColor(.White, .Black);
    }
}

fn verifyCodeAndDataSegments() void {
    const screen = vga.getScreen();
    const memory_stats = memory.getMemoryStats();
    const phys_limit: u32 = @truncate(memory_stats.total_memory - 1);

    screen.write("\nPhysical Memory: ");
    utils.printDec(@truncate(memory_stats.total_memory / 1024 / 1024));
    screen.write(" MB (limit: 0x");
    utils.printHex32(phys_limit);
    screen.write(")\n");
    utils.delay();

    verifySegmentDescriptor(gdt.gdt[1], 1, 0, phys_limit, gdt.makeKernelCodeFlags());
    verifySegmentDescriptor(gdt.gdt[2], 2, 0, phys_limit, gdt.makeKernelDataFlags());
    verifySegmentDescriptor(gdt.gdt[3], 3, 0, phys_limit, gdt.makeUserCodeFlags());
    verifySegmentDescriptor(gdt.gdt[4], 4, 0, phys_limit, gdt.makeUserDataFlags());
}

fn verifyStackSetup() void {
    const screen = vga.getScreen();

    screen.write("\n=== Stack Verification ===\n");

    const current_esp: usize = asm volatile ("mov %%esp, %[ret]"
        : [ret] "=r" (-> usize),
    );

    screen.write("Current ESP: 0x");
    utils.printHex(current_esp);
    screen.write("\n");

    const tss_ptr = tss.getTSS();
    screen.write("TSS ESP0: 0x");
    utils.printHex(tss_ptr.esp0);
    screen.write("\n");
    screen.write("TSS IST1: 0x");
    utils.printHex(tss_ptr.ist1);
    screen.write("\n");

    const kernel_stack_bottom = boot.STACK.getKernelBase();
    const kernel_stack_top = boot.STACK.getKernelTop();
    const interrupt_stack_bottom = boot.STACK.getInterruptBase();
    const interrupt_stack_top = boot.STACK.getInterruptTop();

    screen.write("\nStack Ranges:\n");
    screen.write("Kernel Stack:    0x");
    utils.printHex(kernel_stack_bottom);
    screen.write(" - 0x");
    utils.printHex(kernel_stack_top);
    screen.write("\n");

    screen.write("Interrupt Stack: 0x");
    utils.printHex(interrupt_stack_bottom);
    screen.write(" - 0x");
    utils.printHex(interrupt_stack_top);
    screen.write("\n");

    screen.write("\nStack Pointer Validation:\n");
    if (current_esp < kernel_stack_bottom or current_esp > kernel_stack_top) {
        screen.setColor(.Red, .Black);
        screen.write("ERROR: Current stack pointer outside kernel stack range!\n");
        screen.write("ESP=0x");
        utils.printHex(current_esp);
        screen.write(" not in 0x");
        utils.printHex(kernel_stack_bottom);
        screen.write("-0x");
        utils.printHex(kernel_stack_top);
        screen.write("\n");
        utils.delay();
        screen.setColor(.White, .Black);
    } else {
        screen.setColor(.Green, .Black);
        screen.write("Current stack pointer in valid range\n");
        screen.setColor(.White, .Black);
    }

    if (tss_ptr.esp0 != kernel_stack_top) {
        screen.setColor(.Red, .Black);
        screen.write("ERROR: TSS ESP0 not pointing to kernel stack top!\n");
        screen.write("Expected: 0x");
        utils.printHex(kernel_stack_top);
        screen.write(" Got: 0x");
        utils.printHex(tss_ptr.esp0);
        utils.delay();
        screen.write("\n");
        screen.setColor(.White, .Black);
    } else {
        screen.setColor(.Green, .Black);
        screen.write("TSS ESP0 correctly configured\n");
        screen.setColor(.White, .Black);
    }

    if (tss_ptr.ist1 != interrupt_stack_top) {
        screen.setColor(.Red, .Black);
        screen.write("ERROR: TSS IST1 not pointing to interrupt stack top!\n");
        screen.write("Expected: 0x");
        utils.printHex(interrupt_stack_top);
        screen.write(" Got: 0x");
        utils.printHex(tss_ptr.ist1);
        utils.delay();
        screen.write("\n");
        screen.setColor(.White, .Black);
    } else {
        screen.setColor(.Green, .Black);
        screen.write("TSS IST1 correctly configured\n");
        screen.setColor(.White, .Black);
    }
}

fn verifyTSS() void {
    const screen = vga.getScreen();
    screen.write("\nStarting TSS verification...\n");

    // Print TSS pointer
    screen.write("TSS pointer: 0x");
    utils.printHex(@intFromPtr(tss.getTSS()));
    screen.write("\n");

    const current_tss = tss.getTSS();
    screen.write("Got TSS structure\n");

    // Check SS0 first
    screen.write("Checking SS0...\n");
    screen.write("SS0: Expected 0x10, Got 0x");
    utils.printHex32(current_tss.ss0);
    screen.write("\n");

    // Try reading each segment value individually
    screen.write("Reading CS: 0x");
    utils.printHex32(current_tss.cs);
    screen.write("\nReading SS: 0x");
    utils.printHex32(current_tss.ss);
    screen.write("\nReading DS: 0x");
    utils.printHex32(current_tss.ds);
    screen.write("\n");

    screen.write("\n=== TSS Verification ===\n");

    screen.write("SS0: Expected 0x10, Got 0x");
    utils.printHex32(current_tss.ss0);
    if (current_tss.ss0 != 0x10) {
        screen.setColor(.Red, .Black);
        screen.write(" [MISMATCH]");
        utils.delay();
        screen.setColor(.White, .Black);
    }
    screen.write("\n");

    const segments = [_]struct { name: []const u8, value: u32 }{
        .{ .name = "CS", .value = current_tss.cs },
        .{ .name = "SS", .value = current_tss.ss },
        .{ .name = "DS", .value = current_tss.ds },
        .{ .name = "ES", .value = current_tss.es },
        .{ .name = "FS", .value = current_tss.fs },
        .{ .name = "GS", .value = current_tss.gs },
    };

    screen.write("\nVerifying null segments:\n");
    for (segments) |seg| {
        screen.write("  ");
        screen.write(seg.name);
        screen.write(": ");
        if (seg.value != 0) {
            screen.setColor(.Red, .Black);
            screen.write("NOT NULL (0x");
            utils.printHex32(seg.value);
            screen.write(")");
            utils.delay();
            screen.setColor(.White, .Black);
        } else {
            screen.setColor(.Green, .Black);
            screen.write("NULL");
            screen.setColor(.White, .Black);
        }
        screen.write("\n");
    }

    screen.write("\nI/O Map Base: Expected ");
    utils.printDec(@sizeOf(tss.TSS));
    screen.write(", Got ");
    utils.printDec(current_tss.iomap_base);
    if (current_tss.iomap_base != @sizeOf(tss.TSS)) {
        screen.setColor(.Red, .Black);
        screen.write(" [MISMATCH]");
        utils.delay();
        screen.setColor(.White, .Black);
    }
    screen.write("\n");
}

pub fn execute(args: []const u8) void {
    const screen = vga.getScreen();
    _ = args;

    screen.write("\n=== Starting System Verification ===\n");

    screen.write("\nStep 1: Stack Verification\n");
    screen.write("-----------------------\n");
    verifyStackSetup();

    screen.write("\nStep 2: GDT Verification\n");
    screen.write("----------------------\n");
    verifyNullDescriptor();
    verifyCodeAndDataSegments();

    screen.write("\nStep 3: TSS Verification\n");
    screen.write("----------------------\n");
    verifyTSS();

    screen.write("\n");
    screen.write("================================\n");
    screen.write("System Verification Complete\n");
    screen.write("================================\n");
}
