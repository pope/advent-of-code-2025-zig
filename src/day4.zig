const std = @import("std");
const aoc = @import("aoc");

const padding = 2;

pub fn main() !void {
    var setup: aoc.Setup = try .init("day4-input");
    defer setup.deinit();
    var it = setup.lineIterator();

    try part1(setup.allocator(), &it);

    try setup.reset();
    try part2(setup.allocator(), &it);
}

fn part1(alloc: std.mem.Allocator, it: *aoc.InputIterator) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const len = (try it.peek()).?.len;

    var input: std.ArrayList([]u8) = .empty;
    try inputListAddPaddingRow(&arena, &input, len);
    while (try it.next()) |row| {
        std.debug.assert(row.len == len);
        try inputListAddRow(&arena, &input, row);
    }
    try inputListAddPaddingRow(&arena, &input, len);

    const output = try createOutputList(&arena, input.items);
    processRolls(
        input.items,
        output.items,
        std.simd.suggestVectorLength(u8) orelse 8,
    );

    const count = countMovableRolls(output.items);

    std.debug.print("04.1: Rolls = {d}\n", .{count});
}

fn part2(alloc: std.mem.Allocator, it: *aoc.InputIterator) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const len = (try it.peek()).?.len;

    var input: std.ArrayList([]u8) = .empty;
    try inputListAddPaddingRow(&arena, &input, len);
    while (try it.next()) |row| {
        std.debug.assert(row.len == len);
        try inputListAddRow(&arena, &input, row);
    }
    try inputListAddPaddingRow(&arena, &input, len);

    var output = try createOutputList(&arena, input.items);

    var count: u64 = 0;
    while (true) {
        processRolls(
            input.items,
            output.items,
            std.simd.suggestVectorLength(u8) orelse 8,
        );

        const c = countMovableRolls(output.items);
        if (c == 0) break;
        count += c;

        input, output = switchAndReset(input, output);
    }

    std.debug.print("04.2: Rolls = {d}\n", .{count});
}

inline fn inputListAddPaddingRow(
    arena: *std.heap.ArenaAllocator,
    list: *std.ArrayList([]u8),
    len: usize,
) !void {
    const buf = try arena.allocator().alloc(u8, len + padding);
    try list.append(arena.allocator(), buf);
    @memset(buf, 0);
}

inline fn inputListAddRow(
    arena: *std.heap.ArenaAllocator,
    list: *std.ArrayList([]u8),
    row: []const u8,
) !void {
    const buf = try arena.allocator().alloc(u8, row.len + padding);
    try list.append(arena.allocator(), buf);
    buf[0] = 0;
    for (buf[1 .. buf.len - 1], row) |*b, r| {
        b.* = switch (r) {
            '.' => 0,
            '@' => 1,
            else => return error.Oops,
        };
    }
    buf[buf.len - 1] = 0;
}

inline fn createOutputList(
    arena: *std.heap.ArenaAllocator,
    list: []const []const u8,
) !std.ArrayList([]u8) {
    var output: std.ArrayList([]u8) = try .initCapacity(
        arena.allocator(),
        list.len,
    );
    for (list) |buf| {
        const new_buf = try arena.allocator().alloc(u8, buf.len);
        @memset(new_buf, 0);
        try output.appendBounded(new_buf);
    }
    return output;
}

fn processRolls(
    input: []const []const u8,
    output: [][]u8,
    vec_len: comptime_int,
) void {
    const VecU8 = @Vector(vec_len, u8);

    for (1..input.len - 1) |i| {
        var res_line = output[i];
        const len = res_line.len - padding;

        var j: usize = 0;
        while (j + vec_len <= len) : (j += vec_len) {
            var vo = @as(VecU8, input[i][j + 0 ..][0..vec_len].*);
            vo += @as(VecU8, input[i][j + 1 ..][0..vec_len].*);
            vo += @as(VecU8, input[i][j + 2 ..][0..vec_len].*);

            vo += @as(VecU8, input[i - 1][j + 0 ..][0..vec_len].*);
            vo += @as(VecU8, input[i - 1][j + 1 ..][0..vec_len].*);
            vo += @as(VecU8, input[i - 1][j + 2 ..][0..vec_len].*);

            vo += @as(VecU8, input[i + 1][j + 0 ..][0..vec_len].*);
            vo += @as(VecU8, input[i + 1][j + 1 ..][0..vec_len].*);
            vo += @as(VecU8, input[i + 1][j + 2 ..][0..vec_len].*);

            // Multiple so that values that were 0, are 0 again
            vo *= @as(VecU8, input[i][j + 1 ..][0..vec_len].*);

            res_line[j + 1 ..][0..vec_len].* = vo;
        }

        while (j < len) : (j += 1) {
            var res = input[i][j + 1];
            if (res == 0) continue;

            res += input[i][j + 0];
            res += input[i][j + 2];

            res += input[i - 1][j + 0];
            res += input[i - 1][j + 1];
            res += input[i - 1][j + 2];

            res += input[i + 1][j + 0];
            res += input[i + 1][j + 1];
            res += input[i + 1][j + 2];

            res_line[j + 1] = res;
        }
    }
}

fn outputToStr(alloc: std.mem.Allocator, output: []const []const u8) ![]u8 {
    var str: std.ArrayList(u8) = try .initCapacity(alloc, 1 << 7);
    defer str.deinit(alloc);

    for (output[1 .. output.len - 1]) |line| {
        for (line[1 .. line.len - 1]) |d| {
            const c: u8 = switch (d) {
                0 => '.',
                1, 2, 3, 4 => 'x',
                else => '@',
            };
            try str.appendBounded(c);
        }
        try str.appendBounded('\n');
    }
    _ = str.pop();
    return str.toOwnedSlice(alloc);
}

