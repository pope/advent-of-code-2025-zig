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

    const f = try aoc.loadInput(alloc, "day2-input");
    defer f.close();
    var file_buffer: [4096]u8 = undefined;
    var reader = f.reader(&file_buffer);

    var sum: u64 = 0;
    while (try reader.interface.takeDelimiter(',')) |input| {
        const i = std.mem.indexOf(u8, input, "-") orelse return error.Oops;
        const a = try std.fmt.parseInt(u64, input[0..i], 10);
        const b = try std.fmt.parseInt(u64, input[i + 1 ..], 10);

        var buf: [32]u8 = undefined;
        var id = a;
        while (id <= b) : (id += 1) {
            const id_str = try std.fmt.bufPrint(&buf, "{d}", .{id});
            if (id_str.len % 2 != 0) continue;
            if (std.mem.eql(u8, id_str[0 .. id_str.len / 2], id_str[id_str.len / 2 ..])) {
                sum += id;
            }
        }
    }

    std.debug.print("02.1: Password = {d}\n", .{sum});
}

test "day 2 - part 1" {
    const alloc = std.testing.allocator;
    const test_data = [_]struct {
        input: []const u8,
        invalid_ids: []const u32,
    }{
        .{ .input = "11-22", .invalid_ids = &[_]u32{ 11, 22 } },
        .{ .input = "95-115", .invalid_ids = &[_]u32{99} },
        .{ .input = "998-1012", .invalid_ids = &[_]u32{1010} },
        .{ .input = "1188511880-1188511890", .invalid_ids = &[_]u32{1188511885} },
        .{ .input = "222220-222224", .invalid_ids = &[_]u32{222222} },
        .{ .input = "1698522-1698528", .invalid_ids = &[_]u32{} },
        .{ .input = "446443-446449", .invalid_ids = &[_]u32{446446} },
        .{ .input = "38593856-38593862", .invalid_ids = &[_]u32{38593859} },
        .{ .input = "565653-565659", .invalid_ids = &[_]u32{} },
        .{ .input = "824824821-824824827", .invalid_ids = &[_]u32{} },
        .{ .input = "2121212118-2121212124", .invalid_ids = &[_]u32{} },
    };
    const expected_sum: u64 = 1227775554;
    var actual_sum: u64 = 0;
    for (test_data) |data| {
        const i = std.mem.indexOf(u8, data.input, "-") orelse return error.Oops;
        const a = try std.fmt.parseInt(u32, data.input[0..i], 10);
        const b = try std.fmt.parseInt(u32, data.input[i + 1 ..], 10);

        var list: std.ArrayList(u32) = .empty;
        defer list.deinit(alloc);

        var buf: [16]u8 = undefined;
        var id = a;
        while (id <= b) : (id += 1) {
            const id_str = try std.fmt.bufPrint(&buf, "{d}", .{id});
            if (id_str.len % 2 != 0) continue;
            if (std.mem.eql(u8, id_str[0 .. id_str.len / 2], id_str[id_str.len / 2 ..])) {
                try list.append(alloc, id);
                actual_sum += id;
            }
        }
        try std.testing.expectEqualSlices(u32, data.invalid_ids, list.items);
    }
    try std.testing.expectEqual(expected_sum, actual_sum);
}
