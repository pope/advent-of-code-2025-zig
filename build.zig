const std = @import("std");

const Context = struct {
    b: *std.Build,
    run_step: *std.Build.Step,
    test_step: *std.Build.Step,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    alloc: std.mem.Allocator,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("aoc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const ctx = Context{
        .b = b,
        .run_step = b.step("run", "Run all apps"),
        .test_step = b.step("test", "Run all tests"),
        .mod = mod,
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
        .alloc = std.heap.page_allocator,
    };

    try addExeAndTests(ctx, "day1");
    try addExeAndTests(ctx, "day2");
}

fn addExeAndTests(ctx: Context, name: []const u8) !void {
    const path = try std.fmt.allocPrint(
        ctx.alloc,
        "src/{s}.zig",
        .{name},
    );
    defer ctx.alloc.free(path);

    const exe = ctx.b.addExecutable(.{
        .name = name,
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(path),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = &.{
                .{ .name = "aoc", .module = ctx.mod },
            },
        }),
    });
    ctx.b.installArtifact(exe);
    const run_cmd = ctx.b.addRunArtifact(exe);
    run_cmd.step.dependOn(ctx.b.getInstallStep());
    ctx.run_step.dependOn(&run_cmd.step);

    const exe_tests = ctx.b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = ctx.b.addRunArtifact(exe_tests);
    ctx.test_step.dependOn(&run_exe_tests.step);
}
