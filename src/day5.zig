const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day5-input");
    defer setup.deinit();

    const num_size = u64;
    var it = setup.lineIterator();
    var ranges = try processRanges(
        num_size,
        setup.allocator(),
        &it,
    );
    defer ranges.deinit(setup.allocator());

    std.debug.print(
        "05.1: Fresh = {}\n",
        .{try part1Answer(num_size, ranges.items, &it)},
    );

    std.debug.print(
        "05.2: Fresh = {}\n",
        .{part2Answer(num_size, ranges.items)},
    );
}

fn part1Answer(
    comptime T: type,
    ranges: []const Range(T),
    it: *aoc.LineIterator,
) !u16 {
    var num_fresh: u16 = 0;
    while (try it.next()) |line| {
        const a = try std.fmt.parseInt(T, line, 10);
        for (ranges) |r| {
            if (a >= r.low and a <= r.high) {
                num_fresh += 1;
                break;
            }
        }
    }
    return num_fresh;
}

fn part2Answer(comptime T: type, ranges: []const Range(T)) T {
    var num_fresh: T = 0;
    for (ranges) |r| {
        num_fresh += r.high - r.low + 1;
    }
    return num_fresh;
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
    it: *aoc.LineIterator,
) !std.ArrayList(Range(T)) {
    var ranges: std.ArrayList(Range(T)) = .empty;
    while (try it.next()) |line| {
        if (std.mem.eql(u8, "", line)) break;
        try ranges.append(
            alloc,
            try Range(T).initFromStr(line),
        );
    } else return error.Oops;
    compressRanges(Range(T), &ranges);
    return ranges;
}

const test_input =
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

test "day 5 - part 1" {
    const size_type = u8;

    var it = aoc.LineIterator.initFromBuffer(test_input);
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

    const fresh = try part1Answer(size_type, ranges.items, &it);
    try std.testing.expectEqual(3, fresh);
}

test "day 5 - part 2" {
    const size_type = u8;

    var it = aoc.LineIterator.initFromBuffer(test_input);
    var ranges = try processRanges(
        size_type,
        std.testing.allocator,
        &it,
    );
    defer ranges.deinit(std.testing.allocator);

    const fresh = part2Answer(size_type, ranges.items);
    try std.testing.expectEqual(14, fresh);
}
