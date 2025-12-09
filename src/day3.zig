const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day3-input");
    defer setup.deinit();

    var reader = setup.reader();
    try part1(&reader.interface);

    try reader.seekTo(0);
    try part2(setup.allocator(), &reader.interface);
}

fn part1(reader: *std.io.Reader) !void {
    var sum: u16 = 0;
    while (try reader.takeDelimiter('\n')) |input| {
        sum += part1Process(input);
    }
    std.debug.print("03.1: Joltage = {}\n", .{sum});
}

fn part1Process(input: []const u8) u16 {
    const a = std.mem.indexOfMax(u8, input[0 .. input.len - 1]);
    const b = std.mem.indexOfMax(u8, input[a + 1 ..]);
    const tens = (input[a] - 0x30) * 10;
    const ones = input[b + (a + 1)] - 0x30;
    return tens + ones;
}

fn part2(alloc: std.mem.Allocator, reader: *std.io.Reader) !void {
    var sum: u64 = 0;
    while (try reader.takeDelimiter('\n')) |input| {
        sum += try part2Process(alloc, input);
    }
    std.debug.print("03.1: Joltage = {}\n", .{sum});
}

fn part2Process(alloc: std.mem.Allocator, input: []const u8) !u64 {
    const JoltageNode = struct {
        data: u8 = 0,
        node: std.DoublyLinkedList.Node = .{},
    };

    const nodes = try alloc.alloc(JoltageNode, input.len);
    defer alloc.free(nodes);

    var list: std.DoublyLinkedList = .{};
    for (input, 0..) |c, i| {
        nodes[i].data = c - 0x30;
        list.append(&nodes[i].node);
    }
    var len = input.len;
    std.debug.assert(len >= 12);
    std.debug.assert(len == list.len());

    var process_it = list.first;
    while (process_it != null and process_it.?.next != null and len > 12) {
        const cur = process_it.?;
        const next = cur.next.?;

        const a = @as(
            *JoltageNode,
            @fieldParentPtr("node", cur),
        ).data;
        const b = @as(
            *JoltageNode,
            @fieldParentPtr("node", next),
        ).data;

        if (a < b) {
            len -= 1;
            list.remove(cur);
            process_it = next.prev orelse next;
        } else {
            process_it = next;
        }
    }

    // NOTE: After this step, there can be more than 12 items left. So when
    // doing the calculations below, only take the first 12.

    return blk: {
        var result: u64 = 0;
        var count: usize = 0;
        var result_it: ?*const std.DoublyLinkedList.Node = list.first;
        while (result_it) |node| : (result_it = node.next) {
            const j: *const JoltageNode = @fieldParentPtr(
                "node",
                node,
            );
            result = result * 10 + j.data;
            count += 1;

            if (count >= 12) break :blk result;
        }
        break :blk result;
    };
}

test "day 3 - part 1" {
    var sum: u16 = 0;
    const test_data = [_]struct {
        input: []const u8,
        expected: u8,
    }{
        .{ .input = "987654321111111", .expected = 98 },
        .{ .input = "811111111111119", .expected = 89 },
        .{ .input = "234234234234278", .expected = 78 },
        .{ .input = "818181911112111", .expected = 92 },
    };
    for (test_data) |data| {
        const value = part1Process(data.input);
        try std.testing.expectEqual(data.expected, value);

        sum += value;
    }

    try std.testing.expectEqual(357, sum);
}

test "day 3 - part 2" {
    var sum: u64 = 0;
    const test_data = [_]struct {
        input: []const u8,
        expected: u64,
    }{
        .{ .input = "987654321111111", .expected = 987654321111 },
        .{ .input = "811111111111119", .expected = 811111111119 },
        .{ .input = "234234234234278", .expected = 434234234278 },
        .{ .input = "818181911112111", .expected = 888911112111 },
    };
    for (test_data) |data| {
        const val = try part2Process(
            std.testing.allocator,
            data.input,
        );
        try std.testing.expectEqual(data.expected, val);
        sum += val;
    }
    try std.testing.expectEqual(3121910778619, sum);
}
