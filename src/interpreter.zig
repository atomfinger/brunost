const std = @import("std");
const ast = @import("ast.zig");
const token_mod = @import("token.zig");
const parser_mod = @import("parser.zig");
const stdlib_terminal = @import("stdlib/terminal.zig");
const stdlib_matte = @import("stdlib/matte.zig");
const stdlib_streng = @import("stdlib/streng.zig");
const stdlib_liste = @import("stdlib/liste.zig");

pub const EvalError = error{
    TypeError,
    UndefinedVariable,
    ImmutableAssignment,
    DivisionByZero,
    IndexOutOfBounds,
    UnknownBuiltin,
    UnknownModule,
    ModuleNameCollision,
    ModuleNotFound,
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

pub const ModuleMember = struct {
    name: []const u8,
    value: Value,
};

pub const Value = union(enum) {
    integer: i64,
    string: []const u8,
    boolean: bool,
    list: []Value,
    function: Function,
    module: []ModuleMember,
    builtin_fn: *const fn (args: []const Value, interp: *Interpreter) EvalError!Value,
    null_val: void,

    pub fn is_truthy(self: Value) bool {
        return switch (self) {
            .boolean => |b| b,
            .integer => |n| n != 0,
            .string => |s| s.len > 0,
            .list => |l| l.len > 0,
            .null_val => false,
            .function, .module, .builtin_fn => true,
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
            .module => "<modul>",
            .builtin_fn => "<innebygd-funksjon>",
        };
    }

    pub fn as_int(self: Value) EvalError!i64 {
        return switch (self) {
            .integer => |n| n,
            else => EvalError.TypeError,
        };
    }

    pub fn as_str(self: Value) EvalError![]const u8 {
        return switch (self) {
            .string => |s| s,
            else => EvalError.TypeError,
        };
    }

    pub fn as_list(self: Value) EvalError![]Value {
        return switch (self) {
            .list => |l| l,
            else => EvalError.TypeError,
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
    str_arena: std.heap.ArenaAllocator,
    global: Environment,
    signal: ?Signal,
    output: std.io.AnyWriter,
    base_dir: []const u8,
    module_envs: std.ArrayList(*Environment),

    pub fn init(alloc: std.mem.Allocator, output: std.io.AnyWriter, base_dir: []const u8) Interpreter {
        return .{
            .alloc = alloc,
            .str_arena = std.heap.ArenaAllocator.init(alloc),
            .global = Environment.init(alloc, null),
            .signal = null,
            .output = output,
            .base_dir = base_dir,
            .module_envs = .{},
        };
    }

    pub fn deinit(self: *Interpreter) void {
        for (self.module_envs.items) |env| {
            env.deinit();
            self.alloc.destroy(env);
        }
        self.module_envs.deinit(self.alloc);
        self.global.deinit();
        self.str_arena.deinit();
    }

    pub fn str_alloc(self: *Interpreter) std.mem.Allocator {
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
            .import_stmt => |s| self.eval_import(s, env),
            .module_decl => |m| self.eval_module_decl(m, env),
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

    fn eval_import(self: *Interpreter, stmt: ast.ImportStmt, env: *Environment) EvalError!Value {
        const effective_name = stmt.alias orelse stmt.segments[stmt.segments.len - 1];

        if (env.store.contains(effective_name)) return EvalError.ModuleNameCollision;

        const mod = if (stmt.segments.len == 1)
            self.make_builtin_module(stmt.segments[0]) catch |e| switch (e) {
                EvalError.UnknownModule => blk: {
                    if (self.base_dir.len == 0) return EvalError.UnknownModule;
                    break :blk try self.load_file_module(stmt.segments);
                },
                else => return e,
            }
        else
            try self.load_file_module(stmt.segments);

        try env.define(effective_name, .{ .value = mod, .mutable = false });

        return Value{ .null_val = {} };
    }

    fn eval_module_decl(self: *Interpreter, decl: ast.ModuleDecl, env: *Environment) EvalError!Value {
        var members: std.ArrayList(ModuleMember) = .{};
        for (decl.functions) |fn_node| {
            const f = fn_node.fn_decl;
            members.append(self.str_alloc(), .{
                .name = f.name,
                .value = .{ .function = .{ .params = f.params, .body = f.body, .env = env } },
            }) catch return EvalError.OutOfMemory;
        }
        const mod = Value{ .module = members.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory };
        try env.define(decl.name, .{ .value = mod, .mutable = false });
        return Value{ .null_val = {} };
    }

    fn make_builtin_module(self: *Interpreter, name: []const u8) EvalError!Value {
        const alloc = self.str_alloc();
        if (std.mem.eql(u8, name, "terminal")) return stdlib_terminal.make(alloc) else if (std.mem.eql(u8, name, "matte")) return stdlib_matte.make(alloc) else if (std.mem.eql(u8, name, "streng")) return stdlib_streng.make(alloc) else if (std.mem.eql(u8, name, "liste")) return stdlib_liste.make(alloc) else return EvalError.UnknownModule;
    }

    fn load_file_module(self: *Interpreter, segments: [][]const u8) EvalError!Value {
        // Filesystem is unavailable in WASM builds — comptime-eliminated, not a runtime branch.
        if (comptime @import("builtin").cpu.arch == .wasm32) return EvalError.ModuleNotFound;

        if (self.base_dir.len == 0) return EvalError.ModuleNotFound;

        // Build path: base_dir/seg0/.../segN.brunost
        var path_parts: std.ArrayList([]const u8) = .{};
        path_parts.append(self.str_alloc(), self.base_dir) catch return EvalError.OutOfMemory;
        for (segments) |seg| {
            path_parts.append(self.str_alloc(), seg) catch return EvalError.OutOfMemory;
        }
        const joined = std.fs.path.join(self.str_alloc(), path_parts.items) catch return EvalError.OutOfMemory;
        const path = std.fmt.allocPrint(self.str_alloc(), "{s}.brunost", .{joined}) catch return EvalError.OutOfMemory;

        const source = std.fs.cwd().readFileAlloc(
            self.str_alloc(),
            path,
            std.math.maxInt(usize)
        ) catch return EvalError.ModuleNotFound;

        const lexer = token_mod.Lexer.init(source);
        var p = parser_mod.Parser.init(lexer, self.str_alloc());
        const program = p.parse_program() catch return EvalError.ModuleNotFound;

        const mod_env = self.alloc.create(Environment) catch return EvalError.OutOfMemory;
        mod_env.* = Environment.init(self.alloc, null);
        self.module_envs.append(self.alloc, mod_env) catch return EvalError.OutOfMemory;

        const saved_signal = self.signal;
        self.signal = null;
        _ = self.eval(program, mod_env) catch |e| {
            self.signal = saved_signal;
            return e;
        };
        self.signal = saved_signal;

        var members: std.ArrayList(ModuleMember) = .{};
        var it = mod_env.store.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.value) {
                .function, .module => {
                    members.append(self.str_alloc(), .{
                        .name = entry.key_ptr.*,
                        .value = entry.value_ptr.value,
                    }) catch return EvalError.OutOfMemory;
                },
                else => {},
            }
        }
        return Value{ .module = members.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory };
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
        if (std.mem.eql(u8, expr.op, "<=")) return Value{ .boolean = a <= b };
        if (std.mem.eql(u8, expr.op, ">=")) return Value{ .boolean = a >= b };
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

    fn call_function(self: *Interpreter, func: Function, args: []const Value) EvalError!Value {
        if (args.len != func.params.len) return EvalError.TypeError;
        var call_env = Environment.init(self.alloc, func.env);
        defer call_env.deinit();
        for (func.params, args) |param, arg_val| {
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
        const entry = env.get(expr.object) orelse return EvalError.UndefinedVariable;
        const members = switch (entry.value) {
            .module => |m| m,
            else => return EvalError.TypeError,
        };
        const member_val = for (members) |m| {
            if (std.mem.eql(u8, m.name, expr.member)) break m.value;
        } else return EvalError.UndefinedVariable;
        var args: std.ArrayList(Value) = .{};
        for (expr.args) |arg_node| {
            const v = try self.eval(arg_node, env);
            args.append(self.str_alloc(), v) catch return EvalError.OutOfMemory;
        }
        const args_slice = args.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory;
        return switch (member_val) {
            .builtin_fn => |f| f(args_slice, self),
            .function => |f| self.call_function(f, args_slice),
            else => EvalError.TypeError,
        };
    }
};
