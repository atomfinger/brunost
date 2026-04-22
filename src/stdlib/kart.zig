const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

const HashMap = std.StringHashMapUnmanaged(Value);

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "lengd",    .value = .{ .builtin_fn = lengd } },
        .{ .name = "hent",     .value = .{ .builtin_fn = hent } },
        .{ .name = "sett",     .value = .{ .builtin_fn = sett } },
        .{ .name = "fjern",    .value = .{ .builtin_fn = fjern } },
        .{ .name = "inneheld", .value = .{ .builtin_fn = inneheld } },
        .{ .name = "nøklar",   .value = .{ .builtin_fn = noklar } },
        .{ .name = "verdiar",  .value = .{ .builtin_fn = verdiar } },
    });
    return Value{ .module = members };
}

/// Clone `src` into a fresh arena-allocated HashMap, then return a pointer to it.
fn clone_map(src: *const HashMap, interp: *Interpreter) EvalError!*HashMap {
    const new_map = interp.str_alloc().create(HashMap) catch return EvalError.OutOfMemory;
    new_map.* = src.clone(interp.str_alloc()) catch return EvalError.OutOfMemory;
    return new_map;
}

fn lengd(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const h = try args[0].as_hashmap();
    return Value{ .integer = @intCast(h.count()) };
}

fn hent(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const h = try args[0].as_hashmap();
    const key = try args[1].as_str();
    return h.get(key) orelse EvalError.KeyNotFound;
}

fn sett(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 3) return EvalError.TypeError;
    const key = try args[1].as_str();
    const new_map = try clone_map(try args[0].as_hashmap(), interp);
    new_map.put(interp.str_alloc(), key, args[2]) catch return EvalError.OutOfMemory;
    return Value{ .hashmap = new_map };
}

fn fjern(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const key = try args[1].as_str();
    const new_map = try clone_map(try args[0].as_hashmap(), interp);
    _ = new_map.remove(key);
    return Value{ .hashmap = new_map };
}

fn inneheld(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const h = try args[0].as_hashmap();
    const key = try args[1].as_str();
    return Value{ .boolean = h.contains(key) };
}

fn noklar(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const h = try args[0].as_hashmap();
    const keys = interp.str_alloc().alloc(Value, h.count()) catch return EvalError.OutOfMemory;
    var it = h.iterator();
    var i: usize = 0;
    while (it.next()) |entry| : (i += 1) {
        keys[i] = Value{ .string = entry.key_ptr.* };
    }
    return Value{ .list = .{ .items = keys, .cap = keys.len } };
}

fn verdiar(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const h = try args[0].as_hashmap();
    const vals = interp.str_alloc().alloc(Value, h.count()) catch return EvalError.OutOfMemory;
    var it = h.iterator();
    var i: usize = 0;
    while (it.next()) |entry| : (i += 1) {
        vals[i] = entry.value_ptr.*;
    }
    return Value{ .list = .{ .items = vals, .cap = vals.len } };
}