fn countMovableRolls(output: []const []const u8) u64 {
    var count: u16 = 0;
    for (output) |row| {
        for (row) |d| {
            if (d > 0 and d < 5) count += 1;
        }
    }
    return count;
}

inline fn switchAndReset(
    input: std.ArrayList([]u8),
    output: std.ArrayList([]u8),
) struct {
    std.ArrayList([]u8),
    std.ArrayList([]u8),
} {
    for (input.items) |row| {
        @memset(row, 0);
    }
    for (output.items) |row| {
        for (row) |*c| {
            c.* = switch (c.*) {
                0, 1, 2, 3, 4 => 0,
                else => 1,
            };
        }
    }
    return .{ output, input };
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
    var input: std.ArrayList([]u8) = try .initCapacity(
        arena.allocator(),
        14 + padding,
    );
    {
        var it: aoc.InputIterator = .initFromBuffer(data, '\n');

        const len = (try it.peek()).?.len;
        try inputListAddPaddingRow(&arena, &input, len);
        while (try it.next()) |line| {
            std.debug.assert(line.len == len);
            try inputListAddRow(&arena, &input, line);
        }
        try inputListAddPaddingRow(&arena, &input, len);
    }

    // Process the list.
    const output = try createOutputList(&arena, input.items);
    processRolls(
        input.items,
        output.items,
        4, // So that both loops run more than once
    );

    // Make a string for the output
    const str = try outputToStr(arena.allocator(), output.items);

    // Answer
    const count: u64 = countMovableRolls(output.items);

    try std.testing.expectEqualStrings(expected, str);
    try std.testing.expectEqual(13, count);
}

test "day 4 - part 2" {
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
    const expected = [_]struct {
        data: []const u8,
        count: u64,
    }{
        .{
            .data =
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
            ,
            .count = 13,
        },
        .{
            .data =
            \\.......x..
            \\.@@.x.x.@x
            \\x@@@@...@@
            \\x.@@@@..x.
            \\.@.@@@@.x.
            \\.x@@@@@@.x
            \\.x.@.@.@@@
            \\..@@@.@@@@
            \\.x@@@@@@@.
            \\....@@@...
            ,
            .count = 12,
        },
        .{
            .data =
            \\..........
            \\.x@.....x.
            \\.@@@@...xx
            \\..@@@@....
            \\.x.@@@@...
            \\..@@@@@@..
            \\...@.@.@@x
            \\..@@@.@@@@
            \\..x@@@@@@.
            \\....@@@...
            ,
            .count = 7,
        },
        .{
            .data =
            \\..........
            \\..x.......
            \\.x@@@.....
            \\..@@@@....
            \\...@@@@...
            \\..x@@@@@..
            \\...@.@.@@.
            \\..x@@.@@@x
            \\...@@@@@@.
            \\....@@@...
            ,
            .count = 5,
        },
        .{
            .data =
            \\..........
            \\..........
            \\..x@@.....
            \\..@@@@....
            \\...@@@@...
            \\...@@@@@..
            \\...@.@.@@.
            \\...@@.@@@.
            \\...@@@@@x.
            \\....@@@...
            ,
            .count = 2,
        },
        .{
            .data =
            \\..........
            \\..........
            \\...@@.....
            \\..x@@@....
            \\...@@@@...
            \\...@@@@@..
            \\...@.@.@@.
            \\...@@.@@@.
            \\...@@@@@..
            \\....@@@...
            ,
            .count = 1,
        },
        .{
            .data =
            \\..........
            \\..........
            \\...x@.....
            \\...@@@....
            \\...@@@@...
            \\...@@@@@..
            \\...@.@.@@.
            \\...@@.@@@.
            \\...@@@@@..
            \\....@@@...
            ,
            .count = 1,
        },
        .{
            .data =
            \\..........
            \\..........
            \\....x.....
            \\...@@@....
            \\...@@@@...
            \\...@@@@@..
            \\...@.@.@@.
            \\...@@.@@@.
            \\...@@@@@..
            \\....@@@...
            ,
            .count = 1,
        },
        .{
            .data =
            \\..........
            \\..........
            \\..........
            \\...x@@....
            \\...@@@@...
            \\...@@@@@..
            \\...@.@.@@.
            \\...@@.@@@.
            \\...@@@@@..
            \\....@@@...
            ,
            .count = 1,
        },
        .{
            .data =
            \\..........
            \\..........
            \\..........
            \\....@@....
            \\...@@@@...
            \\...@@@@@..
            \\...@.@.@@.
            \\...@@.@@@.
            \\...@@@@@..
            \\....@@@...
            ,
            .count = 0,
        },
    };
    const vec_len = 8;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var input: std.ArrayList([]u8) = try .initCapacity(
        arena.allocator(),
        14 + padding,
    );
    {
        var it: aoc.InputIterator = .initFromBuffer(data, '\n');
        const len = (try it.peek()).?.len;
        try inputListAddPaddingRow(&arena, &input, len);
        while (try it.next()) |line| {
            std.debug.assert(line.len == len);
            try inputListAddRow(&arena, &input, line);
        }
        try inputListAddPaddingRow(&arena, &input, len);
    }

    var output = try createOutputList(&arena, input.items);

    var count: u64 = 0;

    for (expected) |e| {
        processRolls(
            input.items,
            output.items,
            vec_len,
        );
        const actual = try outputToStr(
            arena.allocator(),
            output.items,
        );
        defer arena.allocator().free(actual);

        const actual_count = countMovableRolls(output.items);

        try std.testing.expectEqual(e.count, actual_count);
        try std.testing.expectEqualStrings(e.data, actual);

        count += actual_count;

        input, output = switchAndReset(input, output);
    }

    try std.testing.expectEqual(43, count);
}
