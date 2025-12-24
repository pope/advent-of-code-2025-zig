const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day6-input");
    defer setup.deinit();

    var it = setup.lineIterator();

    std.debug.print(
        "06.1: Total = {}\n",
        .{try part1ProcessInput(u16, &it, setup.allocator())},
    );

    try setup.reset();

    std.debug.print(
        "06.2: Total = {}\n",
        .{try part2ProcessInput(&it, setup.allocator())},
    );
}

const Operator = enum { add, multiply };

fn part1ProcessInput(
    comptime T: type,
    it: *aoc.InputIterator,
    alloc_in: std.mem.Allocator,
) !u64 {
    var arena = std.heap.ArenaAllocator.init(alloc_in);
    defer arena.deinit();
    const alloc = arena.allocator();

    var numbers: std.ArrayList([]const T) = .empty;

    // Process the first line
    const len = blk: {
        const line = try it.next() orelse return error.Oops;
        var tok_itr = std.mem.splitScalar(
            u8,
            line,
            ' ',
        );
        var cols: std.ArrayList(T) = .empty;
        while (tok_itr.next()) |tok| {
            if (tok.len == 0) continue;
            const num = try std.fmt.parseInt(T, tok, 10);
            try cols.append(alloc, num);
        }

        try numbers.append(alloc, cols.items);
        break :blk cols.items.len;
    };

    // Process the next non-operator lines
    while (true) {
        if (try it.peek()) |line| {
            if (line.len == 0) return error.Oops;
            switch (line[0]) {
                '*', '+' => break,
                else => {},
            }
        } else return error.Oops;

        const line = try it.next() orelse unreachable;
        var cols: std.ArrayList(T) = try .initCapacity(alloc, len);
        var tok_itr = std.mem.splitScalar(
            u8,
            line,
            ' ',
        );
        while (tok_itr.next()) |tok| {
            if (tok.len == 0) continue;
            const num = try std.fmt.parseInt(T, tok, 10);
            try cols.appendBounded(num);
        }

        if (cols.items.len != len) return error.Oops;
        try numbers.append(alloc, cols.items);
    }

    const operators = blk: {
        const line = try it.next() orelse return error.Oops;

        var ops: std.ArrayList(Operator) = try .initCapacity(alloc, len);
        var tok_itr = std.mem.splitScalar(
            u8,
            line,
            ' ',
        );
        while (tok_itr.next()) |tok| {
            if (tok.len == 0) continue;
            if (tok.len > 1) return error.Oops;
            try ops.appendBounded(switch (tok[0]) {
                '+' => .add,
                '*' => .multiply,
                else => return error.Oops,
            });
        }

        if (ops.items.len != len) return error.Oops;
        break :blk ops;
    };

    var total: u64 = 0;
    for (operators.items, 0..) |op, i| {
        switch (op) {
            .add => {
                for (numbers.items) |n| total += n[i];
            },
            .multiply => {
                var t: u64 = 1;
                for (numbers.items) |n| t *= n[i];
                total += t;
            },
        }
    }

    return total;
}

fn part2ProcessInput(
    it: *aoc.InputIterator,
    alloc_in: std.mem.Allocator,
) !u64 {
    var arena = std.heap.ArenaAllocator.init(alloc_in);
    defer arena.deinit();
    const alloc = arena.allocator();

    const NumCol = union(enum) {
        some: u4,
        none,
    };
    const OpCol = struct {
        op: Operator,
        size: u4,
    };

    var numbers: std.ArrayList([]const NumCol) = .empty;

    // Process the next non-operator lines
    while (true) {
        if (try it.peek()) |line| {
            if (line.len == 0) return error.Oops;
            switch (line[0]) {
                '*', '+' => break,
                else => {},
            }
        } else return error.Oops;

        const line = try it.next() orelse unreachable;
        // TODO(pope): @Vector?
        var cols: std.ArrayList(NumCol) = try .initCapacity(alloc, line.len);
        for (line) |c| {
            try cols.appendBounded(switch (c) {
                '0' => .{ .some = 0 },
                '1' => .{ .some = 1 },
                '2' => .{ .some = 2 },
                '3' => .{ .some = 3 },
                '4' => .{ .some = 4 },
                '5' => .{ .some = 5 },
                '6' => .{ .some = 6 },
                '7' => .{ .some = 7 },
                '8' => .{ .some = 8 },
                '9' => .{ .some = 9 },
                ' ' => .none,
                else => return error.Oops,
            });
        }
        try numbers.append(alloc, cols.items);
        if (cols.items.len != numbers.items[0].len) return error.Oops;
    }

    const operators = blk: {
        const line = try it.next() orelse return error.Oops;
        var ops: std.ArrayList(OpCol) = .empty;

        if (line.len != numbers.items[0].len) return error.Oops;

        var i: usize = 0;
        while (i < line.len) {
            const op: Operator = switch (line[i]) {
                '+' => .add,
                '*' => .multiply,
                else => return error.Oops,
            };
            var j: usize = i + 1;
            while (j < line.len and (line[j] != '+' and line[j] != '*')) {
                j += 1;
            }

            if (j - i > 5) return error.Oops;

            const size: u4 = @truncate(if (j == line.len) j - i else j - 1 - i);
            try ops.append(alloc, .{ .op = op, .size = size });

            i = j;
        }

        break :blk ops;
    };

    var total: u64 = 0;
    var i: usize = 0;
    for (operators.items) |op| {
        var buf: [4]u16 = @splat(0);
        for (0..op.size) |j| {
            for (numbers.items) |num| {
                switch (num[i + j]) {
                    .some => |v| buf[j] = (buf[j] * 10) + v,
                    .none => {},
                }
            }
        }

        switch (op.op) {
            .add => {
                for (buf) |n| total += n;
            },
            .multiply => {
                var t: u64 = 1;
                for (buf[0..op.size]) |n| t *= n;
                total += t;
            },
        }

        i += op.size + 1;
    }

    return total;
}

const test_input =
    \\123 328  51 64 
    \\ 45 64  387 23 
    \\  6 98  215 314
    \\*   +   *   +  
;

test "day 6 - part 1" {
    var it: aoc.InputIterator = .initFromBuffer(test_input, '\n');

    const total = try part1ProcessInput(
        u16,
        &it,
        std.testing.allocator,
    );

    try std.testing.expectEqual(4277556, total);
}

test "day 6 - part 2" {
    var it: aoc.InputIterator = .initFromBuffer(test_input, '\n');

    const total = try part2ProcessInput(
        &it,
        std.testing.allocator,
    );

    try std.testing.expectEqual(3263827, total);
}
