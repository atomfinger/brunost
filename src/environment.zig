// src/environment.zig
const std = @import("std");
const object = @import("object.zig");
const Allocator = std.mem.Allocator;

const Object = object.Object;

// For storing variable metadata along with the object
pub const VariableState = struct {
    value: *Object, // Pointer to the heap-allocated object
    is_mutable: bool,
};

pub const Environment = struct {
    store: std.StringHashMap(VariableState),
    outer: ?*Environment,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Environment {
        return Environment{
            .store = std.StringHashMap(VariableState).init(allocator),
            .outer = null,
            .allocator = allocator,
        };
    }

    pub fn newEnclosed(outer_env: *Environment) Environment {
        var env = Self.init(outer_env.allocator);
        env.outer = outer_env;
        return env;
    }

    pub fn deinit(self: *Self) void {
        // Important: The environment owns the VariableState structs,
        // and the VariableState structs (conceptually) own the *Object.
        // We need to destroy the objects when the environment is destroyed.
        var iterator = self.store.iterator();
        while (iterator.next()) |entry| {
            // entry.value_ptr.* is the VariableState
            // entry.value_ptr.*.value is the *Object
            self.allocator.destroy(entry.value_ptr.*.value);
        }
        self.store.deinit();
    }

    // Get a variable's value
    pub fn get(self: *Self, name: []const u8) ?*Object {
        const entry = self.store.get(name);
        if (entry) |var_state| {
            return var_state.value;
        } else if (self.outer) |outer_env| {
            return outer_env.get(name);
        } else {
            return null;
        }
    }

    // Get a variable's state (value + mutability)
    pub fn getState(self: *Self, name: []const u8) ?VariableState {
        const entry = self.store.get(name);
        if (entry) |var_state| {
            return var_state;
        } else if (self.outer) |outer_env| {
            return outer_env.getState(name);
        } else {
            return null;
        }
    }

    // Declare a new variable (fast or endreleg initially)
    // For 'fast', this is the only time it's set.
    // For 'endreleg', this is the declaration.
    pub fn declare(self: *Self, name: []const u8, val: *Object, is_mutable: bool) !*Object {
        // In Brunost, 'fast x er y' or 'endreleg x er y' always declares.
        // Re-declaration in the same scope is an error (to be checked by parser or resolver later)
        // For now, interpreter assumes valid, resolved code.
        if (self.store.contains(name)) {
            // This should ideally be caught earlier (e.g. semantic analysis phase)
            // For now, let's return an error or overwrite if it's a simple interpreter.
            // Overwriting for now, but a real implementation might panic or error.
            // std.debug.print("Warning: Redeclaring variable '{s}' in the same scope.\n", .{name});
            // To properly handle this, we might need a different function for assignment.
            // Let's free the old value if overwriting.
            const old_var_state = self.store.get(name).?;
            self.allocator.destroy(old_var_state.value);
        }

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        try self.store.put(owned_name, VariableState{ .value = val, .is_mutable = is_mutable });
        return val;
    }

    // Assign to an existing 'endreleg' variable
    // Returns the new value, or null if the variable is not found or not mutable.
    pub fn assign(self: *Self, name: []const u8, val: *Object) !?*Object {
        var current_env: ?*Self = self;
        while (current_env) |env| {
            if (env.store.getEntry(name)) |entry| {
                if (entry.value_ptr.*.is_mutable) {
                    // Free the old object before assigning the new one
                    env.allocator.destroy(entry.value_ptr.*.value);
                    entry.value_ptr.*.value = val;
                    return val;
                } else {
                    // Error: Trying to assign to a 'fast' variable
                    // This error should be an object.Object.Error type for the evaluator
                    // For now, returning null, evaluator will need to create an Error object.
                    return null;
                }
            }
            current_env = env.outer;
        }
        // Variable not found in any scope
        return null;
    }
};

test "Environment get/declare/assign" {
    const allocator = std.testing.allocator;
    var global_env = Environment.init(allocator);
    defer global_env.deinit();

    // Declare 'fast'
    var val1_obj = try allocator.create(Object);
    val1_obj.* = object.Object{.Integer = .{ .value = 10 }};
    _ = try global_env.declare("a", val1_obj, false); // fast a er 10

    var retrieved_a = global_env.get("a").?;
    try std.testing.expectEqual(10, retrieved_a.Integer.value);

    // Declare 'endreleg'
    var val2_obj = try allocator.create(Object);
    val2_obj.* = object.Object{.Boolean = .{ .value = true }};
    _ = try global_env.declare("b", val2_obj, true); // endreleg b er sant

    var retrieved_b = global_env.get("b").?;
    try std.testing.expect(retrieved_b.Boolean.value);

    // Assign to 'endreleg'
    var val3_obj = try allocator.create(Object);
    val3_obj.* = object.Object{.Boolean = .{ .value = false }};
    var assigned_b = (try global_env.assign("b", val3_obj).?).?;

    try std.testing.expect(!assigned_b.Boolean.value);
    retrieved_b = global_env.get("b").?; // get it again
    try std.testing.expect(!retrieved_b.Boolean.value);


    // Attempt to assign to 'fast' (should fail or be handled by assign returning null for error)
    var val4_obj = try allocator.create(Object);
    val4_obj.* = object.Object{.Integer = .{ .value = 20 }};
    const assign_fast_result = try global_env.assign("a", val4_obj);
    try std.testing.expect(assign_fast_result == null); // Expecting null as error indicator for now
    // The original val4_obj for 'a' was not destroyed by assign, but if assign succeeded, it would be.
    // If assign returns null due to 'fast', the new val4_obj is now orphaned and needs freeing.
    if (assign_fast_result == null) { // This means assignment failed (e.g. to fast var)
        allocator.destroy(val4_obj);
    }


    retrieved_a = global_env.get("a").?; // Check 'a' is unchanged
    try std.testing.expectEqual(10, retrieved_a.Integer.value);


    // Test enclosed environment
    var local_env = Environment.newEnclosed(&global_env);
    defer local_env.deinit();

    // Get from outer
    retrieved_a = local_env.get("a").?;
    try std.testing.expectEqual(10, retrieved_a.Integer.value);

    // Declare in local (shadowing)
    var val5_obj = try allocator.create(Object);
    val5_obj.* = object.Object{.Integer = .{ .value = 100 }};
    _ = try local_env.declare("a", val5_obj, false); // fast a er 100 (in local)

    retrieved_a = local_env.get("a").?; // Should get from local
    try std.testing.expectEqual(100, retrieved_a.Integer.value);

    retrieved_a = global_env.get("a").?; // Global should be unchanged
    try std.testing.expectEqual(10, retrieved_a.Integer.value);

    // Assign in local to an outer 'endreleg' variable
    var val6_obj = try allocator.create(Object);
    val6_obj.* = object.Object{.StringObj = .{ .value = try allocator.dupe(u8, "lokal endring") }};
    _ = (try local_env.assign("b", val6_obj).?).?; // b is in global, but assignable

    var retrieved_b_local = local_env.get("b").?;
    try std.testing.expectEqualStrings("lokal endring", retrieved_b_local.StringObj.value);
    var retrieved_b_global = global_env.get("b").?;
    try std.testing.expectEqualStrings("lokal endring", retrieved_b_global.StringObj.value);
}
