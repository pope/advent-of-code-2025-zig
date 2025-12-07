const std = @import("std");

const Context = struct {
    b: *std.Build,
    run_step: *std.Build.Step,
    test_step: *std.Build.Step,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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
    };

    for (0..3) |i| {
        try addDayExeAndTests(&ctx, i + 1);
    }
}

fn addDayExeAndTests(ctx: *const Context, day: usize) !void {
    const name = try std.fmt.allocPrint(
        ctx.b.allocator,
        "day{}",
        .{day},
    );
    defer ctx.b.allocator.free(name);
    return addExeAndTests(ctx, name);
}

fn addExeAndTests(ctx: *const Context, name: []const u8) !void {
    const path = try std.fmt.allocPrint(
        ctx.b.allocator,
        "src/{s}.zig",
        .{name},
    );
    defer ctx.b.allocator.free(path);

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

    // Not freeing this since this kept by the builder.
    const exe_name = try std.fmt.allocPrint(
        ctx.b.allocator,
        "run-{s}",
        .{name},
    );
    const exe_desc = try std.fmt.allocPrint(
        ctx.b.allocator,
        "Run {s}",
        .{name},
    );
    const exe_step = ctx.b.step(exe_name, exe_desc);
    exe_step.dependOn(&run_cmd.step);
}
