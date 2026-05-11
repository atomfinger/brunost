const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "lengd", .value = .{ .builtin_fn = lengd } },
        .{ .name = "leggTil", .value = .{ .builtin_fn = legg_til } },
        .{ .name = "fyrste", .value = .{ .builtin_fn = fyrste } },
        .{ .name = "siste", .value = .{ .builtin_fn = siste } },
        .{ .name = "hent", .value = .{ .builtin_fn = hent } },
        .{ .name = "oppdater", .value = .{ .builtin_fn = oppdater } },
        .{ .name = "ta", .value = .{ .builtin_fn = ta } },
        .{ .name = "inneheld", .value = .{ .builtin_fn = inneheld } },
        .{ .name = "finn", .value = .{ .builtin_fn = finn } },
        .{ .name = "alle", .value = .{ .builtin_fn = alle } },
        .{ .name = "gjerOm", .value = .{ .builtin_fn = gjer_om } },
        .{ .name = "filtrer", .value = .{ .builtin_fn = filtrer } },
        .{ .name = "reduser", .value = .{ .builtin_fn = reduser } },
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

fn ta(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const list = try args[0].as_list();
    const count = try args[1].as_int();
    if (count < 0) return EvalError.IndexOutOfBounds;
    const take_len: usize = @min(list.len, @as(usize, @intCast(count)));
    const taken = interp.str_alloc().alloc(Value, take_len) catch return EvalError.OutOfMemory;
    @memcpy(taken, list[0..take_len]);
    return Value{ .list = .{ .items = taken, .cap = taken.len } };
}

fn inneheld(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const list = try args[0].as_list();
    for (list) |item| {
        const callback_args = [_]Value{item};
        const matched = try interp.call_callable(args[1], callback_args[0..]);
        if (interp.signal != null) return Value{ .null_val = {} };
        if (matched.is_truthy()) return Value{ .boolean = true };
    }
    return Value{ .boolean = false };
}

fn finn(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const list = try args[0].as_list();
    for (list) |item| {
        const callback_args = [_]Value{item};
        const matched = try interp.call_callable(args[1], callback_args[0..]);
        if (interp.signal != null) return Value{ .null_val = {} };
        if (matched.is_truthy()) return item;
    }
    return Value{ .null_val = {} };
}

fn alle(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const list = try args[0].as_list();
    for (list) |item| {
        const callback_args = [_]Value{item};
        const matched = try interp.call_callable(args[1], callback_args[0..]);
        if (interp.signal != null) return Value{ .null_val = {} };
        if (!matched.is_truthy()) return Value{ .boolean = false };
    }
    return Value{ .boolean = true };
}

fn gjer_om(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const list = try args[0].as_list();
    const mapped = interp.str_alloc().alloc(Value, list.len) catch return EvalError.OutOfMemory;
    for (list, 0..) |item, i| {
        const callback_args = [_]Value{item};
        mapped[i] = try interp.call_callable(args[1], callback_args[0..]);
        if (interp.signal != null) return Value{ .null_val = {} };
    }
    return Value{ .list = .{ .items = mapped, .cap = mapped.len } };
}

fn filtrer(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const list = try args[0].as_list();
    const kept = interp.str_alloc().alloc(Value, list.len) catch return EvalError.OutOfMemory;
    var count: usize = 0;
    for (list) |item| {
        const callback_args = [_]Value{item};
        const keep = try interp.call_callable(args[1], callback_args[0..]);
        if (interp.signal != null) return Value{ .null_val = {} };
        if (!keep.is_truthy()) continue;
        kept[count] = item;
        count += 1;
    }
    return Value{ .list = .{ .items = kept[0..count], .cap = kept.len } };
}

fn reduser(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 3) return EvalError.TypeError;
    const list = try args[0].as_list();
    var acc = args[1];
    for (list) |item| {
        const callback_args = [_]Value{ acc, item };
        acc = try interp.call_callable(args[2], callback_args[0..]);
        if (interp.signal != null) return Value{ .null_val = {} };
    }
    return acc;
}
