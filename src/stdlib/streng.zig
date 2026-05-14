const std = @import("std");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "lengd", .value = .{ .builtin_fn = lengd } },
        .{ .name = "tilTal", .value = .{ .builtin_fn = til_tal } },
        .{ .name = "reverser", .value = .{ .builtin_fn = reverser } },
        .{ .name = "inneheld", .value = .{ .builtin_fn = inneheld } },
        .{ .name = "del", .value = .{ .builtin_fn = del } },
        .{ .name = "trim", .value = .{ .builtin_fn = trim } },
        .{ .name = "tilStoreBokstavar", .value = .{ .builtin_fn = til_store_bokstavar } },
        .{ .name = "tilSmåBokstavar", .value = .{ .builtin_fn = til_sma_bokstavar } },
        .{ .name = "byt", .value = .{ .builtin_fn = byt } },
        .{ .name = "startarMed", .value = .{ .builtin_fn = startar_med } },
        .{ .name = "slutarMed", .value = .{ .builtin_fn = slutar_med } },
        .{ .name = "format", .value = .{ .builtin_fn = format } },
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
    const buf = try interp.str_alloc().dupe(u8, str);
    std.mem.reverse(u8, buf);
    return Value{ .string = buf };
}

fn inneheld(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const str = try args[0].as_str();
    const to_locate = try args[1].as_str();
    const found = std.mem.indexOf(u8, str, to_locate) != null;
    return Value{ .boolean = found };
}

fn del(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const str = try args[0].as_str();
    const sep = try args[1].as_str();
    const alloc = interp.str_alloc();

    var parts: std.ArrayList(Value) = .empty;
    if (sep.len == 0) {
        // Split into individual bytes (characters)
        for (str) |b| {
            const ch = alloc.dupe(u8, &[_]u8{b}) catch return EvalError.OutOfMemory;
            parts.append(alloc, Value{ .string = ch }) catch return EvalError.OutOfMemory;
        }
    } else {
        var rest = str;
        while (std.mem.indexOf(u8, rest, sep)) |idx| {
            const part = alloc.dupe(u8, rest[0..idx]) catch return EvalError.OutOfMemory;
            parts.append(alloc, Value{ .string = part }) catch return EvalError.OutOfMemory;
            rest = rest[idx + sep.len ..];
        }
        const last = alloc.dupe(u8, rest) catch return EvalError.OutOfMemory;
        parts.append(alloc, Value{ .string = last }) catch return EvalError.OutOfMemory;
    }
    const slice = parts.toOwnedSlice(alloc) catch return EvalError.OutOfMemory;
    return Value{ .list = .{ .items = slice, .cap = slice.len } };
}

fn trim(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const str = try args[0].as_str();
    const trimmed = std.mem.trim(u8, str, &std.ascii.whitespace);
    const buf = interp.str_alloc().dupe(u8, trimmed) catch return EvalError.OutOfMemory;
    return Value{ .string = buf };
}

// Byte-by-byte uppercase handling ASCII + Norwegian letters (æøå / ÆØÅ).
// Norwegian letters in UTF-8 are two-byte sequences with lead byte 0xC3.
fn til_store_bokstavar(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const str = try args[0].as_str();
    const alloc = interp.str_alloc();
    var buf: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < str.len) {
        const b = str[i];
        if (b == 0xC3 and i + 1 < str.len) {
            const b2 = str[i + 1];
            const upper: ?u8 = switch (b2) {
                0xA5 => 0x85, // å → Å
                0xA6 => 0x86, // æ → Æ
                0xB8 => 0x98, // ø → Ø
                else => null,
            };
            if (upper) |u| {
                buf.append(alloc, 0xC3) catch return EvalError.OutOfMemory;
                buf.append(alloc, u) catch return EvalError.OutOfMemory;
                i += 2;
                continue;
            }
        }
        buf.append(alloc, std.ascii.toUpper(b)) catch return EvalError.OutOfMemory;
        i += 1;
    }
    return Value{ .string = buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory };
}

fn til_sma_bokstavar(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const str = try args[0].as_str();
    const alloc = interp.str_alloc();
    var buf: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < str.len) {
        const b = str[i];
        if (b == 0xC3 and i + 1 < str.len) {
            const b2 = str[i + 1];
            const lower: ?u8 = switch (b2) {
                0x85 => 0xA5, // Å → å
                0x86 => 0xA6, // Æ → æ
                0x98 => 0xB8, // Ø → ø
                else => null,
            };
            if (lower) |l| {
                buf.append(alloc, 0xC3) catch return EvalError.OutOfMemory;
                buf.append(alloc, l) catch return EvalError.OutOfMemory;
                i += 2;
                continue;
            }
        }
        buf.append(alloc, std.ascii.toLower(b)) catch return EvalError.OutOfMemory;
        i += 1;
    }
    return Value{ .string = buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory };
}

fn byt(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 3) return EvalError.TypeError;
    const str = try args[0].as_str();
    const from = try args[1].as_str();
    const to = try args[2].as_str();
    if (from.len == 0) return Value{ .string = str };
    const alloc = interp.str_alloc();
    var buf: std.ArrayList(u8) = .empty;
    var rest = str;
    while (std.mem.indexOf(u8, rest, from)) |idx| {
        buf.appendSlice(alloc, rest[0..idx]) catch return EvalError.OutOfMemory;
        buf.appendSlice(alloc, to) catch return EvalError.OutOfMemory;
        rest = rest[idx + from.len ..];
    }
    buf.appendSlice(alloc, rest) catch return EvalError.OutOfMemory;
    return Value{ .string = buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory };
}

fn startar_med(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const str = try args[0].as_str();
    const prefix = try args[1].as_str();
    return Value{ .boolean = std.mem.startsWith(u8, str, prefix) };
}

fn slutar_med(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const str = try args[0].as_str();
    const suffix = try args[1].as_str();
    return Value{ .boolean = std.mem.endsWith(u8, str, suffix) };
}

fn format(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 2) return EvalError.TypeError;
    const template = try args[0].as_str();
    const map = try args[1].as_hashmap();
    const alloc = interp.str_alloc();
    var buf: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < template.len) {
        if (template[i] == '{') {
            const start = i + 1;
            var j = start;
            while (j < template.len and template[j] != '}') j += 1;
            if (j >= template.len) {
                buf.append(alloc, '{') catch return EvalError.OutOfMemory;
                i += 1;
                continue;
            }
            const key = template[start..j];
            if (map.get(key)) |val| {
                const s = try val.to_string(alloc);
                buf.appendSlice(alloc, s) catch return EvalError.OutOfMemory;
            } else {
                buf.append(alloc, '{') catch return EvalError.OutOfMemory;
                buf.appendSlice(alloc, key) catch return EvalError.OutOfMemory;
                buf.append(alloc, '}') catch return EvalError.OutOfMemory;
            }
            i = j + 1;
        } else {
            buf.append(alloc, template[i]) catch return EvalError.OutOfMemory;
            i += 1;
        }
    }
    return Value{ .string = buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory };
}
