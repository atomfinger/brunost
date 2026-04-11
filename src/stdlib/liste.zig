const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "lengd",   .value = .{ .builtin_fn = lengd } },
        .{ .name = "leggTil", .value = .{ .builtin_fn = legg_til } },
        .{ .name = "fyrste",  .value = .{ .builtin_fn = fyrste } },
        .{ .name = "siste",   .value = .{ .builtin_fn = siste } },
    });
    return Value{ .module = members };
}

fn lengd(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    return Value{ .integer = @intCast((try args[0].as_list()).len) };
}

fn legg_til(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const l = try args[0].as_list();
    const new_list = interp.str_alloc().alloc(Value, l.len + 1) catch return EvalError.OutOfMemory;
    @memcpy(new_list[0..l.len], l);
    new_list[l.len] = args[1];
    return Value{ .list = new_list };
}

fn fyrste(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const l = try args[0].as_list();
    if (l.len == 0) return EvalError.IndexOutOfBounds;
    return l[0];
}

fn siste(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const l = try args[0].as_list();
    if (l.len == 0) return EvalError.IndexOutOfBounds;
    return l[l.len - 1];
}
