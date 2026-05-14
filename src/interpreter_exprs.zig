const std = @import("std");
const ast = @import("ast.zig");
const interp_mod = @import("interpreter.zig");
const Interpreter = interp_mod.Interpreter;
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Environment = interp_mod.Environment;
const Function = interp_mod.Function;
const StructInstance = interp_mod.StructInstance;

pub fn eval_list(self: *Interpreter, l: ast.ListLit, env: *Environment) EvalError!Value {
    var items: std.ArrayList(Value) = .empty;
    for (l.elements) |elem| {
        const v = try self.eval(elem, env);
        items.append(self.str_alloc(), v) catch return EvalError.OutOfMemory;
    }
    const slice = items.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory;
    return Value{ .list = .{ .items = slice, .cap = slice.len } };
}

pub fn eval_hashmap(self: *Interpreter, h: ast.HashmapLit, env: *Environment) EvalError!Value {
    const map = self.str_alloc().create(std.StringHashMapUnmanaged(Value)) catch return EvalError.OutOfMemory;
    map.* = .{};
    for (h.pairs) |pair| {
        const k = try self.eval(pair.key, env);
        const key = try k.as_str();
        const value = try self.eval(pair.value, env);
        map.put(self.str_alloc(), key, value) catch return EvalError.OutOfMemory;
    }
    return Value{ .hashmap = map };
}

pub fn eval_identifier(self: *Interpreter, i: ast.Identifier, env: *Environment) EvalError!Value {
    if (env.get(i.name)) |entry| return entry.value;
    self.last_undefined_name = i.name;
    return EvalError.UndefinedVariable;
}

pub fn eval_infix(self: *Interpreter, expr: ast.InfixExpr, env: *Environment) EvalError!Value {
    if (std.mem.eql(u8, expr.op, "og")) {
        const left = try self.eval(expr.left, env);
        if (!left.is_truthy()) return Value{ .boolean = false };
        const right = try self.eval(expr.right, env);
        return Value{ .boolean = right.is_truthy() };
    }
    if (std.mem.eql(u8, expr.op, "eller")) {
        const left = try self.eval(expr.left, env);
        if (left.is_truthy()) return Value{ .boolean = true };
        const right = try self.eval(expr.right, env);
        return Value{ .boolean = right.is_truthy() };
    }

    const left = try self.eval(expr.left, env);
    const right = try self.eval(expr.right, env);
    if (std.mem.eql(u8, expr.op, "er") or std.mem.eql(u8, expr.op, "erSameSom")) {
        return Value{ .boolean = left.equals(right) };
    }
    if (std.mem.eql(u8, expr.op, "+")) {
        switch (left) {
            .integer => |a| switch (right) {
                .integer => |b| return Value{ .integer = a + b },
                .float => |b| return Value{ .float = @as(f64, @floatFromInt(a)) + b },
                .string => |b| {
                    const a_str = try left.to_string(self.str_alloc());
                    const s = std.fmt.allocPrint(self.str_alloc(), "{s}{s}", .{ a_str, b }) catch return EvalError.OutOfMemory;
                    return Value{ .string = s };
                },
                else => return EvalError.TypeError,
            },
            .float => |a| switch (right) {
                .float => |b| return Value{ .float = a + b },
                .integer => |b| return Value{ .float = a + @as(f64, @floatFromInt(b)) },
                else => return EvalError.TypeError,
            },
            .string => |a| {
                const b_str = try right.to_string(self.str_alloc());
                const s = std.fmt.allocPrint(self.str_alloc(), "{s}{s}", .{ a, b_str }) catch return EvalError.OutOfMemory;
                return Value{ .string = s };
            },
            else => return EvalError.TypeError,
        }
    }
    const both_numeric = switch (left) {
        .integer, .float => switch (right) {
            .integer, .float => true,
            else => false,
        },
        else => false,
    };
    if (!both_numeric) return EvalError.TypeError;
    const has_float = (left == .float or right == .float);
    if (has_float) {
        const a = try left.as_float();
        const b = try right.as_float();
        if (std.mem.eql(u8, expr.op, "-")) return Value{ .float = a - b };
        if (std.mem.eql(u8, expr.op, "*")) return Value{ .float = a * b };
        if (std.mem.eql(u8, expr.op, "/")) {
            if (b == 0.0) return EvalError.DivisionByZero;
            return Value{ .float = a / b };
        }
        if (std.mem.eql(u8, expr.op, "<")) return Value{ .boolean = a < b };
        if (std.mem.eql(u8, expr.op, ">")) return Value{ .boolean = a > b };
        if (std.mem.eql(u8, expr.op, "<=")) return Value{ .boolean = a <= b };
        if (std.mem.eql(u8, expr.op, ">=")) return Value{ .boolean = a >= b };
        return EvalError.TypeError;
    }
    const a = left.integer;
    const b = right.integer;
    if (std.mem.eql(u8, expr.op, "-")) return Value{ .integer = a - b };
    if (std.mem.eql(u8, expr.op, "*")) return Value{ .integer = a * b };
    if (std.mem.eql(u8, expr.op, "/")) {
        if (b == 0) return EvalError.DivisionByZero;
        return Value{ .integer = @divTrunc(a, b) };
    }
    if (std.mem.eql(u8, expr.op, "<")) return Value{ .boolean = a < b };
    if (std.mem.eql(u8, expr.op, ">")) return Value{ .boolean = a > b };
    if (std.mem.eql(u8, expr.op, "<=")) return Value{ .boolean = a <= b };
    if (std.mem.eql(u8, expr.op, ">=")) return Value{ .boolean = a >= b };
    return EvalError.TypeError;
}

