const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "skriv", .value = .{ .builtin_fn = skriv } },
    });
    return Value{ .module = members };
}

fn skriv(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const str = try args[0].to_string(interp.str_alloc());
    interp.output.print("{s}\n", .{str}) catch return EvalError.OutOfMemory;
    return Value{ .null_val = {} };
}
