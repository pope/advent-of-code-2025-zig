const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day7-input");
    defer setup.deinit();

    var it = setup.lineIterator();
    var arena = std.heap.ArenaAllocator.init(setup.allocator());
    defer arena.deinit();

    _, const p1a = try part1Answer(&arena, &it);
    std.debug.print("07.1: Splits = {}\n", .{p1a});

    try setup.reset();
    _ = arena.reset(.retain_capacity);
    const p2a = try part2Answer(&arena, &it);
    std.debug.print("07.2: Timelines = {}\n", .{p2a});
}

const Tile = enum {
    empty,
    start,
    splitter,
    beam,
};

fn part1Answer(
    arena: *std.heap.ArenaAllocator,
    it: *aoc.LineIterator,
) !struct {
    []const []const Tile,
    u64,
} {
    const data = try parseInput(arena, it);

    var tmp_buf = try arena.allocator().alloc(Tile, data[0].len);
    @memset(tmp_buf, .empty);

    var splits: u64 = 0;
    var prev = data[0];
    for (data) |row| {
        for (row, prev, 0..) |tile, p_tile, i| {
            switch (tile) {
                .empty, .beam => {},
                .start => tmp_buf[i] = .beam,
                .splitter => if (p_tile == .beam) {
                    std.debug.assert(i > 0 and i < tmp_buf.len - 1);

                    splits += 1;
                    tmp_buf[i - 1] = .beam; // left
                    tmp_buf[i] = .empty; // cur
                    tmp_buf[i + 1] = .beam; // right
                },
            }
        }
        for (row, tmp_buf) |*tile, b_tile| {
            if (tile.* == .empty and b_tile == .beam) tile.* = .beam;
        }
        prev = row;
    }

    return .{ data, splits };
}

fn part2Answer(
    arena: *std.heap.ArenaAllocator,
    it: *aoc.LineIterator,
) !u64 {
    const data = try parseInput(arena, it);

    const TimelineCounter = struct {
        tile: Tile,
        count: u64,
    };
    var tmp_buf = try arena.allocator().alloc(
        TimelineCounter,
        data[0].len,
    );
    for (tmp_buf) |*b| b.* = .{ .tile = .empty, .count = 0 };

    var prev = data[0];
    for (data) |row| {
        for (row, prev, 0..) |tile, p_tile, i| {
            switch (tile) {
                .empty, .beam => {},
                .start => tmp_buf[i] = .{ .tile = .beam, .count = 1 },
                .splitter => if (p_tile == .beam) {
                    tmp_buf[i - 1].tile = .beam;
                    tmp_buf[i - 1].count += tmp_buf[i].count;
                    tmp_buf[i + 1].tile = .beam;
                    tmp_buf[i + 1].count += tmp_buf[i].count;

                    tmp_buf[i] = .{ .tile = .empty, .count = 0 };
                },
            }
        }
        for (row, tmp_buf) |*tile, b_tile| {
            if (tile.* == .empty and b_tile.tile == .beam) tile.* = .beam;
        }
        prev = row;
    }

    var timelines: u64 = 0;
    for (tmp_buf) |b| timelines += b.count;
    return timelines;
}

fn parseInput(arena: *std.heap.ArenaAllocator, it: *aoc.LineIterator) ![][]Tile {
    const alloc = arena.allocator();

    const line_len = blk: {
        if (try it.peek()) |l| {
            if (l.len == 0) return error.Oops;
            break :blk l.len;
        }
        return error.Oops;
    };

    var data: std.ArrayList([]Tile) = .empty;
    while (try it.next()) |line| {
        if (line_len != line.len) return error.Oops;
        var row: std.ArrayList(Tile) = try .initCapacity(alloc, line_len);
        for (line) |c| {
            try row.appendBounded(switch (c) {
                '.' => .empty,
                'S' => .start,
                '^' => .splitter,
                else => return error.Oops,
            });
        }
        try data.append(alloc, try row.toOwnedSlice(alloc));
    }
    return data.toOwnedSlice(alloc);
}

fn tilesToStr(alloc: std.mem.Allocator, tiles: []const []const Tile) ![]u8 {
    if (tiles.len == 0) return error.Oops;

    var str: std.ArrayList(u8) = try .initCapacity(
        alloc,
        tiles.len * (tiles[0].len + 1),
    );
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

test "day 7 - part 1" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var it = aoc.LineIterator.initFromBuffer(test_input);

    const data, const splits = try part1Answer(&arena, &it);

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
    const actual = try tilesToStr(
        std.testing.allocator,
        data,
    );
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
    try std.testing.expectEqual(21, splits);
}

test "day 7 - part 2" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var it = aoc.LineIterator.initFromBuffer(test_input);

    const timelines = try part2Answer(&arena, &it);
    try std.testing.expectEqual(40, timelines);
}
