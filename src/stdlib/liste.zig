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
        .{ .name = "hent",    .value = .{ .builtin_fn = hent } },
        .{ .name = "oppdater",.value = .{ .builtin_fn = oppdater } },
    });
    return Value{ .module = members };
}

fn lengd(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    return Value{ .integer = @intCast((try args[0].as_list()).len) };
}

fn legg_til(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const bl = switch (args[0]) {
        .list => |l| l,
        else => return EvalError.TypeError,
    };
    const new_len = bl.items.len + 1;
    if (new_len <= bl.cap) {
        // Spare capacity in the arena-allocated buffer: extend in place.
        // The arena never reclaims memory, so bl.items.ptr[0..bl.cap] is permanently ours.
        const buf = bl.items.ptr[0..new_len];
        buf[bl.items.len] = args[1];
        return Value{ .list = .{ .items = buf, .cap = bl.cap } };
    }
    const new_cap = if (bl.cap == 0) @as(usize, 4) else bl.cap * 2;
    const new_buf = interp.str_alloc().alloc(Value, new_cap) catch return EvalError.OutOfMemory;
    @memcpy(new_buf[0..bl.items.len], bl.items);
    new_buf[bl.items.len] = args[1];
    return Value{ .list = .{ .items = new_buf[0..new_len], .cap = new_cap } };
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

fn hent(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const l = try args[0].as_list();
    const idx = try args[1].as_int();
    if (idx < 0 or idx >= l.len) return EvalError.IndexOutOfBounds;
    return l[@intCast(idx)];
}

fn oppdater(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 3) return EvalError.TypeError;
    const l = try args[0].as_list();
    const idx = try args[1].as_int();
    if (idx < 0 or idx >= l.len) return EvalError.IndexOutOfBounds;
    
    const new_list = interp.str_alloc().alloc(Value, l.len) catch return EvalError.OutOfMemory;
    @memcpy(new_list, l);
    new_list[@intCast(idx)] = args[2];
    return Value{ .list = .{ .items = new_list, .cap = new_list.len } };
}
