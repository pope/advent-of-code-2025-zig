const std = @import("std");
const aoc = @import("root.zig");
const day1 = @import("day1.zig");
const day2 = @import("day2.zig");
const day3 = @import("day3.zig");
const day4 = @import("day4.zig");
const day5 = @import("day5.zig");
const day6 = @import("day6.zig");
const day7 = @import("day7.zig");
const day8 = @import("day8.zig");

fn kib(num: u64) u64 {
    return num << 10;
}

pub fn main(init: std.process.Init) !void {
    const ArgToFnMap = std.StringArrayHashMapUnmanaged(
        *const fn (alloc: std.mem.Allocator) anyerror!aoc.Answer,
    );
    var map = ArgToFnMap.empty;
    defer map.deinit(init.gpa);

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // Pre-allocate some space so that the first run with timings aren't the
    // one paying this cost.
    _ = try init.arena.allocator().alloc(u8, kib(64));
    _ = init.arena.reset(.retain_capacity);

    try map.put(init.gpa, "day1", &day1.solve);
    try map.put(init.gpa, "day2", &day2.solve);
    try map.put(init.gpa, "day3", &day3.solve);
    try map.put(init.gpa, "day4", &day4.solve);
    try map.put(init.gpa, "day5", &day5.solve);
    try map.put(init.gpa, "day6", &day6.solve);
    try map.put(init.gpa, "day7", &day7.solve);
    try map.put(init.gpa, "day8", &day8.solve);

    var run_all = true;

    var it = init.minimal.args.iterate();
    _ = it.next(); // drop the program name
    while (it.next()) |arg| {
        if (map.get(arg)) |func| {
            run_all = false;
            const start = std.Io.Clock.now(.awake, init.io);
            _ = init.arena.reset(.retain_capacity);
            const answer = try func(init.arena.allocator());
            const end = std.Io.Clock.now(.awake, init.io);
            try printAnswer(stdout, answer, start.durationTo(end));
        }
    }
    if (run_all) {
        for (map.values()) |func| {
            const start = std.Io.Clock.now(.awake, init.io);
            _ = init.arena.reset(.retain_capacity);
            const answer = try func(init.arena.allocator());
            const end = std.Io.Clock.now(.awake, init.io);
            try printAnswer(stdout, answer, start.durationTo(end));
        }
    }
}

fn printAnswer(w: *std.Io.Writer, answer: aoc.Answer, duration: std.Io.Duration) !void {
    const nanos = duration.toNanoseconds();

    try w.print("{d:02}.1: ", .{answer.day});
    try answer.part1.write(w);
    _ = try w.write("\n");

    try w.print("{d:02}.2: ", .{answer.day});
    try answer.part2.write(w);
    _ = try w.write("\n");

    try w.flush();

    // Debug info - timing

    std.debug.print("{d:02}.x: ", .{answer.day});

    if (nanos < std.time.ns_per_us) {
        std.debug.print("{} ns\n", .{nanos});
    } else if (nanos < std.time.ns_per_ms) {
        std.debug.print(
            "{d:.3} us\n",
            .{@as(f64, @floatFromInt(nanos)) / std.time.ns_per_us},
        );
    } else {
        std.debug.print(
            "{d:.3} ms\n",
            .{@as(f64, @floatFromInt(nanos)) / std.time.ns_per_ms},
        );
    }
}

test {
    std.testing.refAllDecls(@This());
}
