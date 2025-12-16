const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day7-input");
    defer setup.deinit();

    var it = setup.lineIterator();
    std.debug.print(
        "07.1: Splits = {}\n",
        .{try part1Answer(setup.allocator(), &it)},
    );

    std.debug.print("07.1: TODO\n", .{});
}

const Tile = enum {
    empty,
    start,
    splitter,
    beam,
};

fn part1Answer(alloc: std.mem.Allocator, it: *aoc.LineIterator) !u64 {
    const line_len = blk: {
        if (try it.peek()) |l| {
            if (l.len == 0) return error.Oops;
            break :blk l.len;
        }
        return error.Oops;
    };

    var prev = try alloc.alloc(Tile, line_len);
    defer alloc.free(prev);

    var cur = try alloc.alloc(Tile, line_len);
    defer alloc.free(cur);

    var tmp = try alloc.alloc(Tile, line_len);
    defer alloc.free(tmp);
    @memset(tmp, .empty);

    var splits: u64 = 0;
    while (try it.next()) |line| {
        for (line, cur, prev, 0..) |char, *c, p, i| {
            c.* = switch (char) {
                '.' => .empty,
                'S' => blk: {
                    tmp[i] = .beam;
                    break :blk .start;
                },
                '^' => blk: {
                    if (p == .beam) {
                        splits += 1;
                        tmp[i] = .empty;
                        if (i > 0) tmp[i - 1] = .beam;
                        if (i < tmp.len - 1) tmp[i + 1] = .beam;
                    }
                    break :blk .splitter;
                },
                else => return error.Oops,
            };
        }
        for (cur, tmp) |*t, b| {
            if (t.* == .empty and b == .beam) t.* = .beam;
        }

        const tmp_swp = cur;
        cur = prev;
        prev = tmp_swp;
    }
    return splits;
}

fn testTilesToStr(alloc: std.mem.Allocator, tiles: *[16][15]Tile) ![]u8 {
    var str: std.ArrayList(u8) = try .initCapacity(alloc, 16 * 16);
    defer str.deinit(alloc);

    for (tiles) |row| {
        for (row) |t| {
            const c: u8 = switch (t) {
                .empty => '.',
                .start => 'S',
                .splitter => '^',
                .beam => '|',
            };
            try str.appendBounded(c);
        }
        try str.appendBounded('\n');
    }
    _ = str.pop();
    return str.toOwnedSlice(alloc);
}

const test_input =
    \\.......S.......
    \\...............
    \\.......^.......
    \\...............
    \\......^.^......
    \\...............
    \\.....^.^.^.....
    \\...............
    \\....^.^...^....
    \\...............
    \\...^.^...^.^...
    \\...............
    \\..^...^.....^..
    \\...............
    \\.^.^.^.^.^...^.
    \\...............
;

test "day 7 - part 1.0" {
    var output: [16][15]Tile = undefined;
    var buf: [15]Tile = @splat(.empty);

    var it = aoc.LineIterator.initFromBuffer(test_input);
    var idx: usize = 0;
    var splits: u8 = 0;
    while (try it.next()) |line| : (idx += 1) {
        const tiles = &output[idx];
        for (line, tiles, 0..) |c, *t, cur| {
            t.* = switch (c) {
                '.' => .empty,
                'S' => blk: {
                    buf[cur] = .beam;
                    break :blk .start;
                },
                '^' => blk: {
                    if (idx > 0 and output[idx - 1][cur] == .beam) {
                        splits += 1;
                        buf[cur] = .empty;
                        if (cur > 0) buf[cur - 1] = .beam;
                        if (cur < buf.len - 1) buf[cur + 1] = .beam;
                    }
                    break :blk .splitter;
                },
                else => return error.Oops,
            };
        }
        for (tiles, &buf) |*t, b| {
            if (t.* == .empty and b == .beam) t.* = .beam;
        }
    }

    const expected =
        \\.......S.......
        \\.......|.......
        \\......|^|......
        \\......|.|......
        \\.....|^|^|.....
        \\.....|.|.|.....
        \\....|^|^|^|....
        \\....|.|.|.|....
        \\...|^|^|||^|...
        \\...|.|.|||.|...
        \\..|^|^|||^|^|..
        \\..|.|.|||.|.|..
        \\.|^|||^||.||^|.
        \\.|.|||.||.||.|.
        \\|^|^|^|^|^|||^|
        \\|.|.|.|.|.|||.|
    ;
    const actual = try testTilesToStr(
        std.testing.allocator,
        &output,
    );
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
    try std.testing.expectEqual(21, splits);
}

test "day 7 - part 1.1" {
    var it = aoc.LineIterator.initFromBuffer(test_input);
    try std.testing.expectEqual(
        21,
        try part1Answer(std.testing.allocator, &it),
    );
}
