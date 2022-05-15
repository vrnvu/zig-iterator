const std = @import("std");
const testing = std.testing;

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        nextFn: fn (self: *Self) ?T,

        pub fn next(self: *Self) ?T {
            return self.nextFn(self);
        }
    };
}

pub fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(T),
        next_val: T,
        start: T,
        step: T,
        end: T,

        pub fn init(start: T, end: T, step: T) !Self {
            if (step == 0) {
                return error.InvalidStepSize;
            }

            return Self{
                .iterator = Iterator(T){
                    .nextFn = next,
                },
                .next_val = start,
                .start = start,
                .step = step,
                .end = end,
            };
        }

        pub fn next(iterator: *Iterator(T)) ?T {
            const self = @fieldParentPtr(Self, "iterator", iterator);
            const current = self.next_val;
            if (self.step < 0) {
                if (current <= self.end) {
                    return null;
                }
            } else {
                if (current >= self.end) {
                    return null;
                }
            }
            self.next_val += self.step;
            return current;
        }
    };
}

pub fn fold(
    comptime T: type,
    f: fn (acc: T, val: T) T,
    iter: *Iterator(T),
    init: T,
) T {
    var acc: T = init;
    while (iter.next()) |val| {
        acc = f(acc, val);
    }
    return acc;
}

test "range ascend" {
    var range = try Range(u32).init(0, 10, 1);
    var iter = &range.iterator;
    var correct: u32 = 0;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct += 1;
    }
    try testing.expectEqual(correct, 10);
    try testing.expectEqual(iter.next(), null);
}

test "range descend" {
    var range = try Range(i32).init(10, 0, -1);
    var iter = &range.iterator;
    var correct: i32 = 10;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct -= 1;
    }
    try testing.expectEqual(correct, 0);
    try testing.expectEqual(iter.next(), null);
}

test "range skip" {
    var range = try Range(u32).init(0, 10, 2);
    var iter = &range.iterator;
    var correct: u32 = 0;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct += 2;
    }
    try testing.expectEqual(correct, 10);
    try testing.expectEqual(iter.next(), null);
}

fn add(a: u32, b: u32) u32 {
    return a + b;
}

test "fold over range" {
    var range = try Range(u32).init(1, 10, 1);
    var iter = &range.iterator;
    const total = fold(u32, add, iter, 17);
    try testing.expectEqual(total, 17 + 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9);
}

fn mul(a: u32, b: u32) u32 {
    return a * b;
}

test "factorial" {
    var range = try Range(u32).init(1, 10, 1);
    var iter = &range.iterator;
    const total = fold(u32, mul, iter, 1);
    try testing.expectEqual(total, 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8 * 9);
}

fn factorial(n: u32) !u32 {
    var range = try Range(u32).init(1, n, 1);
    var iter = &range.iterator;
    return fold(u32, mul, iter, 1);
}

test "factorial fn" {
    try testing.expectEqual(factorial(10), 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8 * 9);
}

pub fn Stringer() type {
    return struct {
        const Self = @This();

        iterator: Iterator(u8),
        string: []const u8,
        p: usize,

        pub fn init(string: []const u8) !Self {
            return Self{
                .iterator = Iterator(u8){
                    .nextFn = next,
                },
                .string = string,
                .p = 0,
            };
        }

        pub fn next(iterator: *Iterator(u8)) ?u8 {
            const self = @fieldParentPtr(Self, "iterator", iterator);
            if (self.p >= self.string.len) {
                return null;
            }
            const current = self.string[self.p];
            self.p += 1;
            return current;
        }
    };
}

test "stringer" {
    const string = "hello";
    var range = try Stringer().init(string[0..]);
    var iter = &range.iterator;
    var i: usize = 0;
    while (iter.next()) |c| {
        try testing.expectEqual(string[i], c);
        i += 1;
    }
    try testing.expectEqual(i, string.len);
    try testing.expectEqual(iter.next(), null);
}

pub fn ListConsumer(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(T),
        list: std.SinglyLinkedList(T),

        pub fn init(list: std.SinglyLinkedList(T)) !Self {
            return Self{
                .iterator = Iterator(T){
                    .nextFn = next,
                },
                .list = list,
            };
        }

        pub fn next(iterator: *Iterator(T)) ?T {
            const self = @fieldParentPtr(Self, "iterator", iterator);
            if (self.list.popFirst()) |current| {
                return current.data;
            } else {
                return null;
            }
        }
    };
}

test "singly linked list" {
    const L = std.SinglyLinkedList(u32);
    var list = L{};

    try testing.expect(list.len() == 0);

    var one = L.Node{ .data = 1 };
    var two = L.Node{ .data = 2 };
    var three = L.Node{ .data = 3 };

    list.prepend(&three);
    list.prepend(&two);
    list.prepend(&one);

    try testing.expect(list.len() == 3);

    var consumer = try ListConsumer(u32).init(list);
    var iter = &consumer.iterator;
    var c: u32 = 1;

    while (iter.next()) |got| {
        try testing.expectEqual(c, got);
        c += 1;
    }
}

test "fold over singly linked list" {
    const L = std.SinglyLinkedList(u32);
    var list = L{};

    try testing.expect(list.len() == 0);

    var one = L.Node{ .data = 1 };
    var two = L.Node{ .data = 2 };
    var three = L.Node{ .data = 3 };

    list.prepend(&three);
    list.prepend(&two);
    list.prepend(&one);

    var consumer = try ListConsumer(u32).init(list);
    var iter = &consumer.iterator;
    const total = fold(u32, add, iter, 0);
    try testing.expectEqual(total, 0 + 1 + 2 + 3);
}
