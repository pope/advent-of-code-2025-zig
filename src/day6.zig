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
}

const Operator = enum { add, multiply };

fn part1ProcessInput(
    comptime T: type,
    it: *aoc.LineIterator,
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

test "day 6 - part 2" {
    const input =
        \\123 328  51 64 
        \\ 45 64  387 23 
        \\  6 98  215 314
        \\*   +   *   +  
    ;

    var it = aoc.LineIterator.initFromBuffer(input);
    const total = try part1ProcessInput(
        u16,
        &it,
        std.testing.allocator,
    );

    try std.testing.expectEqual(4277556, total);
}
