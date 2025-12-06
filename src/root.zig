const std = @import("std");

pub fn loadInput(alloc: std.mem.Allocator, name: []const u8) !std.fs.File {
    const home_dir = try std.process.getEnvVarOwned(alloc, "HOME");
    defer alloc.free(home_dir);

    const path = try std.fmt.allocPrint(
        alloc,
        "{s}/Code/advent-of-code-2025/input/{s}",
        .{ home_dir, name },
    );
    defer alloc.free(path);

    return try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
}
