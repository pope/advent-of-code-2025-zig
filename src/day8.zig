const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day8-input");
    defer setup.deinit();

    var it = setup.lineIterator();

    std.debug.print("08.1: Answer = {}\n", .{
        try part1Answer(setup.allocator(), &it, 1000),
    });
}

// Element type can be a float or int. Messing around for fun.
const Vec4 = @Vector(4, i64);

const Vec4Pair = struct {
    a_idx: u16,
    b_idx: u16,
    distance: @typeInfo(Vec4).vector.child,

    fn lessThan(_: void, l: Vec4Pair, r: Vec4Pair) std.math.Order {
        return std.math.order(l.distance, r.distance);
    }
};

fn relativeDistance(a: Vec4, b: Vec4) @typeInfo(Vec4).vector.child {
    const vec_type = @typeInfo(Vec4).vector.child;
    const c = blk: {
        switch (@typeInfo(vec_type)) {
            .int => |i| if (i.signedness == .unsigned) {
                // Since I couldn't find an absolute value subtract
                const sm = @select(vec_type, a < b, a, b);
                const lg = @select(vec_type, a >= b, a, b);
                break :blk lg - sm;
            },
            else => {},
        }
        break :blk a - b;
    };
    const sqrd = c * c;
    // Ignoring the @sqrt of this answer since we don't need the actual
    // distance, and thus can save a calculation.
    return @reduce(.Add, sqrd);
}

const DisjointSet = struct {
    parents: []u16,

    fn init(alloc: std.mem.Allocator, len: u32) !DisjointSet {
        const parents = try alloc.alloc(u16, len);
        for (parents, 0..) |*p, idx| p.* = @intCast(idx);
        return .{ .parents = parents };
    }

    fn deinit(self: DisjointSet, alloc: std.mem.Allocator) void {
        alloc.free(self.parents);
    }

    fn root(self: DisjointSet, idx: u16) u16 {
        if (self.parents[idx] != idx) {
            self.parents[idx] = self.root(self.parents[idx]);
        }
        return self.parents[idx];
    }

    fn merge(self: DisjointSet, a_idx: u16, b_idx: u16) void {
        const a_root = self.root(a_idx);
        const b_root = self.root(b_idx);
        self.parents[a_root] = b_root;
    }
};

fn parseInput(alloc: std.mem.Allocator, line_it: *aoc.LineIterator) ![]Vec4 {
    const vec_type = @typeInfo(Vec4).vector.child;
    var result: std.ArrayList(Vec4) = .empty;
    defer result.deinit(alloc);
    while (try line_it.next()) |line| {
        var it = std.mem.splitScalar(u8, line, ',');
        switch (@typeInfo(vec_type)) {
            .float => {
                const x = try std.fmt.parseFloat(
                    vec_type,
                    it.next() orelse return error.Oops,
                );
                const y = try std.fmt.parseFloat(
                    vec_type,
                    it.next() orelse return error.Oops,
                );
                const z = try std.fmt.parseFloat(
                    vec_type,
                    it.next() orelse return error.Oops,
                );
                if (it.next() != null) return error.Oops;
                try result.append(alloc, .{ x, y, z, 0 });
            },
            .int => {
                const x = try std.fmt.parseInt(
                    vec_type,
                    it.next() orelse return error.Oops,
                    10,
                );
                const y = try std.fmt.parseInt(
                    vec_type,
                    it.next() orelse return error.Oops,
                    10,
                );
                const z = try std.fmt.parseInt(
                    vec_type,
                    it.next() orelse return error.Oops,
                    10,
                );
                if (it.next() != null) return error.Oops;
                try result.append(alloc, .{ x, y, z, 0 });
            },
            else => @compileError("Unsupported type"),
        }
    }
    return result.toOwnedSlice(alloc);
}

fn getTopClosestPairs(
    alloc: std.mem.Allocator,
    boxes: []const Vec4,
    top_num: usize,
) !std.ArrayList(Vec4Pair) {
    var top: std.ArrayList(Vec4Pair) = try .initCapacity(alloc, top_num);
    errdefer top.deinit(alloc);

    // Using a heap because it's too many to sort quickly
    var heap: std.PriorityQueue(
        Vec4Pair,
        void,
        Vec4Pair.lessThan,
    ) = .init(alloc, {});
    defer heap.deinit();
    // Close enough size to avoid re-allocs.
    try heap.ensureTotalCapacity(std.math.pow(usize, boxes.len, 2) / 2);

    for (boxes[0 .. boxes.len - 1], 0..) |a, i| {
        for (boxes[i + 1 .. boxes.len], 1..) |b, j| {
            const distance = relativeDistance(a, b);
            try heap.add(.{
                .a_idx = @intCast(i),
                .b_idx = @intCast(i + j),
                .distance = distance,
            });
        }
    }

    for (0..top_num) |_| {
        try top.appendBounded(heap.remove());
    }
    return top;
}

fn part1Answer(alloc: std.mem.Allocator, line_it: *aoc.LineIterator, top_num: usize) !u64 {
    const boxes = try parseInput(alloc, line_it);
    defer alloc.free(boxes);

    const d_set: DisjointSet = try .init(alloc, @intCast(boxes.len));
    defer d_set.deinit(alloc);

    // Merge the top `n` pairs into circuits
    {
        var top_pairs: std.ArrayList(Vec4Pair) = try getTopClosestPairs(
            alloc,
            boxes,
            top_num,
        );
        defer top_pairs.deinit(alloc);

        for (top_pairs.items) |p| {
            d_set.merge(p.a_idx, p.b_idx);
        }
    }

    // For each index, count how many items refer to itself as root
    // > 1 - multiple boxes in the circuit
    // = 1 - no connections
    // = 0 - not a root, belongs to someone else
    const sizes = try alloc.alloc(u16, boxes.len);
    {
        @memset(sizes, 0);
        defer alloc.free(sizes);

        for (0..boxes.len) |idx| {
            sizes[d_set.root(@intCast(idx))] += 1;
        }
        std.mem.sort(u16, sizes, {}, std.sort.desc(u16));
    }

    const a: u64 = @intCast(sizes[0]);
    const b: u64 = @intCast(sizes[1]);
    const c: u64 = @intCast(sizes[2]);
    return a * b * c;
}

const test_input =
    \\162,817,812
    \\57,618,57
    \\906,360,560
    \\592,479,940
    \\352,342,300
    \\466,668,158
    \\542,29,236
    \\431,825,988
    \\739,650,466
    \\52,470,668
    \\216,146,977
    \\819,987,18
    \\117,168,530
    \\805,96,715
    \\346,949,466
    \\970,615,88
    \\941,993,340
    \\862,61,35
    \\984,92,344
    \\425,690,689
;

test "day 8 - part 1" {
    var line_it = aoc.LineIterator.initFromBuffer(test_input);

    const result = try part1Answer(std.testing.allocator, &line_it, 10);
    try std.testing.expectEqual(40, result);
}
