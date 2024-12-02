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

    kernel.setLinkerScriptPath(.{ .cwd_relative = "linker.ld" });
    b.installArtifact(kernel);
}
