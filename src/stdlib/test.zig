const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;
const Signal = interp_mod.Signal;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "krev", .value = .{ .builtin_fn = krev } },
    });
    return Value{ .module = members };
}

fn krev(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len < 1 or args.len > 2) return EvalError.TypeError;
    if (!args[0].is_truthy()) {
        const msg: Value = if (args.len == 2)
            args[1]
        else
            Value{ .string = "Assertion failed" };
        interp.signal = Signal{ .thrown = msg };
    }
    return Value{ .null_val = {} };
}