pub fn eval_prefix(self: *Interpreter, expr: ast.PrefixExpr, env: *Environment) EvalError!Value {
    const right = try self.eval(expr.right, env);
    if (std.mem.eql(u8, expr.op, "!")) {
        return Value{ .boolean = !right.is_truthy() };
    }
    if (std.mem.eql(u8, expr.op, "-")) {
        switch (right) {
            .integer => |n| return Value{ .integer = -n },
            .float => |n| return Value{ .float = -n },
            else => return EvalError.TypeError,
        }
    }
    return EvalError.TypeError;
}

fn call_function(self: *Interpreter, func: Function, args: []const Value) EvalError!Value {
    if (args.len != func.params.len) return EvalError.TypeError;
    var call_env = Environment.init(self.alloc, func.env);
    defer call_env.deinit();
    for (func.params, args) |param, arg_val| {
        try call_env.define(param, .{ .value = arg_val, .mutable = false });
    }
    const result = try self.eval(func.body, &call_env);
    if (self.signal) |sig| {
        switch (sig) {
            .return_val => |v| {
                self.signal = null;
                return v;
            },
            .break_loop, .continue_loop => self.signal = null,
            else => {},
        }
    }
    if (func.implicit_return) return result;
    return Value{ .null_val = {} };
}

pub fn call_callable(self: *Interpreter, callable: Value, args: []const Value) EvalError!Value {
    return switch (callable) {
        .builtin_fn => |f| try f(args, self),
        .function => |f| try call_function(self, f, args),
        else => EvalError.TypeError,
    };
}

pub fn eval_call(self: *Interpreter, expr: ast.CallExpr, env: *Environment) EvalError!Value {
    const callee_val = try self.eval(expr.callee, env);
    const fn_name = switch (expr.callee.*) {
        .identifier => |id| id.name,
        else => "<uttrykk>",
    };
    var args_buf: [16]Value = undefined;
    const args_slice: []Value = if (expr.args.len <= args_buf.len) blk: {
        for (expr.args, 0..) |arg_node, ai| {
            args_buf[ai] = try self.eval(arg_node, env);
        }
        break :blk args_buf[0..expr.args.len];
    } else blk: {
        var args_list: std.ArrayList(Value) = .empty;
        for (expr.args) |arg_node| {
            const v = try self.eval(arg_node, env);
            args_list.append(self.str_alloc(), v) catch return EvalError.OutOfMemory;
        }
        break :blk args_list.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory;
    };
    if (self.debug) {
        self.dbg("kall '{s}' ({d} arg(ar)):", .{ fn_name, args_slice.len });
        for (args_slice, 0..) |arg, i| {
            self.dbg("  arg[{d}] = {s}", .{ i, self.dbg_val(arg) });
        }
    }
    const result = try call_callable(self, callee_val, args_slice);
    if (self.debug and self.signal == null) {
        self.dbg("  '{s}' returnerte {s}", .{ fn_name, self.dbg_val(result) });
    }
    return result;
}

pub fn eval_struct_decl(self: *Interpreter, decl: ast.StructDecl, env: *Environment) EvalError!Value {
    const fields = self.str_alloc().dupe(ast.StructFieldDecl, decl.fields) catch return EvalError.OutOfMemory;
    try env.define(decl.name, .{
        .value = .{ .struct_type = .{ .name = decl.name, .fields = fields } },
        .mutable = false,
    });
    return .{ .null_val = {} };
}

