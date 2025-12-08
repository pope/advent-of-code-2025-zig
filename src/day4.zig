const std = @import("std");
const aoc = @import("aoc");

const padding = 2;

pub fn main() !void {
    var setup: aoc.Setup = try .init("day4-input");
    defer setup.deinit();

    var reader = setup.reader();
    try part1(setup.allocator(), &reader.interface);
}

fn part1(alloc: std.mem.Allocator, reader: *std.io.Reader) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const len = (try reader.peekDelimiterExclusive('\n')).len;

    var list: std.ArrayList([]u8) = .empty;
    try part1ListAddPaddingRow(&arena, &list, len);
    while (try reader.takeDelimiter('\n')) |input| {
        std.debug.assert(input.len == len);
        try part1ListAddRow(&arena, &list, input);
    }
    try part1ListAddPaddingRow(&arena, &list, len);

    const output = try part1ProcessList(
        &arena,
        list.items,
        std.simd.suggestVectorLength(u8) orelse 8,
    );

    var count: u16 = 0;
    for (output.items) |line| {
        for (line) |d| {
            if (d > 0 and d < 5) count += 1;
        }
    }

    std.debug.print("04.1: Rolls = {d}\n", .{count});
}

inline fn part1ListAddPaddingRow(
    arena: *std.heap.ArenaAllocator,
    list: *std.ArrayList([]u8),
    len: usize,
) !void {
    const buf = try arena.allocator().alloc(u8, len + padding);
    try list.append(arena.allocator(), buf);
    @memset(buf, 0);
}

inline fn part1ListAddRow(
    arena: *std.heap.ArenaAllocator,
    list: *std.ArrayList([]u8),
    row: []const u8,
) !void {
    const buf = try arena.allocator().alloc(u8, row.len + padding);
    try list.append(arena.allocator(), buf);
    buf[0] = 0;
    buf[row.len + 1] = 0;
    for (0..row.len) |i| {
        buf[i + 1] = switch (row[i]) {
            '.' => 0,
            '@' => 1,
            else => return error.Oops,
        };
    }
}

fn part1ProcessList(
    arena: *std.heap.ArenaAllocator,
    list: []const []const u8,
    vec_len: comptime_int,
) !std.ArrayList([]u8) {
    var output: std.ArrayList([]u8) = try .initCapacity(
        arena.allocator(),
        list.len - padding,
    );
    for (list[1 .. list.len - 1]) |*buf| {
        const new_buf = try arena.allocator().alloc(
            u8,
            buf.len - padding,
        );
        @memset(new_buf, 0);
        output.appendAssumeCapacity(new_buf);
    }
    const VecU8 = @Vector(vec_len, u8);

    for (1..list.len - 1) |i| {
        var res_line = output.items[i - 1];
        const len = res_line.len;

        var j: usize = 0;
        while (j + vec_len <= len) : (j += vec_len) {
            var vo = @as(VecU8, list[i][j + 0 ..][0..vec_len].*);
            vo += @as(VecU8, list[i][j + 1 ..][0..vec_len].*);
            vo += @as(VecU8, list[i][j + 2 ..][0..vec_len].*);

            vo += @as(VecU8, list[i - 1][j + 0 ..][0..vec_len].*);
            vo += @as(VecU8, list[i - 1][j + 1 ..][0..vec_len].*);
            vo += @as(VecU8, list[i - 1][j + 2 ..][0..vec_len].*);

            vo += @as(VecU8, list[i + 1][j + 0 ..][0..vec_len].*);
            vo += @as(VecU8, list[i + 1][j + 1 ..][0..vec_len].*);
            vo += @as(VecU8, list[i + 1][j + 2 ..][0..vec_len].*);

            // Multiple so that values that were 0, are 0 again
            vo *= @as(VecU8, list[i][j + 1 ..][0..vec_len].*);

            res_line[j..][0..vec_len].* = vo;
        }

        while (j < len) : (j += 1) {
            var res = list[i][j + 1];
            if (res == 0) continue;

            res += list[i][j + 0];
            res += list[i][j + 2];

            res += list[i - 1][j + 0];
            res += list[i - 1][j + 1];
            res += list[i - 1][j + 2];

            res += list[i + 1][j + 0];
            res += list[i + 1][j + 1];
            res += list[i + 1][j + 2];

            res_line[j] = res;
        }
    }
    return output;
}

test "day 4 - part 1" {
    const data =
        \\..@@.@@@@.
        \\@@@.@.@.@@
        \\@@@@@.@.@@
        \\@.@@@@..@.
        \\@@.@@@@.@@
        \\.@@@@@@@.@
        \\.@.@.@.@@@
        \\@.@@@.@@@@
        \\.@@@@@@@@.
        \\@.@.@@@.@.
    ;
    const expected =
        \\..xx.xx@x.
        \\x@@.@.@.@@
        \\@@@@@.x.@@
        \\@.@@@@..@.
        \\x@.@@@@.@x
        \\.@@@@@@@.@
        \\.@.@.@.@@@
        \\x.@@@.@@@@
        \\.@@@@@@@@.
        \\x.x.@@@.x.
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // Create the list of data.
    //
    // There is padding of zeros for the start, end and left and right. This
    // is to reduce any if checks as we start searching for things above,
    // below, and left and right.
    var list: std.ArrayList([]u8) = try .initCapacity(
        arena.allocator(),
        14 + padding,
    );
    {
        var it = std.mem.splitScalar(
            u8,
            data,
            '\n',
        );
        const len = it.peek().?.len;
        try part1ListAddPaddingRow(&arena, &list, len);
        while (it.next()) |line| {
            std.debug.assert(line.len == len);
            try part1ListAddRow(&arena, &list, line);
        }
        try part1ListAddPaddingRow(&arena, &list, len);
    }

    // Process the list.
    const output = try part1ProcessList(
        &arena,
        list.items,
        4, // So that both loops run more than once
    );

    // Make a string for the output
    var str: std.ArrayList(u8) = .empty;
    for (output.items) |line| {
        for (line) |d| {
            const c: u8 = switch (d) {
                0 => '.',
                1, 2, 3, 4 => 'x',
                else => '@',
            };
            try str.append(arena.allocator(), c);
        }
        try str.append(arena.allocator(), '\n');
    }
    _ = str.pop();

    // Answer
    var count: u16 = 0;
    for (output.items) |line| {
        for (line) |d| {
            if (d > 0 and d < 5) count += 1;
        }
    }

    try std.testing.expectEqualStrings(expected, str.items);
    try std.testing.expectEqual(13, count);
}
