const std = @import("std");
const aoc = @import("aoc");

pub fn main() !void {
    var setup: aoc.Setup = try .init("day8-input");
    defer setup.deinit();

    var it = setup.lineIterator();

    std.debug.print("08.1: Answer = {}\n", .{
        try part1Answer(setup.allocator(), &it, 1000),
    });

    try setup.reset();

    std.debug.print("08.2: Answer = {}\n", .{
        try part2Answer(setup.allocator(), &it),
    });
}

// Element type can be a float or int. Messing around for fun.  As a result,
// the code in this file is pretty dang funky at parts, but all in the spirit
// of learning.
//
// At the end of this experiment, f32 is performing better than i64 in debug
// mode. In release mode, it's a wash.
const Vec4 = @Vector(4, f32);

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

const Vec4PairHeap = std.PriorityQueue(
    Vec4Pair,
    void,
    Vec4Pair.lessThan,
);

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

fn parseInput(alloc: std.mem.Allocator, line_it: *aoc.InputIterator) ![]Vec4 {
    const vec_type = @typeInfo(Vec4).vector.child;
    var result: std.ArrayList(Vec4) = .empty;
    defer result.deinit(alloc);
    while (try line_it.next()) |line| {
        var it = std.mem.splitScalar(
            u8,
            line,
            ',',
        );
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

fn getPairsHeap(
    alloc: std.mem.Allocator,
    boxes: []const Vec4,
) !Vec4PairHeap {
    var heap: Vec4PairHeap = .init(alloc, {});
    errdefer heap.deinit();

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
    return heap;
}

fn part1Answer(
    alloc: std.mem.Allocator,
    line_it: *aoc.InputIterator,
    top_num: usize,
) !u64 {
    const boxes = try parseInput(alloc, line_it);
    defer alloc.free(boxes);

    const d_set: DisjointSet = try .init(alloc, @intCast(boxes.len));
    defer d_set.deinit(alloc);

    // Merge the top `n` pairs into circuits
    {
        var pair_heap = try getPairsHeap(
            alloc,
            boxes,
        );
        defer pair_heap.deinit();

        var count: usize = 0;
        while (pair_heap.removeOrNull()) |p| {
            d_set.merge(p.a_idx, p.b_idx);
            count += 1;
            if (count >= top_num) break;
        }
    }

    // For each index, count how many items refer to itself as root
    // > 1 - multiple boxes in the circuit
    // = 1 - no connections
    // = 0 - not a root, belongs to someone else
    const sizes = try alloc.alloc(u16, boxes.len);
    @memset(sizes, 0);
    defer alloc.free(sizes);

    for (0..boxes.len) |idx| {
        sizes[d_set.root(@intCast(idx))] += 1;
    }
    std.mem.sort(u16, sizes, {}, std.sort.desc(u16));

    const a: u64 = @intCast(sizes[0]);
    const b: u64 = @intCast(sizes[1]);
    const c: u64 = @intCast(sizes[2]);
    return a * b * c;
}

fn part2Answer(
    alloc: std.mem.Allocator,
    line_it: *aoc.InputIterator,
) !u64 {
    const boxes = try parseInput(alloc, line_it);
    defer alloc.free(boxes);

    const d_set: DisjointSet = try .init(alloc, @intCast(boxes.len));
    defer d_set.deinit(alloc);

    var pair_heap = try getPairsHeap(
        alloc,
        boxes,
    );
    defer pair_heap.deinit();

    var remaining = boxes.len;
    while (pair_heap.removeOrNull()) |p| {
        if (d_set.root(p.a_idx) == d_set.root(p.b_idx)) continue;
        d_set.merge(p.a_idx, p.b_idx);
        remaining -= 1;
        if (remaining == 1) {
            const res = boxes[p.a_idx][0] * boxes[p.b_idx][0];
            return switch (@typeInfo(@typeInfo(Vec4).vector.child)) {
                .int => @intCast(res),
                .float => @intFromFloat(res),
                else => @compileError("Unsupported type"),
            };
        }
    }

    return error.Oops;
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
    var it: aoc.InputIterator = .initFromBuffer(test_input, '\n');

    const result = try part1Answer(
        std.testing.allocator,
        &it,
        10,
    );
    try std.testing.expectEqual(40, result);
}

test "day 8 - part 2" {
    var it: aoc.InputIterator = .initFromBuffer(test_input, '\n');

    const result = try part2Answer(
        std.testing.allocator,
        &it,
    );
    try std.testing.expectEqual(25272, result);
}
