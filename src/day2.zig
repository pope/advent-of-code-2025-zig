const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day2-input");
    defer setup.deinit();

    var it = setup.inputIterator(',');
    try part1(&it);

    try setup.reset();
    try part2(&it);
}

// Shout-outs to github.com/maneatingape/advent-of-code-rust for this idea on
// using patterns to find arithmetic series of data to test against.

const part_1_patterns = [_]Pattern{
    .init(2, 1),
    .init(4, 2),
    .init(6, 3),
    .init(8, 4),
    .init(10, 5),
};

const part_2_patterns = [_]Pattern{
    .init(2, 1),
    .init(3, 1),
    .init(4, 2),
    .init(5, 1),
    .init(6, 2),
    .init(6, 3),
    .init(7, 1),
    .init(8, 4),
    .init(9, 3),
    .init(10, 2),
    .init(10, 5),
};
const part_2_double_counted_patterns = [_]Pattern{
    .init(2 * 3, 1),
    .init(2 * 5, 1),
};

fn part1(it: *aoc.InputIterator) !void {
    const sum = try processPattern(
        it,
        &part_1_patterns,
        part_1_patterns[0..0], // Empty, no exclusions
        .noDebug(),
    );
    std.debug.print("02.1: Password = {d}\n", .{sum});
}

// Reworked to use the arithmetic sum
fn part2(it: *aoc.InputIterator) !void {
    const sum = try processPattern(
        it,
        &part_2_patterns,
        &part_2_double_counted_patterns,
        .noDebug(),
    );
    std.debug.print("02.2: Password = {d}\n", .{sum});
}

/// A context object for capturing debug information - which numbers were
/// found - when processing the data.
const DebugContext = union(enum) {
    const Self = @This();

    empty: void,
    list: *std.ArrayList(u64),

    fn noDebug() Self {
        return .{ .empty = {} };
    }

    fn initList(list: *std.ArrayList(u64)) Self {
        return .{ .list = list };
    }

    fn addFoundNumber(self: Self, num: u64) !void {
        return switch (self) {
            .empty => {},
            .list => |l| l.appendBounded(num),
        };
    }

    fn removeDuplicate(self: Self, num: u64) !void {
        switch (self) {
            .empty => {},
            .list => |l| {
                if (std.mem.indexOfScalar(
                    u64,
                    l.items,
                    num,
                )) |id| {
                    _ = l.orderedRemove(id);
                } else {
                    return error.Oops;
                }
            },
        }
    }
};

fn processPattern(
    it: *aoc.InputIterator,
    patterns: []const Pattern,
    exclusion_patterns: []const Pattern,
    debug_context: DebugContext,
) !u64 {
    var sum: u64 = 0;
    while (try it.next()) |input| {
        const start, const end = try parseRange(u64, input);
        sum += try arithmeticSum(
            patterns,
            start,
            end,
            .add,
            debug_context,
        );
        sum -= try arithmeticSum(
            exclusion_patterns,
            start,
            end,
            .remove_duplicates,
            debug_context,
        );
    }
    return sum;
}

inline fn parseRange(comptime T: type, input: []const u8) !struct { T, T } {
    const i = std.mem.indexOf(
        u8,
        input,
        "-",
    ) orelse return error.Oops;
    const a = try std.fmt.parseInt(T, input[0..i], 10);
    const b = try std.fmt.parseInt(T, input[i + 1 ..], 10);
    return .{ a, b };
}

const ArithmeticSumStep = enum { add, remove_duplicates };

fn arithmeticSum(
    patterns: []const Pattern,
    start: u64,
    end: u64,
    sum_step: ArithmeticSumStep,
    debug_context: DebugContext,
) !u64 {
    var result: u64 = 0;
    for (patterns) |p| {
        const lower = @max(
            try nextMultipleOf(u64, start, p.step),
            p.start,
        );
        const upper = @min(end, p.end);

        // This can be calculated with math, but it's sooo much faster than
        // the previous implementation that it's fine to get that debug info
        // here.
        var cur = lower;
        while (cur <= upper) : (cur += p.step) {
            result += cur;
            switch (sum_step) {
                .add => try debug_context.addFoundNumber(cur),
                .remove_duplicates => try debug_context.removeDuplicate(cur),
            }
        }
    }
    return result;
}

fn nextMultipleOf(comptime T: type, num: T, mult: T) !T {
    return try std.math.divCeil(T, num, mult) * mult;
}

