const std = @import("std");
const ast = @import("ast.zig");

pub const EvalError = error{
    TypeError,
    UndefinedVariable,
    ImmutableAssignment,
    DivisionByZero,
    IndexOutOfBounds,
    UnknownBuiltin,
    OutOfMemory,
};

pub const Signal = union(enum) {
    return_val: Value,
    thrown: Value,
};

pub const Function = struct {
    params: [][]const u8,
    body: *ast.Node, // Block
    env: *Environment,
};

pub const Value = union(enum) {
    integer: i64,
    string: []const u8,
    boolean: bool,
    list: []Value,
    function: Function,
    null_val: void,

    pub fn is_truthy(self: Value) bool {
        return switch (self) {
            .boolean => |b| b,
            .integer => |n| n != 0,
            .string => |s| s.len > 0,
            .list => |l| l.len > 0,
            .null_val => false,
            .function => true,
        };
    }

    pub fn equals(self: Value, other: Value) bool {
        return switch (self) {
            .integer => |a| switch (other) {
                .integer => |b| a == b,
                else => false,
            },
            .boolean => |a| switch (other) {
                .boolean => |b| a == b,
                else => false,
            },
            .string => |a| switch (other) {
                .string => |b| std.mem.eql(u8, a, b),
                else => false,
            },
            .null_val => switch (other) {
                .null_val => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn to_string(self: Value, alloc: std.mem.Allocator) EvalError![]const u8 {
        return switch (self) {
            .integer => |n| std.fmt.allocPrint(alloc, "{d}", .{n}) catch return EvalError.OutOfMemory,
            .string => |s| s,
            .boolean => |b| if (b) "sant" else "usant",
            .null_val => "inkje",
            .list => |l| blk: {
                var buf: std.ArrayList(u8) = .{};
                buf.append(alloc, '[') catch return EvalError.OutOfMemory;
                for (l, 0..) |elem, idx| {
                    const s = try elem.to_string(alloc);
                    buf.appendSlice(alloc, s) catch return EvalError.OutOfMemory;
                    if (idx + 1 < l.len) buf.appendSlice(alloc, ", ") catch return EvalError.OutOfMemory;
                }
                buf.append(alloc, ']') catch return EvalError.OutOfMemory;
                break :blk buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory;
            },
            .function => "<funksjon>",
        };
    }
};

pub const EnvEntry = struct {
    value: Value,
    mutable: bool,
};

pub const Environment = struct {
    store: std.StringHashMap(EnvEntry),
    parent: ?*Environment,

    pub fn init(alloc: std.mem.Allocator, parent: ?*Environment) Environment {
        return .{
            .store = std.StringHashMap(EnvEntry).init(alloc),
            .parent = parent,
        };
    }

    pub fn deinit(self: *Environment) void {
        self.store.deinit();
    }

    pub fn get(self: *Environment, name: []const u8) ?EnvEntry {
        if (self.store.get(name)) |entry| return entry;
        if (self.parent) |p| return p.get(name);
        return null;
    }

    pub fn define(self: *Environment, name: []const u8, entry: EnvEntry) EvalError!void {
        self.store.put(name, entry) catch return EvalError.OutOfMemory;
    }

    pub fn assign(self: *Environment, name: []const u8, value: Value) EvalError!void {
        if (self.store.getPtr(name)) |entry| {
            if (!entry.mutable) return EvalError.ImmutableAssignment;
            entry.value = value;
            return;
        }
        if (self.parent) |p| return p.assign(name, value);
        return EvalError.UndefinedVariable;
    }
};

pub const Interpreter = struct {
    alloc: std.mem.Allocator,
    /// Arena for all runtime-allocated strings (to_string results, concatenations).
    /// Freed all at once in deinit(), avoiding per-string tracking.
    str_arena: std.heap.ArenaAllocator,
    global: Environment,
    signal: ?Signal,
    output: std.io.AnyWriter,

    pub fn init(alloc: std.mem.Allocator, output: std.io.AnyWriter) Interpreter {
        return .{
            .alloc = alloc,
            .str_arena = std.heap.ArenaAllocator.init(alloc),
            .global = Environment.init(alloc, null),
            .signal = null,
            .output = output,
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.global.deinit();
        self.str_arena.deinit();
    }

    fn str_alloc(self: *Interpreter) std.mem.Allocator {
        return self.str_arena.allocator();
    }

    pub fn eval(self: *Interpreter, node: *ast.Node, env: *Environment) EvalError!Value {
        return switch (node.*) {
            .program => |p| self.eval_program(p, env),
            .block => |b| self.eval_block(b, env),
            .var_decl => |d| self.eval_var_decl(d, env),
            .assign_stmt => |a| self.eval_assign(a, env),
            .return_stmt => |r| self.eval_return(r, env),
            .throw_stmt => |t| self.eval_throw(t, env),
            .expr_stmt => |e| self.eval(e.expr, env),
            .fn_decl => |f| self.eval_fn_decl(f, env),
            .if_stmt => |i| self.eval_if(i, env),
            .while_stmt => |w| self.eval_while(w, env),
            .foreach_stmt => |f| self.eval_foreach(f, env),
            .try_stmt => |t| self.eval_try(t, env),
            .integer_lit => |i| Value{ .integer = i.value },
            .string_lit => |s| Value{ .string = s.value },
            .bool_lit => |b| Value{ .boolean = b.value },
            .list_lit => |l| self.eval_list(l, env),
            .identifier => |i| self.eval_identifier(i, env),
            .infix_expr => |i| self.eval_infix(i, env),
            .prefix_expr => |p| self.eval_prefix(p, env),
            .call_expr => |c| self.eval_call(c, env),
            .member_call => |m| self.eval_member_call(m, env),
        };
    }

    fn eval_program(self: *Interpreter, prog: ast.Program, env: *Environment) EvalError!Value {
        var result = Value{ .null_val = {} };
        for (prog.statements) |stmt| {
            result = try self.eval(stmt, env);
            if (self.signal != null) break;
        }
        return result;
    }

    fn eval_block(self: *Interpreter, block: ast.Block, env: *Environment) EvalError!Value {
        var result = Value{ .null_val = {} };
        for (block.statements) |stmt| {
            result = try self.eval(stmt, env);
            if (self.signal != null) break;
        }
        return result;
    }

    fn eval_var_decl(self: *Interpreter, decl: ast.VarDecl, env: *Environment) EvalError!Value {
        const value = try self.eval(decl.value, env);
        try env.define(decl.name, .{ .value = value, .mutable = decl.mutable });
        return Value{ .null_val = {} };
    }

    fn eval_assign(self: *Interpreter, a: ast.AssignStmt, env: *Environment) EvalError!Value {
        const value = try self.eval(a.value, env);
        try env.assign(a.name, value);
        return Value{ .null_val = {} };
    }

    fn eval_return(self: *Interpreter, r: ast.ReturnStmt, env: *Environment) EvalError!Value {
        const value = try self.eval(r.value, env);
        self.signal = Signal{ .return_val = value };
        return Value{ .null_val = {} };
    }

    fn eval_throw(self: *Interpreter, t: ast.ThrowStmt, env: *Environment) EvalError!Value {
        const value = try self.eval(t.value, env);
        self.signal = Signal{ .thrown = value };
        return Value{ .null_val = {} };
    }

    fn eval_fn_decl(_: *Interpreter, f: ast.FnDecl, env: *Environment) EvalError!Value {
        const func = Value{ .function = .{ .params = f.params, .body = f.body, .env = env } };
        try env.define(f.name, .{ .value = func, .mutable = false });
        return Value{ .null_val = {} };
    }

    fn eval_if(self: *Interpreter, stmt: ast.IfStmt, env: *Environment) EvalError!Value {
        const cond_val = try self.eval(stmt.condition, env);
        const cond_bool = cond_val.is_truthy();
        const take_branch = cond_bool == stmt.expected;
        if (take_branch) {
            var child_env = Environment.init(self.alloc, env);
            defer child_env.deinit();
            return self.eval(stmt.consequence, &child_env);
        } else if (stmt.alternative) |alt| {
            var child_env = Environment.init(self.alloc, env);
            defer child_env.deinit();
            return self.eval(alt, &child_env);
        }
        return Value{ .null_val = {} };
    }

    fn eval_while(self: *Interpreter, stmt: ast.WhileStmt, env: *Environment) EvalError!Value {
        while (true) {
            const cond_val = try self.eval(stmt.condition, env);
            const cond_bool = cond_val.is_truthy();
            if (cond_bool != stmt.expected) break;
            var child_env = Environment.init(self.alloc, env);
            defer child_env.deinit();
            _ = try self.eval(stmt.body, &child_env);
            if (self.signal != null) break;
        }
        return Value{ .null_val = {} };
    }

    fn eval_foreach(self: *Interpreter, stmt: ast.ForeachStmt, env: *Environment) EvalError!Value {
        const iter_val = try self.eval(stmt.iterable, env);
        switch (iter_val) {
            .list => |items| {
                for (items) |item| {
                    var child_env = Environment.init(self.alloc, env);
                    defer child_env.deinit();
                    try child_env.define(stmt.iterator_name, .{ .value = item, .mutable = false });
                    _ = try self.eval(stmt.body, &child_env);
                    if (self.signal != null) break;
                }
            },
            else => return EvalError.TypeError,
        }
        return Value{ .null_val = {} };
    }

    fn eval_try(self: *Interpreter, stmt: ast.TryStmt, env: *Environment) EvalError!Value {
        var try_env = Environment.init(self.alloc, env);
        defer try_env.deinit();
        _ = try self.eval(stmt.body, &try_env);
        if (self.signal) |sig| {
            switch (sig) {
                .thrown => |err_val| {
                    self.signal = null;
                    var catch_env = Environment.init(self.alloc, env);
                    defer catch_env.deinit();
                    try catch_env.define(stmt.error_name, .{ .value = err_val, .mutable = false });
                    return self.eval(stmt.catch_body, &catch_env);
                },
                else => {}, // return signal propagates
            }
        }
        return Value{ .null_val = {} };
    }

    fn eval_list(self: *Interpreter, l: ast.ListLit, env: *Environment) EvalError!Value {
        var items: std.ArrayList(Value) = .{};
        for (l.elements) |elem| {
            const v = try self.eval(elem, env);
            items.append(self.str_alloc(), v) catch return EvalError.OutOfMemory;
        }
        return Value{ .list = items.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory };
    }

    fn eval_identifier(_: *Interpreter, i: ast.Identifier, env: *Environment) EvalError!Value {
        if (env.get(i.name)) |entry| return entry.value;
        return EvalError.UndefinedVariable;
    }

    fn eval_infix(self: *Interpreter, expr: ast.InfixExpr, env: *Environment) EvalError!Value {
        const left = try self.eval(expr.left, env);
        const right = try self.eval(expr.right, env);
        if (std.mem.eql(u8, expr.op, "er") or std.mem.eql(u8, expr.op, "erSameSom")) {
            return Value{ .boolean = left.equals(right) };
        }
        if (std.mem.eql(u8, expr.op, "+")) {
            switch (left) {
                .integer => |a| switch (right) {
                    .integer => |b| return Value{ .integer = a + b },
                    else => return EvalError.TypeError,
                },
                .string => |a| switch (right) {
                    .string => |b| {
                        const s = std.fmt.allocPrint(self.str_alloc(), "{s}{s}", .{ a, b }) catch return EvalError.OutOfMemory;
                        return Value{ .string = s };
                    },
                    .integer => |b| {
                        const b_str = std.fmt.allocPrint(self.str_alloc(), "{d}", .{b}) catch return EvalError.OutOfMemory;
                        const s = std.fmt.allocPrint(self.str_alloc(), "{s}{s}", .{ a, b_str }) catch return EvalError.OutOfMemory;
                        return Value{ .string = s };
                    },
                    else => return EvalError.TypeError,
                },
                else => return EvalError.TypeError,
            }
        }
        // Arithmetic
        const a = switch (left) {
            .integer => |n| n,
            else => return EvalError.TypeError,
        };
        const b = switch (right) {
            .integer => |n| n,
            else => return EvalError.TypeError,
        };
        if (std.mem.eql(u8, expr.op, "-")) return Value{ .integer = a - b };
        if (std.mem.eql(u8, expr.op, "*")) return Value{ .integer = a * b };
        if (std.mem.eql(u8, expr.op, "/")) {
            if (b == 0) return EvalError.DivisionByZero;
            return Value{ .integer = @divTrunc(a, b) };
        }
        if (std.mem.eql(u8, expr.op, "<")) return Value{ .boolean = a < b };
        if (std.mem.eql(u8, expr.op, ">")) return Value{ .boolean = a > b };
        return EvalError.TypeError;
    }

    fn eval_prefix(self: *Interpreter, expr: ast.PrefixExpr, env: *Environment) EvalError!Value {
        const right = try self.eval(expr.right, env);
        if (std.mem.eql(u8, expr.op, "!")) {
            return Value{ .boolean = !right.is_truthy() };
        }
        if (std.mem.eql(u8, expr.op, "-")) {
            switch (right) {
                .integer => |n| return Value{ .integer = -n },
                else => return EvalError.TypeError,
            }
        }
        return EvalError.TypeError;
    }

    fn eval_call(self: *Interpreter, expr: ast.CallExpr, env: *Environment) EvalError!Value {
        const callee_val = try self.eval(expr.callee, env);
        const func = switch (callee_val) {
            .function => |f| f,
            else => return EvalError.TypeError,
        };
        if (expr.args.len != func.params.len) return EvalError.TypeError;
        var call_env = Environment.init(self.alloc, func.env);
        defer call_env.deinit();
        for (func.params, expr.args) |param, arg_node| {
            const arg_val = try self.eval(arg_node, env);
            try call_env.define(param, .{ .value = arg_val, .mutable = false });
        }
        _ = try self.eval(func.body, &call_env);
        if (self.signal) |sig| {
            switch (sig) {
                .return_val => |v| {
                    self.signal = null;
                    return v;
                },
                else => {},
            }
        }
        return Value{ .null_val = {} };
    }

    fn eval_member_call(self: *Interpreter, expr: ast.MemberCall, env: *Environment) EvalError!Value {
        if (std.mem.eql(u8, expr.object, "terminal") and std.mem.eql(u8, expr.member, "skriv")) {
            if (expr.args.len != 1) return EvalError.TypeError;
            const val = try self.eval(expr.args[0], env);
            const str = try val.to_string(self.str_alloc());
            self.output.print("{s}\n", .{str}) catch return EvalError.OutOfMemory;
            return Value{ .null_val = {} };
        }
        return EvalError.UnknownBuiltin;
    }
};
