const std = @import("std");

pub const Setup = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    file: std.fs.File,
    file_buffer: [4096]u8,

    pub fn init(input_name: []const u8) !Setup {
        var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
        errdefer _ = gpa.deinit();

        var f = try loadInput(gpa.allocator(), input_name);
        errdefer f.close();

        return .{
            .gpa = gpa,
            .file = f,
            .file_buffer = undefined,
        };
    }

    pub fn allocator(self: *Setup) std.mem.Allocator {
        return self.gpa.allocator();
    }

    pub fn reader(self: *Setup) std.fs.File.Reader {
        return self.file.reader(&self.file_buffer);
    }

    pub fn deinit(self: *Setup) void {
        self.file.close();

        const leaked = self.gpa.deinit();
        if (leaked == .leak) @panic("Memory leak detected!");
    }
};

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
