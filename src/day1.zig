const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day1-input");
    defer setup.deinit();
    var it = setup.lineIterator();

    try part1(&it);
    try setup.reset();
    try part2(&it);
}

fn part1(it: *aoc.InputIterator) !void {
    var dial: i16 = 50;
    var count: u16 = 0;

    while (try it.next()) |line| {
        const new_dial, const new_count = try part1ProcessLine(
            line,
            dial,
        );
        dial = new_dial;
        count += new_count;
    }
    std.debug.print("01.1: Password = {d}\n", .{count});
}

fn part2(it: *aoc.InputIterator) !void {
    var dial: i16 = 50;
    var count: u16 = 0;

    while (try it.next()) |line| {
        const new_dial, const new_count = try part2ProcessLine(
            line,
            dial,
        );
        dial = new_dial;
        count += new_count;
    }
    std.debug.print("01.2: Password = {d}\n", .{count});
}

fn part1ProcessLine(line: []const u8, dial: i16) !struct { i16, u16 } {
    const dir: i16 = switch (line[0]) {
        'L' => -1,
        'R' => 1,
        else => return error.Oops,
    };
    const val = try std.fmt.parseInt(i16, line[1..], 10);
    const new_dial = @mod(dial + (dir * val), 100);
    return .{ new_dial, if (new_dial == 0) 1 else 0 };
}

fn part2ProcessLine(line: []const u8, dial: i16) !struct { i16, u16 } {
    const dir: i16 = switch (line[0]) {
        'L' => -1,
        'R' => 1,
        else => return error.Oops,
    };
    const val = try std.fmt.parseInt(i16, line[1..], 10);
    var count = @divFloor(@as(u16, @intCast(val)), 100);
    const rem = @mod(val, 100);
    const new_dial = dial + (dir * rem);
    if ((new_dial < 0 and dial != 0) or new_dial > 99 or new_dial == 0) {
        count += 1;
    }
    return .{ @mod(new_dial, 100), count };
}

test "day 1 - part 1" {
    var dial: i16 = 50;
    var count: u16 = 0;
    const test_data = [_]struct {
        input: []const u8,
        dial: i16,
        count: u16,
    }{
        .{ .input = "L68", .dial = 82, .count = 0 },
        .{ .input = "L30", .dial = 52, .count = 0 },
        .{ .input = "R48", .dial = 0, .count = 1 },
        .{ .input = "L5", .dial = 95, .count = 1 },
        .{ .input = "R60", .dial = 55, .count = 1 },
        .{ .input = "L55", .dial = 0, .count = 2 },
        .{ .input = "L1", .dial = 99, .count = 2 },
        .{ .input = "L99", .dial = 0, .count = 3 },
        .{ .input = "R14", .dial = 14, .count = 3 },
        .{ .input = "L82", .dial = 32, .count = 3 },
    };
    for (test_data) |d| {
        const new_dial, const new_count = try part1ProcessLine(
            d.input,
            dial,
        );
        dial = new_dial;
        count += new_count;
        try std.testing.expectEqual(d.dial, dial);
        try std.testing.expectEqual(d.count, count);
    }
}

test "day 1 - part 2" {
    var dial: i16 = 50;
    var count: u16 = 0;
    const test_data = [_]struct {
        input: []const u8,
        dial: i16,
        count: u16,
    }{
        .{ .input = "L68", .dial = 82, .count = 1 },
        .{ .input = "L30", .dial = 52, .count = 1 },
        .{ .input = "R48", .dial = 0, .count = 2 },
        .{ .input = "L5", .dial = 95, .count = 2 },
        .{ .input = "R60", .dial = 55, .count = 3 },
        .{ .input = "L55", .dial = 0, .count = 4 },
        .{ .input = "L1", .dial = 99, .count = 4 },
        .{ .input = "L99", .dial = 0, .count = 5 },
        .{ .input = "R214", .dial = 14, .count = 7 },
        .{ .input = "L82", .dial = 32, .count = 8 },
    };
    for (test_data) |d| {
        const new_dial, const new_count = try part2ProcessLine(
            d.input,
            dial,
        );
        dial = new_dial;
        count += new_count;
        try std.testing.expectEqual(d.dial, dial);
        try std.testing.expectEqual(d.count, count);
    }
}
