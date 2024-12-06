const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .abi = .none,
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .cwd_relative = "src/boot.zig" },
    });

    // Create the zig-cache directory
    const cache_dir = b.cache_root.path orelse unreachable;
    std.fs.cwd().makePath(cache_dir) catch {};

    const asm_out = b.cache_root.join(b.allocator, &.{"interrupts_asm.o"}) catch unreachable;
    const asm_src = b.pathFromRoot("src/interrupts_asm.asm");

    // Create NASM build step
    const nasm = b.addSystemCommand(&.{
        "nasm",
        "-f",
        "elf32",
        "-o",
        asm_out,
        asm_src,
    });

    // Add the assembly object file
    kernel.addObjectFile(.{ .cwd_relative = asm_out });

    // Make kernel depend on nasm command
    kernel.step.dependOn(&nasm.step);

    kernel.setLinkerScriptPath(.{ .cwd_relative = "linker.ld" });
    b.installArtifact(kernel);
}
