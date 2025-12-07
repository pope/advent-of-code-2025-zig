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
    const f = try aoc.loadInput(alloc, "day2-input");
    defer f.close();
    var reader = f.reader(&file_buffer);

    try part1(&reader.interface);

    try reader.seekTo(0);

    try part2(alloc, &reader.interface);
}

fn part1(r: *std.io.Reader) !void {
    var id_str_buf: [32]u8 = undefined;
    var sum: u64 = 0;
    while (try r.takeDelimiter(',')) |input| {
        const start, const end = blk: {
            const i = std.mem.indexOf(u8, input, "-") orelse return error.Oops;
            const a = try std.fmt.parseInt(u64, input[0..i], 10);
            const b = try std.fmt.parseInt(u64, input[i + 1 ..], 10);
            break :blk .{ a, b };
        };

        var id = start;
        while (id <= end) : (id += 1) {
            const id_str = try std.fmt.bufPrint(&id_str_buf, "{d}", .{id});
            if (id_str.len % 2 != 0) continue;
            if (std.mem.eql(u8, id_str[0 .. id_str.len / 2], id_str[id_str.len / 2 ..])) {
                sum += id;
            }
        }
    }

    std.debug.print("02.1: Password = {d}\n", .{sum});
}

fn part2(alloc: std.mem.Allocator, r: *std.io.Reader) !void {
    var list: std.ArrayList(u64) = .empty;
    defer list.deinit(alloc);

    var id_str_buf: [32]u8 = undefined;
    var sum: u64 = 0;
    while (try r.takeDelimiter(',')) |input| {
        defer list.clearRetainingCapacity();

        const start, const end = blk: {
            const i = std.mem.indexOf(u8, input, "-") orelse return error.Oops;
            const a = try std.fmt.parseInt(u64, input[0..i], 10);
            const b = try std.fmt.parseInt(u64, input[i + 1 ..], 10);
            break :blk .{ a, b };
        };

        var id = start;
        while (id <= end) : (id += 1) {
            const id_str = try std.fmt.bufPrint(&id_str_buf, "{d}", .{id});
            group: for (2..9) |divisor| {
                if (id_str.len % divisor != 0) continue;
                const len = id_str.len / divisor;
                for (0..divisor - 1) |i| {
                    if (!std.mem.eql(u8, id_str[(i + 0) * len .. (i + 1) * len], id_str[(i + 1) * len .. (i + 2) * len])) {
                        continue :group;
                    }
                }
                if (std.mem.indexOfScalar(u64, list.items, id)) |_| {} else {
                    try list.append(alloc, id);
                    sum += id;
                }
            }
        }
    }

    std.debug.print("02.2: Password = {d}\n", .{sum});
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

    var list: std.ArrayList(u32) = .empty;
    defer list.deinit(alloc);

    var buf: [16]u8 = undefined;

    for (test_data) |data| {
        defer list.clearRetainingCapacity();

        const start, const end = blk: {
            const i = std.mem.indexOf(u8, data.input, "-") orelse return error.Oops;
            const a = try std.fmt.parseInt(u32, data.input[0..i], 10);
            const b = try std.fmt.parseInt(u32, data.input[i + 1 ..], 10);
            break :blk .{ a, b };
        };

        var id = start;
        while (id <= end) : (id += 1) {
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

test "day 2 - part 2" {
    const alloc = std.testing.allocator;
    const test_data = [_]struct {
        input: []const u8,
        invalid_ids: []const u32,
    }{
        .{ .input = "11-22", .invalid_ids = &[_]u32{ 11, 22 } },
        .{ .input = "95-115", .invalid_ids = &[_]u32{ 99, 111 } },
        .{ .input = "998-1012", .invalid_ids = &[_]u32{ 999, 1010 } },
        .{ .input = "1188511880-1188511890", .invalid_ids = &[_]u32{1188511885} },
        .{ .input = "222220-222224", .invalid_ids = &[_]u32{222222} },
        .{ .input = "1698522-1698528", .invalid_ids = &[_]u32{} },
        .{ .input = "446443-446449", .invalid_ids = &[_]u32{446446} },
        .{ .input = "38593856-38593862", .invalid_ids = &[_]u32{38593859} },
        .{ .input = "565653-565659", .invalid_ids = &[_]u32{565656} },
        .{ .input = "824824821-824824827", .invalid_ids = &[_]u32{824824824} },
        .{ .input = "2121212118-2121212124", .invalid_ids = &[_]u32{2121212121} },
    };
    const expected_sum: u64 = 4174379265;
    var actual_sum: u64 = 0;

    var list: std.ArrayList(u32) = .empty;
    defer list.deinit(alloc);

    var buf: [16]u8 = undefined;

    for (test_data) |data| {
        defer list.clearRetainingCapacity();

        const start, const end = blk: {
            const i = std.mem.indexOf(u8, data.input, "-") orelse return error.Oops;
            const a = try std.fmt.parseInt(u32, data.input[0..i], 10);
            const b = try std.fmt.parseInt(u32, data.input[i + 1 ..], 10);
            break :blk .{ a, b };
        };

        var id = start;
        while (id <= end) : (id += 1) {
            const id_str = try std.fmt.bufPrint(&buf, "{d}", .{id});
            group: for (2..9) |divisor| {
                if (id_str.len % divisor != 0) continue;
                const len = id_str.len / divisor;
                for (0..divisor - 1) |i| {
                    if (!std.mem.eql(u8, id_str[(i + 0) * len .. (i + 1) * len], id_str[(i + 1) * len .. (i + 2) * len])) {
                        continue :group;
                    }
                }
                if (std.mem.indexOfScalar(u32, list.items, id)) |_| {} else {
                    try list.append(alloc, id);
                    actual_sum += id;
                }
            }
        }
        try std.testing.expectEqualSlices(u32, data.invalid_ids, list.items);
    }
    try std.testing.expectEqual(expected_sum, actual_sum);
}
