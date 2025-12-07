const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
    const alloc = gpa.allocator();

    var file_buffer: [4096]u8 = undefined;
    const f = try aoc.loadInput(alloc, "day3-input");
    defer f.close();
    var reader = f.reader(&file_buffer);

    try part1(&reader.interface);
}

fn part1(reader: *std.io.Reader) !void {
    var sum: u16 = 0;
    while (try reader.takeDelimiter('\n')) |input| {
        const a = std.mem.indexOfMax(u8, input[0 .. input.len - 1]);
        const b = std.mem.indexOfMax(u8, input[a + 1 ..]);
        const tens = (input[a] - 0x30) * 10;
        const ones = input[b + (a + 1)] - 0x30;
        sum += tens + ones;
    }
    std.debug.print("03.1: Joltage = {}\n", .{sum});
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
        const a = std.mem.indexOfMax(u8, data.input[0 .. data.input.len - 1]);
        const b = std.mem.indexOfMax(u8, data.input[a + 1 ..]);
        const tens = (data.input[a] - 0x30) * 10;
        const ones = data.input[b + (a + 1)] - 0x30;

        try std.testing.expectEqual(data.expected, tens + ones);

        sum += tens + ones;
    }

    try std.testing.expectEqual(357, sum);
}
