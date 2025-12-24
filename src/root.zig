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

    pub inline fn lineIterator(self: *Setup) InputIterator {
        return self.inputIterator('\n');
    }

    pub fn inputIterator(self: *Setup, delim: u8) InputIterator {
        var r = self.reader();
        return .initFromReader(&r.interface, delim);
    }

    pub fn deinit(self: *Setup) void {
        self.opt_reader = null;
        self.file.close();

        const leaked = self.gpa.deinit();
        if (leaked == .leak) @panic("Memory leak detected!");
    }
};

const GenericInputIterator = struct {
    ptr: *anyopaque,
    peekFn: *const fn (ptr: *anyopaque) ?[]const u8,
    nextFn: *const fn (ptr: *anyopaque) ?[]const u8,

    fn peek(self: GenericInputIterator) ?[]const u8 {
        return self.peekFn(self.ptr);
    }

    fn next(self: GenericInputIterator) ?[]const u8 {
        return self.nextFn(self.ptr);
    }
};

pub fn SliceStructIterable(
    comptime T: type,
    comptime name: []const u8,
) type {
    return struct {
        const Self = @This();

        data: []const T,
        cur: usize,

        pub fn init(data: []const T) Self {
            return .{ .data = data, .cur = 0 };
        }

        pub fn iterator(self: *Self) GenericInputIterator {
            return .{
                .ptr = self,
                .peekFn = peek,
                .nextFn = next,
            };
        }

        fn peek(ptr: *anyopaque) ?[]const u8 {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.cur + 1 >= self.data.len) return null;
            return @field(self.data[self.cur + 1], name);
        }

        fn next(ptr: *anyopaque) ?[]const u8 {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.cur >= self.data.len) return null;
            const result = @field(self.data[self.cur], name);
            self.cur += 1;
            return result;
        }
    };
}

pub const InputIterator = union(enum) {
    const Self = @This();

    reader: struct { *std.io.Reader, u8 },
    split: std.mem.SplitIterator(u8, .scalar),
    it: GenericInputIterator,

    pub fn initFromBuffer(buf: []const u8, delim: u8) Self {
        return .{ .split = std.mem.splitScalar(
            u8,
            buf,
            delim,
        ) };
    }

    pub fn initFromReader(r: *std.io.Reader, delim: u8) Self {
        return .{ .reader = .{ r, delim } };
    }

    pub fn initFromIterator(it: GenericInputIterator) Self {
        return .{ .it = it };
    }

    pub fn next(self: *Self) !?[]const u8 {
        return switch (self.*) {
            .reader => |r| r[0].takeDelimiter(r[1]),
            .split => |*it| it.*.next(),
            .it => |*it| it.*.next(),
        };
    }

    pub fn peek(self: *Self) !?[]const u8 {
        return switch (self.*) {
            .reader => |r| blk: {
                const b = try r[0].peekDelimiterExclusive(r[1]);
                break :blk b;
            },
            .split => |*it| it.*.peek(),
            .it => |*it| it.*.peek(),
        };
    }
};

test "InputIterator - split" {
    const input =
        \\One
        \\Two
        \\Three
    ;
    var it = InputIterator.initFromBuffer(input, '\n');

    try std.testing.expectEqualStrings("One", (try it.next()).?);
    try std.testing.expectEqualStrings("Two", (try it.next()).?);
    try std.testing.expectEqualStrings("Three", (try it.next()).?);
    try std.testing.expectEqual(null, try it.next());
}

test "InputIterator - reader" {
    const input =
        \\One
        \\Two
        \\Three
    ;
    var buf: [64]u8 = undefined;
    var reader: std.testing.Reader = .init(&buf, &.{
        .{ .buffer = input },
    });
    var it: InputIterator = .initFromReader(&reader.interface, '\n');

    try std.testing.expectEqualStrings("One", (try it.next()).?);
    try std.testing.expectEqualStrings("Two", (try it.next()).?);
    try std.testing.expectEqualStrings("Three", (try it.next()).?);
    try std.testing.expectEqual(null, try it.next());
}

test "InputIterator - generic iterator" {
    const test_input = [_]struct {
        input: []const u8,
    }{
        .{ .input = "One" },
        .{ .input = "Two" },
        .{ .input = "Three" },
    };

    var slice_iterable = SliceStructIterable(
        @TypeOf(test_input[0]),
        "input",
    ).init(&test_input);
    var it: InputIterator = .initFromIterator(slice_iterable.iterator());

    try std.testing.expectEqualStrings("Two", (try it.peek()).?);
    try std.testing.expectEqualStrings("One", (try it.next()).?);
    try std.testing.expectEqualStrings("Three", (try it.peek()).?);
    try std.testing.expectEqualStrings("Two", (try it.next()).?);
    try std.testing.expectEqual(null, try it.peek());
    try std.testing.expectEqualStrings("Three", (try it.next()).?);
    try std.testing.expectEqual(null, try it.peek());
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
