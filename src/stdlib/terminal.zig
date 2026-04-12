const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "skriv",    .value = .{ .builtin_fn = skriv } },
        .{ .name = "tøm",      .value = .{ .builtin_fn = toem } },
        .{ .name = "argument", .value = .{ .builtin_fn = argument } },
    });
    return Value{ .module = members };
}

fn skriv(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const str = try args[0].to_string(interp.str_alloc());
    interp.output.print("{s}\n", .{str}) catch return EvalError.OutOfMemory;
    return Value{ .null_val = {} };
}

fn toem(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 0) return EvalError.TypeError;
    interp.output.print("\x1B[2J\x1B[H", .{}) catch return EvalError.OutOfMemory;
    return Value{ .null_val = {} };
}

fn argument(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const idx = try args[0].as_int();
    if (idx < 0 or idx >= interp.script_args.len) return EvalError.IndexOutOfBounds;
    return Value{ .string = interp.script_args[@intCast(idx)] };
}
