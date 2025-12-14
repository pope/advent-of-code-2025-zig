const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day5-input");
    defer setup.deinit();

    var reader = setup.reader();

    const num_size = u64;
    const RangeT = Range(num_size);

    var ranges: std.ArrayList(RangeT) = .empty;
    defer ranges.deinit(setup.allocator());
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (std.mem.eql(u8, "", line)) break;
        try ranges.append(setup.allocator(), try RangeT.initFromStr(line));
    } else return error.Oops;
    compressRanges(RangeT, &ranges);

    try part1(num_size, ranges.items, &reader.interface);

    part2(num_size, ranges.items);
}

fn part1(comptime T: type, ranges: []const Range(T), reader: *std.io.Reader) !void {
    var num_fresh: u16 = 0;
    while (try reader.takeDelimiter('\n')) |line| {
        const a = try std.fmt.parseInt(T, line, 10);
        for (ranges) |r| {
            if (a >= r.low and a <= r.high) {
                num_fresh += 1;
                break;
            }
        }
    }

    std.debug.print("05.1: Fresh = {}\n", .{num_fresh});
}

fn part2(comptime T: type, ranges: []const Range(T)) void {
    var num_fresh: T = 0;
    for (ranges) |r| {
        num_fresh += r.high - r.low + 1;
    }
    std.debug.print("05.2: Fresh = {}\n", .{num_fresh});
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

fn compressRanges(
    comptime T: type,
    ranges: *std.ArrayList(T),
) void {
    std.mem.sort(T, ranges.items, {}, T.rangeSort);
    var prev: usize = 0;
    for (ranges.items[1..]) |r| {
        if (r.low - 1 <= ranges.items[prev].high) {
            ranges.items[prev].high = @max(ranges.items[prev].high, r.high);
        } else {
            prev += 1;
            ranges.items[prev] = r;
        }
    }

    const new_data: [0]T = undefined;
    ranges.replaceRangeAssumeCapacity(
        prev + 1,
        ranges.items.len - (prev + 1),
        &new_data,
    );
}

fn processRanges(
    comptime T: type,
    alloc: std.mem.Allocator,
    it: *std.mem.SplitIterator(u8, .scalar),
) !std.ArrayList(Range(T)) {
    var ranges: std.ArrayList(Range(T)) = .empty;
    while (it.next()) |line| {
        if (std.mem.eql(u8, "", line)) break;
        try ranges.append(
            alloc,
            try Range(T).initFromStr(line),
        );
    } else return error.Oops;
    compressRanges(Range(T), &ranges);
    return ranges;
}

test "day 5 - part 1" {
    const size_type = u8;
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

    var ranges = try processRanges(
        size_type,
        std.testing.allocator,
        &it,
    );
    defer ranges.deinit(std.testing.allocator);

    const expectedRanges = [_]Range(size_type){
        .{ .low = 3, .high = 5 },
        .{ .low = 10, .high = 20 },
    };
    try std.testing.expectEqualSlices(
        Range(size_type),
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

test "day 5 - part 2" {
    const size_type = u8;
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
    var ranges = try processRanges(
        size_type,
        std.testing.allocator,
        &it,
    );
    defer ranges.deinit(std.testing.allocator);

    var fresh: size_type = 0;
    for (ranges.items) |r| {
        fresh += r.high - r.low + 1;
    }
    try std.testing.expectEqual(14, fresh);
}
