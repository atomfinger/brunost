// src/object.zig
const std = @import("std");
const ast = @import("ast.zig"); // May need for function objects later
const Allocator = std.mem.Allocator;

pub const ObjectType = enum {
    Integer,
    Boolean,
    StringObj,
    Null,
    ReturnValue,
    Error,
    // TODO: Add Function, List, Builtin
};

pub const Object = union(ObjectType) {
    Integer: IntegerObj,
    Boolean: BooleanObj,
    StringObj: StringObj,
    Null: NullObj,
    ReturnValue: ReturnValueObj,
    Error: ErrorObj,

    pub fn inspect(self: Object, writer: anytype) !void {
        switch (self) {
            .Integer => |obj| try writer.print("{d}", .{obj.value}),
            .Boolean => |obj| try writer.print("{s}", .{if (obj.value) "sant" else "usant"}),
            .StringObj => |obj| try writer.print("\"{s}\"", .{obj.value}),
            .Null => |_| try writer.print("null", .{}), // Or maybe "ingenting"?
            .ReturnValue => |obj| {
                try writer.print("ReturnValue(", .{});
                try obj.value.inspect(writer);
                try writer.print(")", .{});
            },
            .Error => |obj| try writer.print("Feil: {s}", .{obj.message}),
        }
    }

    pub fn deinit(self: *Object, allocator: Allocator) void {
        switch (self.*) {
            .StringObj => |*obj| allocator.free(obj.value),
            .Error => |*obj| allocator.free(obj.message),
            .ReturnValue => |*obj| {
                // The ReturnValue owns the object it's wrapping
                allocator.destroy(obj.value); // Assuming value is a *Object
            },
            .Integer, .Boolean, .Null => {}, // No heap allocation for these simple types
        }
    }

    // Helper to check if an object is "truthy" in boolean contexts
    pub fn isTruthy(self: Object) bool {
        return switch (self) {
            .Boolean => |b| b.value,
            .Null => false,
            else => true, // All other types are truthy (e.g. numbers, strings)
        };
    }
};

pub const IntegerObj = struct {
    value: i64,
};

pub const BooleanObj = struct {
    value: bool,
};

pub const StringObj = struct {
    value: []const u8, // Allocated string
};

pub const NullObj = struct {};

pub const ReturnValueObj = struct {
    value: *Object, // The actual value being returned, heap allocated
};

pub const ErrorObj = struct {
    message: []const u8, // Allocated string
};

// Commonly used singleton objects
pub const TRUE = Object{ .Boolean = .{ .value = true } };
pub const FALSE = Object{ .Boolean = .{ .value = false } };
pub const NULL = Object{ .Null = .{} };

test "Object Inspect" {
    const allocator = std.testing.allocator;
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    const int_obj = Object{ .Integer = .{ .value = 123 } };
    try int_obj.inspect(writer);
    try std.testing.expectEqualStrings("123", fbs.getWritten());
    fbs.reset();

    const bool_obj = Object{ .Boolean = .{ .value = true } };
    try bool_obj.inspect(writer);
    try std.testing.expectEqualStrings("sant", fbs.getWritten());
    fbs.reset();

    var str_obj_val = try allocator.dupe(u8, "hello");
    defer allocator.free(str_obj_val);
    const str_obj = Object{ .StringObj = .{ .value = str_obj_val } };
    try str_obj.inspect(writer);
    try std.testing.expectEqualStrings("\"hello\"", fbs.getWritten());
    fbs.reset();


    try NULL.inspect(writer);
    try std.testing.expectEqualStrings("null", fbs.getWritten());
    fbs.reset();

    var err_msg = try allocator.dupe(u8, "test error");
    // ErrorObj's message will be freed by its deinit if created through a helper that allocates
    // Here we manage it manually for the test structure.
    const err_obj = Object{ .Error = .{ .message = err_msg } };
    try err_obj.inspect(writer);
    try std.testing.expectEqualStrings("Feil: test error", fbs.getWritten());
    // No defer allocator.free(err_msg) here if we imagine it's owned by ErrorObj for deinit.
    // However, for this direct struct init, we'd normally free it.
    // Let's assume a helper `newError` would handle allocation and `deinit` would free.
    allocator.free(err_msg); // Manual free for this test setup.
    fbs.reset();

    // Test ReturnValueObj
    var ret_val_int = try allocator.create(Object);
    ret_val_int.* = Object{.Integer = .{ .value = 99 }};
    const ret_obj = Object{ .ReturnValue = .{ .value = ret_val_int } };
    try ret_obj.inspect(writer);
    try std.testing.expectEqualStrings("ReturnValue(99)", fbs.getWritten());
    allocator.destroy(ret_val_int); // Manually destroy for this test setup.
    fbs.reset();
}

test "Object Truthiness" {
    try std.testing.expect(TRUE.isTruthy());
    try std.testing.expect(!FALSE.isTruthy());
    try std.testing.expect(!NULL.isTruthy());
    try std.testing.expect(Object{.Integer = .{ .value = 0 }}.isTruthy());
    try std.testing.expect(Object{.Integer = .{ .value = 12}}.isTruthy());
    const empty_str = Object{.StringObj = .{ .value = ""}};
    try std.testing.expect(empty_str.isTruthy()); // Empty string is truthy
}
