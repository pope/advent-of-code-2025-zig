const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day5-input");
    defer setup.deinit();

    var reader = setup.reader();
    try part1(setup.allocator(), &reader.interface);
}

fn part1(alloc: std.mem.Allocator, reader: *std.io.Reader) !void {
    const num_size = u64;
    const RangeT = Range(num_size);

    var ranges: std.ArrayList(RangeT) = .empty;
    defer ranges.deinit(alloc);
    while (try reader.takeDelimiter('\n')) |line| {
        if (std.mem.eql(u8, "", line)) break;
        try ranges.append(alloc, try RangeT.initFromStr(line));
    } else return error.Oops;

    var num_fresh: u16 = 0;
    while (try reader.takeDelimiter('\n')) |line| {
        const a = try std.fmt.parseInt(num_size, line, 10);
        for (ranges.items) |r| {
            if (a >= r.low and a <= r.high) {
                num_fresh += 1;
                break;
            }
        }
    }

    std.debug.print("05.1: Fresh = {}\n", .{num_fresh});
}

fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        low: T,
        high: T,

        fn initFromStr(str: []const u8) !Self {
            if (std.mem.indexOfScalar(u8, str, '-')) |i| {
                const a = try std.fmt.parseInt(T, str[0..i], 10);
                const b = try std.fmt.parseInt(T, str[i + 1 ..], 10);
                if (a > b) return error.Oops;
                return .{ .low = a, .high = b };
            } else {
                return error.Oops;
            }
        }

        fn rangeSort(context: void, l: Self, r: Self) bool {
            _ = context;
            return l.low < r.low;
        }
    };
}

test "day 5 - part 1" {
    const input =
        \\3-5
        \\10-14
        \\16-20
        \\12-18
        \\
        \\1
        \\5
        \\8
        \\11
        \\17
        \\32
    ;

    var it = std.mem.splitScalar(u8, input, '\n');

    const size_type = u8;
    const RangeT = Range(size_type);

    // TODO(pope): Maybe this could be an interval tree?
    var ranges: std.ArrayList(RangeT) = try .initCapacity(std.testing.allocator, 4);
    defer ranges.deinit(std.testing.allocator);
    while (it.next()) |line| {
        if (std.mem.eql(u8, "", line)) break;
        try ranges.append(
            std.testing.allocator,
            try RangeT.initFromStr(line),
        );
    } else {
        return error.Oops;
    }
    std.mem.sort(
        RangeT,
        ranges.items,
        {},
        RangeT.rangeSort,
    );

    const expectedRanges = [_]RangeT{
        .{ .low = 3, .high = 5 },
        .{ .low = 10, .high = 14 },
        .{ .low = 12, .high = 18 },
        .{ .low = 16, .high = 20 },
    };
    try std.testing.expectEqualSlices(
        RangeT,
        &expectedRanges,
        ranges.items,
    );

    var fresh: size_type = 0;
    while (it.next()) |line| {
        const a = try std.fmt.parseInt(size_type, line, 10);
        for (ranges.items) |r| {
            if (a >= r.low and a <= r.high) {
                fresh += 1;
                break;
            }
        }
    }

    try std.testing.expectEqual(3, fresh);
}