pub fn eval_struct_lit(self: *Interpreter, lit: ast.StructLit, env: *Environment) EvalError!Value {
    const entry = env.get(lit.type_name) orelse {
        self.last_undefined_name = lit.type_name;
        return EvalError.UndefinedVariable;
    };
    const schema = switch (entry.value) {
        .struct_type => |t| t,
        else => return EvalError.NotAStructType,
    };
    const instance = self.str_alloc().create(StructInstance) catch return EvalError.OutOfMemory;
    const fields = self.str_alloc().alloc(interp_mod.StructFieldEntry, schema.fields.len) catch return EvalError.OutOfMemory;
    for (schema.fields, 0..) |fd, i| {
        var found: ?Value = null;
        for (lit.fields) |lf| {
            if (std.mem.eql(u8, lf.name, fd.name)) {
                found = try self.eval(lf.value, env);
                break;
            }
        }
        const val = if (found) |v|
            v
        else if (fd.default_value) |dv|
            try self.eval(dv, env)
        else
            return EvalError.UndefinedField;
        fields[i] = .{ .name = fd.name, .value = val, .mutable = fd.mutable };
    }
    instance.* = .{ .type_name = schema.name, .fields = fields };
    return .{ .struct_instance = instance };
}

pub fn eval_field_access(self: *Interpreter, access: ast.FieldAccess, env: *Environment) EvalError!Value {
    const obj_entry = env.get(access.object) orelse {
        self.last_undefined_name = access.object;
        return EvalError.UndefinedVariable;
    };
    const instance = switch (obj_entry.value) {
        .struct_instance => |s| s,
        else => return EvalError.TypeError,
    };
    for (instance.fields) |f| {
        if (std.mem.eql(u8, f.name, access.field)) return f.value;
    }
    return EvalError.UndefinedField;
}

pub fn eval_field_assign(self: *Interpreter, a: ast.FieldAssign, env: *Environment) EvalError!Value {
    const obj_entry = env.get(a.object) orelse {
        self.last_undefined_name = a.object;
        return EvalError.UndefinedVariable;
    };
    const instance = switch (obj_entry.value) {
        .struct_instance => |s| s,
        else => return EvalError.TypeError,
    };
    const new_val = try self.eval(a.value, env);
    for (instance.fields) |*f| {
        if (std.mem.eql(u8, f.name, a.field)) {
            if (!f.mutable) return EvalError.ImmutableField;
            f.value = new_val;
            return .{ .null_val = {} };
        }
    }
    return EvalError.UndefinedField;
}

pub fn eval_member_call(self: *Interpreter, expr: ast.MemberCall, env: *Environment) EvalError!Value {
    const entry = env.get(expr.object) orelse {
        self.last_undefined_name = expr.object;
        return EvalError.UndefinedVariable;
    };
    const members = switch (entry.value) {
        .module => |m| m,
        else => return EvalError.TypeError,
    };
    const member_val = for (members) |m| {
        if (std.mem.eql(u8, m.name, expr.member)) break m.value;
    } else {
        self.last_undefined_name = expr.member;
        return EvalError.UndefinedVariable;
    };
    var args_buf: [16]Value = undefined;
    const args_slice: []Value = if (expr.args.len <= args_buf.len) blk: {
        for (expr.args, 0..) |arg_node, ai| {
            args_buf[ai] = try self.eval(arg_node, env);
        }
        break :blk args_buf[0..expr.args.len];
    } else blk: {
        var args_list: std.ArrayList(Value) = .empty;
        for (expr.args) |arg_node| {
            const v = try self.eval(arg_node, env);
            args_list.append(self.str_alloc(), v) catch return EvalError.OutOfMemory;
        }
        break :blk args_list.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory;
    };
    if (self.debug) {
        self.dbg("kall '{s}'.'{s}' ({d} arg(ar)):", .{ expr.object, expr.member, args_slice.len });
        for (args_slice, 0..) |arg, i| {
            self.dbg("  arg[{d}] = {s}", .{ i, self.dbg_val(arg) });
        }
    }
    const result = try call_callable(self, member_val, args_slice);
    if (self.debug) self.dbg("  → {s}", .{self.dbg_val(result)});
    return result;
}

pub fn eval_lambda_expr(_: *Interpreter, l: ast.LambdaExpr, env: *Environment) EvalError!Value {
    return Value{ .function = .{
        .params = l.params,
        .body = l.body,
        .env = env,
        .implicit_return = true,
    } };
}
