const std = @import("std");
const ast = @import("ast.zig");
const interp_mod = @import("interpreter.zig");
const Interpreter = interp_mod.Interpreter;
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Signal = interp_mod.Signal;
const Environment = interp_mod.Environment;
const Function = interp_mod.Function;

pub fn eval_program(self: *Interpreter, prog: ast.Program, env: *Environment) EvalError!Value {
    var result = Value{ .null_val = {} };
    for (prog.statements) |stmt| {
        result = try self.eval(stmt, env);
        if (self.signal != null) break;
    }
    return result;
}

pub fn eval_block(self: *Interpreter, block: ast.Block, env: *Environment) EvalError!Value {
    var result = Value{ .null_val = {} };
    for (block.statements) |stmt| {
        result = try self.eval(stmt, env);
        if (self.signal != null) break;
    }
    return result;
}

pub fn eval_var_decl(self: *Interpreter, decl: ast.VarDecl, env: *Environment) EvalError!Value {
    const value = try self.eval(decl.value, env);
    try env.define(decl.name, .{ .value = value, .mutable = decl.mutable });
    self.dbg("{s} '{s}' = {s}", .{ if (decl.mutable) "open" else "låst", decl.name, self.dbg_val(value) });
    return Value{ .null_val = {} };
}

pub fn eval_assign(self: *Interpreter, a: ast.AssignStmt, env: *Environment) EvalError!Value {
    const value = try self.eval(a.value, env);
    env.assign(a.name, value) catch |err| {
        if (err == EvalError.UndefinedVariable) self.last_undefined_name = a.name;
        return err;
    };
    self.dbg("set '{s}' = {s}", .{ a.name, self.dbg_val(value) });
    return Value{ .null_val = {} };
}

pub fn eval_return(self: *Interpreter, r: ast.ReturnStmt, env: *Environment) EvalError!Value {
    const value = try self.eval(r.value, env);
    self.dbg("gjevTilbake {s}", .{self.dbg_val(value)});
    self.signal = Signal{ .return_val = value };
    return Value{ .null_val = {} };
}

pub fn eval_throw(self: *Interpreter, t: ast.ThrowStmt, env: *Environment) EvalError!Value {
    const value = try self.eval(t.value, env);
    self.dbg("kast {s}", .{self.dbg_val(value)});
    self.signal = Signal{ .thrown = value };
    return Value{ .null_val = {} };
}

pub fn eval_fn_decl(self: *Interpreter, f: ast.FnDecl, env: *Environment) EvalError!Value {
    const func = Value{ .function = .{ .params = f.params, .body = f.body, .env = env, .implicit_return = false } };
    try env.define(f.name, .{ .value = func, .mutable = false });
    self.dbg("gjer '{s}' ({d} param(ar))", .{ f.name, f.params.len });
    return Value{ .null_val = {} };
}

pub fn eval_if(self: *Interpreter, stmt: ast.IfStmt, env: *Environment) EvalError!Value {
    const cond_val = try self.eval(stmt.condition, env);
    if (cond_val.is_truthy()) {
        self.dbg("viss: {s} → tek konsekvens", .{self.dbg_val(cond_val)});
        var child_env = Environment.init(self.alloc, env);
        defer child_env.deinit();
        return self.eval(stmt.consequence, &child_env);
    } else if (stmt.alternative) |alt| {
        self.dbg("viss: {s} → tek alternativ", .{self.dbg_val(cond_val)});
        var child_env = Environment.init(self.alloc, env);
        defer child_env.deinit();
        return self.eval(alt, &child_env);
    } else {
        self.dbg("viss: {s} → ingen alternativ", .{self.dbg_val(cond_val)});
    }
    return Value{ .null_val = {} };
}

pub fn eval_break(self: *Interpreter) EvalError!Value {
    self.signal = .{ .break_loop = {} };
    return Value{ .null_val = {} };
}

pub fn eval_continue(self: *Interpreter) EvalError!Value {
    self.signal = .{ .continue_loop = {} };
    return Value{ .null_val = {} };
}

pub fn eval_string_lit(self: *Interpreter, raw: []const u8) EvalError!Value {
    if (std.mem.indexOf(u8, raw, "\\") == null) return Value{ .string = raw };
    const alloc = self.str_alloc();
    var buf: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < raw.len) {
        if (raw[i] == '\\' and i + 1 < raw.len) {
            const c: u8 = switch (raw[i + 1]) {
                'n' => '\n',
                't' => '\t',
                'r' => '\r',
                '\\' => '\\',
                '"' => '"',
                else => {
                    buf.append(alloc, raw[i]) catch return EvalError.OutOfMemory;
                    i += 1;
                    continue;
                },
            };
            buf.append(alloc, c) catch return EvalError.OutOfMemory;
            i += 2;
        } else {
            buf.append(alloc, raw[i]) catch return EvalError.OutOfMemory;
            i += 1;
        }
    }
    return Value{ .string = buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory };
}

