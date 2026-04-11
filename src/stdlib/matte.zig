const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "abs",  .value = .{ .builtin_fn = abs } },
        .{ .name = "maks", .value = .{ .builtin_fn = maks } },
        .{ .name = "min",  .value = .{ .builtin_fn = min } },
        .{ .name = "tilfeldig", .value = .{ .builtin_fn = tilfeldig } },
    });
    return Value{ .module = members };
}

fn abs(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const n = try args[0].as_int();
    return Value{ .integer = if (n < 0) -n else n };
}

fn maks(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const a = try args[0].as_int();
    const b = try args[1].as_int();
    return Value{ .integer = if (a > b) a else b };
}

fn min(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const a = try args[0].as_int();
    const b = try args[1].as_int();
    return Value{ .integer = if (a < b) a else b };
}

fn tilfeldig(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len > 2) return EvalError.TypeError;
    const minVal = if (args.len > 0) try args[0].as_int() else std.math.minInt(i64);
    const maxVal = if (args.len > 1) try args[1].as_int() else std.math.maxInt(i64);
    const rand = std.crypto.random;
    const result = rand.intRangeAtMost(i64, minVal, maxVal);
    return Value{ .integer = result };
}
