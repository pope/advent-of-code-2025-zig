const std = @import("std");

pub const Setup = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    file: std.fs.File,
    file_buffer: [4096]u8,
    opt_reader: ?std.fs.File.Reader,

    pub fn init(input_name: []const u8) !Setup {
        var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
        errdefer _ = gpa.deinit();

        var f = try loadInput(gpa.allocator(), input_name);
        errdefer f.close();

        return .{
            .gpa = gpa,
            .file = f,
            .file_buffer = undefined,
            .opt_reader = null,
        };
    }

    pub fn allocator(self: *Setup) std.mem.Allocator {
        return self.gpa.allocator();
    }

    pub fn reset(self: *Setup) !void {
        return self.reader().seekTo(0);
    }

    pub fn reader(self: *Setup) *std.fs.File.Reader {
        if (self.opt_reader) |*r| return r;

        const r = self.file.reader(&self.file_buffer);
        self.opt_reader = r;
        return &self.opt_reader.?;
    }

    pub fn lineIterator(self: *Setup) LineIterator {
        var r = self.reader();
        return .{ .reader = &r.interface };
    }

    pub fn deinit(self: *Setup) void {
        self.opt_reader = null;
        self.file.close();

        const leaked = self.gpa.deinit();
        if (leaked == .leak) @panic("Memory leak detected!");
    }
};

pub const LineIterator = union(enum) {
    const Self = @This();

    reader: *std.io.Reader,
    split: std.mem.SplitIterator(u8, .scalar),

    pub fn initFromBuffer(buf: []const u8) Self {
        return .{ .split = std.mem.splitScalar(
            u8,
            buf,
            '\n',
        ) };
    }

    pub fn next(self: *Self) !?[]const u8 {
        return switch (self.*) {
            .reader => |r| r.takeDelimiter('\n'),
            .split => |*it| it.*.next(),
        };
    }

    pub fn peek(self: *Self) !?[]const u8 {
        return switch (self.*) {
            .reader => |r| r.peekDelimiterExclusive('\n'),
            .split => |*it| it.*.peek(),
        };
    }
};

test "LineIterator - split" {
    const input =
        \\One
        \\Two
        \\Three
    ;
    var it = LineIterator.initFromBuffer(input);

    try std.testing.expectEqualStrings("One", (try it.next()).?);
    try std.testing.expectEqualStrings("Two", (try it.next()).?);
    try std.testing.expectEqualStrings("Three", (try it.next()).?);
    try std.testing.expectEqual(null, try it.next());
}

test "LineIterator - reader" {
    const input =
        \\One
        \\Two
        \\Three
    ;
    var buf: [64]u8 = undefined;
    var reader: std.testing.Reader = .init(&buf, &.{
        .{ .buffer = input },
    });
    var it: LineIterator = .{ .reader = &reader.interface };

    try std.testing.expectEqualStrings("One", (try it.next()).?);
    try std.testing.expectEqualStrings("Two", (try it.next()).?);
    try std.testing.expectEqualStrings("Three", (try it.next()).?);
    try std.testing.expectEqual(null, try it.next());
}

pub fn loadInput(alloc: std.mem.Allocator, name: []const u8) !std.fs.File {
    const home_dir = try std.process.getEnvVarOwned(
        alloc,
        "HOME",
    );
    defer alloc.free(home_dir);

    const path = try std.fmt.allocPrint(
        alloc,
        "{s}/Code/advent-of-code-2025/input/{s}",
        .{ home_dir, name },
    );
    defer alloc.free(path);

    return try std.fs.openFileAbsolute(
        path,
        .{ .mode = .read_only },
    );
}
