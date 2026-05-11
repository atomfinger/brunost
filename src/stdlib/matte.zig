const std = @import("std");
const builtin = @import("builtin");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

var prng_state = std.Random.DefaultPrng.init(0);
var prng_seeded = false;

pub fn seed_prng(s: u64) void {
    prng_state = std.Random.DefaultPrng.init(s);
    prng_seeded = true;
}

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "abs", .value = .{ .builtin_fn = abs } },
        .{ .name = "maks", .value = .{ .builtin_fn = maks } },
        .{ .name = "min", .value = .{ .builtin_fn = min } },
        .{ .name = "tilfeldig", .value = .{ .builtin_fn = tilfeldig } },
        .{ .name = "modulus", .value = .{ .builtin_fn = modulus } },
    });
    return Value{ .module = members };
}

fn abs(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    return switch (args[0]) {
        .integer => |n| Value{ .integer = if (n < 0) -n else n },
        .float => |n| Value{ .float = @abs(n) },
        else => EvalError.TypeError,
    };
}

fn maks(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const has_float = (args[0] == .float or args[1] == .float);
    if (has_float) {
        const a = try args[0].as_float();
        const b = try args[1].as_float();
        return Value{ .float = if (a > b) a else b };
    }
    const a = try args[0].as_int();
    const b = try args[1].as_int();
    return Value{ .integer = if (a > b) a else b };
}

fn min(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const has_float = (args[0] == .float or args[1] == .float);
    if (has_float) {
        const a = try args[0].as_float();
        const b = try args[1].as_float();
        return Value{ .float = if (a < b) a else b };
    }
    const a = try args[0].as_int();
    const b = try args[1].as_int();
    return Value{ .integer = if (a < b) a else b };
}

fn tilfeldig(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len > 2) return EvalError.TypeError;
    const minVal = if (args.len > 0) try args[0].as_int() else std.math.minInt(i64);
    const maxVal = if (args.len > 1) try args[1].as_int() else std.math.maxInt(i64);
    if (!prng_seeded and builtin.cpu.arch != .wasm32) {
        var seed_bytes: [8]u8 = undefined;
        interp.io.randomSecure(&seed_bytes) catch {};
        const seed = std.mem.readInt(u64, &seed_bytes, .little);
        prng_state = std.Random.DefaultPrng.init(seed);
        prng_seeded = true;
    }
    const result = prng_state.random().intRangeAtMost(i64, minVal, maxVal);
    return Value{ .integer = result };
}

fn modulus(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const firstArg = try args[0].as_int();
    const secondArg = try args[1].as_int();
    return Value{ .integer = @rem(firstArg, secondArg) };
}
