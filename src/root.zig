const std = @import("std");

pub const AnswerValue = union(enum) {
    todo: void,
    result: struct { label: []const u8, val: u64 },

    pub fn initResult(label: []const u8, val: u64) AnswerValue {
        return .{ .result = .{
            .label = label,
            .val = val,
        } };
    }

    pub fn write(self: AnswerValue, w: *std.io.Writer) !void {
        switch (self) {
            .todo => _ = try w.write("TODO"),
            .result => |r| try w.print(
                "{s} = {d}",
                .{ r.label, r.val },
            ),
        }
    }
};

pub const Answer = struct {
    part1: AnswerValue,
    part2: AnswerValue,
    day: u8,
};

const GenericInputIterator = struct {
    ptr: *anyopaque,
    peekFn: *const fn (ptr: *anyopaque) ?[]const u8,
    nextFn: *const fn (ptr: *anyopaque) ?[]const u8,
    resetFn: *const fn (ptr: *anyopaque) void,

    fn peek(self: GenericInputIterator) ?[]const u8 {
        return self.peekFn(self.ptr);
    }

    fn next(self: GenericInputIterator) ?[]const u8 {
        return self.nextFn(self.ptr);
    }

    fn reset(self: GenericInputIterator) void {
        return self.resetFn(self.ptr);
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
                .resetFn = reset,
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

        fn reset(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.cur = 0;
        }
    };
}

pub const InputIterator = union(enum) {
    const Self = @This();

    split: std.mem.SplitIterator(u8, .scalar),
    it: GenericInputIterator,

    pub fn initFromBuffer(buf: []const u8, delim: u8) Self {
        return .{ .split = std.mem.splitScalar(
            u8,
            buf,
            delim,
        ) };
    }

    pub fn initFromIterator(it: GenericInputIterator) Self {
        return .{ .it = it };
    }

    pub fn next(self: *Self) ?[]const u8 {
        return switch (self.*) {
            .split => |*it| it.*.next(),
            .it => |*it| it.*.next(),
        };
    }

    pub fn peek(self: *Self) ?[]const u8 {
        return switch (self.*) {
            .split => |*it| it.*.peek(),
            .it => |*it| it.*.peek(),
        };
    }

    pub fn reset(self: *Self) void {
        switch (self.*) {
            .split => |*it| it.*.reset(),
            .it => |*it| it.*.reset(),
        }
    }
};

test "InputIterator - split" {
    const input =
        \\One
        \\Two
        \\Three
    ;
    var it = InputIterator.initFromBuffer(input, '\n');

    try std.testing.expectEqualStrings("One", it.next().?);
    try std.testing.expectEqualStrings("Two", it.next().?);
    try std.testing.expectEqualStrings("Three", it.next().?);
    try std.testing.expectEqual(null, it.next());

    it.reset();
    try std.testing.expectEqualStrings("One", (it.next()).?);
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

    try std.testing.expectEqualStrings("Two", it.peek().?);
    try std.testing.expectEqualStrings("One", it.next().?);
    try std.testing.expectEqualStrings("Three", it.peek().?);
    try std.testing.expectEqualStrings("Two", it.next().?);
    try std.testing.expectEqual(null, it.peek());
    try std.testing.expectEqualStrings("Three", it.next().?);
    try std.testing.expectEqual(null, it.peek());
    try std.testing.expectEqual(null, it.next());

    it.reset();
    try std.testing.expectEqualStrings("One", it.next().?);
}

pub fn loadInput(alloc: std.mem.Allocator, name: []const u8) !std.fs.File {
    const cwd_path = try std.fs.cwd().realpathAlloc(
        alloc,
        ".",
    );
    defer alloc.free(cwd_path);

    const path = try std.fmt.allocPrint(
        alloc,
        "{s}/src/input/{s}",
        .{ cwd_path, name },
    );
    defer alloc.free(path);

    return try std.fs.openFileAbsolute(
        path,
        .{ .mode = .read_only },
    );
}