pub fn eval_index_expr(self: *Interpreter, expr: ast.IndexExpr, env: *Environment) EvalError!Value {
    const obj = try self.eval(expr.object, env);
    const index = try self.eval(expr.index, env);
    switch (obj) {
        .list => |bl| {
            const idx = try index.as_int();
            if (idx < 0 or idx >= bl.items.len) return EvalError.IndexOutOfBounds;
            return bl.items[@intCast(idx)];
        },
        .hashmap => |h| {
            const key = try index.as_str();
            return h.get(key) orelse EvalError.KeyNotFound;
        },
        else => return EvalError.TypeError,
    }
}

pub fn eval_while(self: *Interpreter, stmt: ast.WhileStmt, env: *Environment) EvalError!Value {
    var iteration: usize = 0;
    while (true) {
        const cond_val = try self.eval(stmt.condition, env);
        if (!cond_val.is_truthy()) break;
        self.dbg("medan: iterasjon {d}", .{iteration});
        iteration += 1;
        var child_env = Environment.init(self.alloc, env);
        defer child_env.deinit();
        _ = try self.eval(stmt.body, &child_env);
        if (self.signal) |sig| switch (sig) {
            .break_loop => { self.signal = null; break; },
            .continue_loop => { self.signal = null; continue; },
            else => break,
        };
    }
    return Value{ .null_val = {} };
}

pub fn eval_foreach(self: *Interpreter, stmt: ast.ForeachStmt, env: *Environment) EvalError!Value {
    const iter_val = try self.eval(stmt.iterable, env);
    switch (iter_val) {
        .list => |bl| {
            self.dbg("forKvart '{s}': {d} element(ar)", .{ stmt.iterator_name, bl.items.len });
            for (bl.items, 0..) |item, i| {
                self.dbg("  element {d}: {s}", .{ i, self.dbg_val(item) });
                var child_env = Environment.init(self.alloc, env);
                defer child_env.deinit();
                try child_env.define(stmt.iterator_name, .{ .value = item, .mutable = false });
                _ = try self.eval(stmt.body, &child_env);
                if (self.signal) |sig| switch (sig) {
                    .break_loop => { self.signal = null; break; },
                    .continue_loop => { self.signal = null; continue; },
                    else => break,
                };
            }
        },
        else => return EvalError.TypeError,
    }
    return Value{ .null_val = {} };
}

pub fn eval_try(self: *Interpreter, stmt: ast.TryStmt, env: *Environment) EvalError!Value {
    var try_env = Environment.init(self.alloc, env);
    defer try_env.deinit();

    const ErrorKind = union(enum) {
        eval_err: EvalError,
        thrown: Value,
    };

    var caught_error: ?ErrorKind = null;
    _ = self.eval(stmt.body, &try_env) catch |err| {
        caught_error = .{ .eval_err = err };
    };
    if (caught_error == null) {
        if (self.signal) |sig| switch (sig) {
            .thrown => |v| {
                self.signal = null;
                caught_error = .{ .thrown = v };
            },
            else => {},
        };
    }

    var result: Value = .{ .null_val = {} };
    if (caught_error != null and stmt.catch_body != null) {
        const err_val: Value = switch (caught_error.?) {
            .eval_err => |e| blk: {
                const s = std.fmt.allocPrint(self.str_alloc(), "{s}", .{@errorName(e)}) catch return EvalError.OutOfMemory;
                break :blk Value{ .string = s };
            },
            .thrown => |v| v,
        };
        caught_error = null;
        var catch_env = Environment.init(self.alloc, env);
        defer catch_env.deinit();
        try catch_env.define(stmt.error_name, .{ .value = err_val, .mutable = false });
        result = try self.eval(stmt.catch_body.?, &catch_env);
    }

    if (stmt.finally_body) |finally_node| {
        const saved_signal = self.signal;
        self.signal = null;
        var finally_env = Environment.init(self.alloc, env);
        defer finally_env.deinit();
        _ = self.eval(finally_node, &finally_env) catch |err| {
            return err;
        };
        if (self.signal != null) {
            return Value{ .null_val = {} };
        }
        self.signal = saved_signal;
    }

    if (caught_error) |ek| switch (ek) {
        .eval_err => |e| return e,
        .thrown => |v| {
            self.signal = Signal{ .thrown = v };
            return Value{ .null_val = {} };
        },
    };

    return result;
}
