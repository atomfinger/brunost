const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "lengd",  .value = .{ .builtin_fn = lengd } },
        .{ .name = "tilTal", .value = .{ .builtin_fn = til_tal } },
        .{ .name = "reverser", .value = .{ .builtin_fn = reverser } },
        .{ .name = "inneheld", .value = .{ .builtin_fn = inneheld } },
    });
    return Value{ .module = members };
}

fn lengd(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    return Value{ .integer = @intCast((try args[0].as_str()).len) };
}

fn til_tal(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const n = std.fmt.parseInt(i64, try args[0].as_str(), 10) catch return EvalError.TypeError;
    return Value{ .integer = n };
}

fn reverser(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const str = try args[0].as_str();
    const buf = try interp.str_arena.allocator().dupe(u8, str);
    std.mem.reverse(u8, buf);
    return Value{ .string = buf };
}

// TODO: In the future we may add a third optional argument that
// enables stuff like regex, ignoring case, etc, and it can be
// in the format of a Brunost type.
fn inneheld(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const str = try args[0].as_str();
    const to_locate = try args[1].as_str();
    const found = std.mem.indexOf(u8, str, to_locate) != null;
    return Value{ .boolean = found };
}