const Pattern = struct {
    step: u64,
    start: u64,
    end: u64,

    /// Creates a Pattern with the total number of digits in the range number
    /// and the length of repeating blocks (size).
    fn init(digit: u8, size: u8) Pattern {
        const step = Pattern.calcStep(digit, size);
        const start = Pattern.calcStart(size, step);
        const end = Pattern.calcEnd(size, step);
        return .{
            .step = step,
            .start = start,
            .end = end,
        };
    }

    /// Calculates the common difference (step) for the arithmetic progression.
    /// Examples:
    /// 2,1 => 11, for 11, 22, 33, 44, ...
    /// 4,2 => 101, for 1010, 1111, 1212, 1313, ...
    fn calcStep(digit: u8, size: u8) u64 {
        const d = std.math.pow(u64, 10, digit) - 1;
        const s = std.math.pow(u64, 10, size) - 1;
        return d / s;
    }

    fn calcStart(size: u8, step: u64) u64 {
        const s = std.math.pow(u64, 10, size - 1);
        return step * s;
    }

    fn calcEnd(size: u8, step: u64) u64 {
        const s = std.math.pow(u64, 10, size) - 1;
        return step * s;
    }
};

test "day 2 - part 1" {
    const test_data = [_]struct {
        input: []const u8,
        invalid_ids: []const u64,
    }{
        .{
            .input = "11-22",
            .invalid_ids = &[_]u64{ 11, 22 },
        },
        .{
            .input = "95-115",
            .invalid_ids = &[_]u64{99},
        },
        .{
            .input = "998-1012",
            .invalid_ids = &[_]u64{1010},
        },
        .{
            .input = "1188511880-1188511890",
            .invalid_ids = &[_]u64{1188511885},
        },
        .{
            .input = "222220-222224",
            .invalid_ids = &[_]u64{222222},
        },
        .{
            .input = "1698522-1698528",
            .invalid_ids = &[_]u64{},
        },
        .{
            .input = "446443-446449",
            .invalid_ids = &[_]u64{446446},
        },
        .{
            .input = "38593856-38593862",
            .invalid_ids = &[_]u64{38593859},
        },
        .{
            .input = "565653-565659",
            .invalid_ids = &[_]u64{},
        },
        .{
            .input = "824824821-824824827",
            .invalid_ids = &[_]u64{},
        },
        .{
            .input = "2121212118-2121212124",
            .invalid_ids = &[_]u64{},
        },
    };

    var sum: u64 = 0;

    const alloc = std.testing.allocator;
    var list: std.ArrayList(u64) = try .initCapacity(alloc, 16);
    defer list.deinit(alloc);

    for (test_data, 0..) |data, i| {
        list.clearRetainingCapacity();

        var iterable = aoc.SliceStructIterable(
            @TypeOf(data),
            "input",
        ).init(test_data[i .. i + 1]);
        var it: aoc.InputIterator = .initFromIterator(iterable.iterator());

        sum += try processPattern(
            &it,
            &part_1_patterns,
            part_1_patterns[0..0], // Empty, no exclusions
            .initList(&list),
        );

        try std.testing.expectEqualSlices(
            u64,
            data.invalid_ids,
            list.items,
        );
    }

    try std.testing.expectEqual(1227775554, sum);
}

test "day 2 - part 2" {
    const test_data = [_]struct {
        input: []const u8,
        invalid_ids: []const u64,
    }{
        .{
            .input = "11-22",
            .invalid_ids = &[_]u64{ 11, 22 },
        },
        .{
            .input = "95-115",
            .invalid_ids = &[_]u64{ 99, 111 },
        },
        .{
            .input = "998-1012",
            .invalid_ids = &[_]u64{ 999, 1010 },
        },
        .{
            .input = "1188511880-1188511890",
            .invalid_ids = &[_]u64{1188511885},
        },
        .{
            .input = "222220-222224",
            .invalid_ids = &[_]u64{222222},
        },
        .{
            .input = "1698522-1698528",
            .invalid_ids = &[_]u64{},
        },
        .{
            .input = "446443-446449",
            .invalid_ids = &[_]u64{446446},
        },
        .{
            .input = "38593856-38593862",
            .invalid_ids = &[_]u64{38593859},
        },
        .{
            .input = "565653-565659",
            .invalid_ids = &[_]u64{565656},
        },
        .{
            .input = "824824821-824824827",
            .invalid_ids = &[_]u64{824824824},
        },
        .{
            .input = "2121212118-2121212124",
            .invalid_ids = &[_]u64{2121212121},
        },
    };

    var sum: u64 = 0;

    const alloc = std.testing.allocator;
    var list: std.ArrayList(u64) = try .initCapacity(alloc, 16);
    defer list.deinit(alloc);

    for (test_data, 0..) |data, i| {
        list.clearRetainingCapacity();

        var iterable = aoc.SliceStructIterable(
            @TypeOf(data),
            "input",
        ).init(test_data[i .. i + 1]);
        var it: aoc.InputIterator = .initFromIterator(iterable.iterator());

        sum += try processPattern(
            &it,
            &part_2_patterns,
            &part_2_double_counted_patterns,
            .initList(&list),
        );

        try std.testing.expectEqualSlices(
            u64,
            data.invalid_ids,
            list.items,
        );
    }

    try std.testing.expectEqual(4174379265, sum);
}
