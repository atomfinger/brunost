const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "sov", .value = .{ .builtin_fn = sov } },
    });
    return Value{ .module = members };
}

fn sov(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const ms = try args[0].as_int();
    if (ms > 0) {
        if (comptime @import("builtin").cpu.arch != .wasm32) {
            std.Thread.sleep(@intCast(ms * 1_000_000));
        }
    }
    return Value{ .null_val = {} };
}
