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

pub fn main() !void {
    const ArgToFnMap = std.StringArrayHashMap(
        *const fn (alloc: std.mem.Allocator) anyerror!aoc.Answer,
    );
    var map: ArgToFnMap = .init(std.heap.page_allocator);
    defer map.deinit();

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Pre-allocate some space so that the first run with timings aren't the
    // one paying this cost.
    _ = try arena.allocator().alloc(u8, kib(64));
    _ = arena.reset(.retain_capacity);

    try map.put("day1", &day1.solve);
    try map.put("day2", &day2.solve);
    try map.put("day3", &day3.solve);
    try map.put("day4", &day4.solve);
    try map.put("day5", &day5.solve);
    try map.put("day6", &day6.solve);
    try map.put("day7", &day7.solve);
    try map.put("day8", &day8.solve);

    var run_all = true;

    var t = try std.time.Timer.start();

    var it = std.process.args();
    _ = it.next(); // drop the program name
    while (it.next()) |arg| {
        if (map.get(arg)) |func| {
            run_all = false;
            t.reset();
            _ = arena.reset(.retain_capacity);
            const answer = try func(arena.allocator());
            try printAnswer(stdout, answer, t.read());
        }
    }
    if (run_all) {
        for (map.values()) |func| {
            t.reset();
            _ = arena.reset(.retain_capacity);
            const answer = try func(arena.allocator());
            try printAnswer(stdout, answer, t.read());
        }
    }
}

fn printAnswer(w: *std.io.Writer, answer: aoc.Answer, nanos: u64) !void {
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
