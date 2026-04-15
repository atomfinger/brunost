const std = @import("std");
const ast = @import("ast.zig");
const token_mod = @import("token.zig");
const parser_mod = @import("parser.zig");
const stdlib_terminal = @import("stdlib/terminal.zig");
const stdlib_matte = @import("stdlib/matte.zig");
const stdlib_streng = @import("stdlib/streng.zig");
const stdlib_liste = @import("stdlib/liste.zig");
const stdlib_prosess = @import("stdlib/prosess.zig");
const stdlib_kart = @import("stdlib/kart.zig");

pub const EvalError = error{
    TypeError,
    UndefinedVariable,
    ImmutableAssignment,
    DivisionByZero,
    IndexOutOfBounds,
    KeyNotFound,
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
    float: f64,
    string: []const u8,
    boolean: bool,
    list: []Value,
    hashmap: *std.StringHashMapUnmanaged(Value),
    function: Function,
    module: []ModuleMember,
    builtin_fn: *const fn (args: []const Value, interp: *Interpreter) EvalError!Value,
    null_val: void,

    pub fn is_truthy(self: Value) bool {
        return switch (self) {
            .boolean => |b| b,
            .integer => |n| n != 0,
            .float => |n| n != 0.0,
            .string => |s| s.len > 0,
            .list => |l| l.len > 0,
            .hashmap => |h| h.count() > 0,
            .null_val => false,
            .function, .module, .builtin_fn => true,
        };
    }

    pub fn equals(self: Value, other: Value) bool {
        return switch (self) {
            .integer => |a| switch (other) {
                .integer => |b| a == b,
                .float => |b| @as(f64, @floatFromInt(a)) == b,
                else => false,
            },
            .float => |a| switch (other) {
                .float => |b| a == b,
                .integer => |b| a == @as(f64, @floatFromInt(b)),
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
            .float => |n| std.fmt.allocPrint(alloc, "{d}", .{n}) catch return EvalError.OutOfMemory,
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
            .hashmap => |h| blk: {
                var buf: std.ArrayList(u8) = .{};
                buf.append(alloc, '{') catch return EvalError.OutOfMemory;
                var it = h.iterator();
                var first = true;
                while (it.next()) |entry| {
                    if (!first) buf.appendSlice(alloc, ", ") catch return EvalError.OutOfMemory;
                    first = false;
                    const vs = try entry.value_ptr.*.to_string(alloc);
                    const pair = std.fmt.allocPrint(alloc, "\"{s}\": {s}", .{ entry.key_ptr.*, vs }) catch return EvalError.OutOfMemory;
                    buf.appendSlice(alloc, pair) catch return EvalError.OutOfMemory;
                }
                buf.append(alloc, '}') catch return EvalError.OutOfMemory;
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

    pub fn as_float(self: Value) EvalError!f64 {
        return switch (self) {
            .float => |n| n,
            .integer => |n| @floatFromInt(n),
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

    pub fn as_hashmap(self: Value) EvalError!*std.StringHashMapUnmanaged(Value) {
        return switch (self) {
            .hashmap => |h| h,
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
    script_args: []const []const u8,
    module_envs: std.ArrayList(*Environment),
    debug: bool,

    pub fn init(
        alloc: std.mem.Allocator,
        output: std.io.AnyWriter,
        base_dir: []const u8,
        script_args: []const []const u8,
    ) Interpreter {
        return .{
            .alloc = alloc,
            .str_arena = std.heap.ArenaAllocator.init(alloc),
            .global = Environment.init(alloc, null),
            .signal = null,
            .output = output,
            .base_dir = base_dir,
            .script_args = script_args,
            .module_envs = .{},
            .debug = false,
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

    fn dbg(self: *Interpreter, comptime fmt: []const u8, args: anytype) void {
        if (!self.debug) return;
        if (comptime @import("builtin").cpu.arch == .wasm32) return;
        std.debug.print("[debug] " ++ fmt ++ "\n", args);
    }

    fn dbg_val(self: *Interpreter, v: Value) []const u8 {
        return v.to_string(self.str_alloc()) catch "<minnefeil>";
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
            .float_lit => |f| Value{ .float = f.value },
            .string_lit => |s| Value{ .string = s.value },
            .bool_lit => |b| Value{ .boolean = b.value },
            .list_lit => |l| self.eval_list(l, env),
            .hashmap_lit => |h| self.eval_hashmap(h, env),
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
        self.dbg("{s} '{s}' = {s}", .{ if (decl.mutable) "open" else "låst", decl.name, self.dbg_val(value) });
        return Value{ .null_val = {} };
    }

    fn eval_assign(self: *Interpreter, a: ast.AssignStmt, env: *Environment) EvalError!Value {
        const value = try self.eval(a.value, env);
        try env.assign(a.name, value);
        self.dbg("set '{s}' = {s}", .{ a.name, self.dbg_val(value) });
        return Value{ .null_val = {} };
    }

    fn eval_return(self: *Interpreter, r: ast.ReturnStmt, env: *Environment) EvalError!Value {
        const value = try self.eval(r.value, env);
        self.dbg("gjevTilbake {s}", .{self.dbg_val(value)});
        self.signal = Signal{ .return_val = value };
        return Value{ .null_val = {} };
    }

    fn eval_throw(self: *Interpreter, t: ast.ThrowStmt, env: *Environment) EvalError!Value {
        const value = try self.eval(t.value, env);
        self.dbg("kast {s}", .{self.dbg_val(value)});
        self.signal = Signal{ .thrown = value };
        return Value{ .null_val = {} };
    }

    fn eval_fn_decl(self: *Interpreter, f: ast.FnDecl, env: *Environment) EvalError!Value {
        const func = Value{ .function = .{ .params = f.params, .body = f.body, .env = env } };
        try env.define(f.name, .{ .value = func, .mutable = false });
        self.dbg("gjer '{s}' ({d} param(ar))", .{ f.name, f.params.len });
        return Value{ .null_val = {} };
    }

    fn eval_if(self: *Interpreter, stmt: ast.IfStmt, env: *Environment) EvalError!Value {
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

    fn eval_while(self: *Interpreter, stmt: ast.WhileStmt, env: *Environment) EvalError!Value {
        var iteration: usize = 0;
        while (true) {
            const cond_val = try self.eval(stmt.condition, env);
            if (!cond_val.is_truthy()) break;
            self.dbg("medan: iterasjon {d}", .{iteration});
            iteration += 1;
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
                self.dbg("forKvart '{s}': {d} element(ar)", .{ stmt.iterator_name, items.len });
                for (items, 0..) |item, i| {
                    self.dbg("  element {d}: {s}", .{ i, self.dbg_val(item) });
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

        // Evaluate the try body, intercepting both `kast` signals and runtime
        // EvalErrors so they can both be caught by the `fang` block.
        const maybe_caught: ?Value = caught: {
            _ = self.eval(stmt.body, &try_env) catch |err| {
                // Convert a Zig EvalError into a string value delivered to fang.
                const s = std.fmt.allocPrint(self.str_alloc(), "{s}", .{@errorName(err)}) catch return EvalError.OutOfMemory;
                break :caught Value{ .string = s };
            };
            if (self.signal) |sig| switch (sig) {
                .thrown => |err_val| {
                    self.signal = null;
                    break :caught err_val;
                },
                else => {},
            };
            break :caught null;
        };

        if (maybe_caught) |err_val| {
            var catch_env = Environment.init(self.alloc, env);
            defer catch_env.deinit();
            try catch_env.define(stmt.error_name, .{ .value = err_val, .mutable = false });
            return self.eval(stmt.catch_body, &catch_env);
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
        self.dbg("bruk '{s}' som '{s}'", .{ stmt.segments[stmt.segments.len - 1], effective_name });
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

        const builtins = comptime [_]struct {
            name: []const u8,
            make: *const fn (std.mem.Allocator) EvalError!Value,
        }{
            .{ .name = "terminal", .make = stdlib_terminal.make },
            .{ .name = "matte",    .make = stdlib_matte.make    },
            .{ .name = "streng",   .make = stdlib_streng.make   },
            .{ .name = "liste",    .make = stdlib_liste.make    },
            .{ .name = "prosess",  .make = stdlib_prosess.make  },
            .{ .name = "kart",     .make = stdlib_kart.make     },
        };

        for (builtins) |b| {
            if (std.mem.eql(u8, name, b.name)) return b.make(alloc);
        }

        return EvalError.UnknownModule;
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

    fn eval_hashmap(self: *Interpreter, h: ast.HashmapLit, env: *Environment) EvalError!Value {
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

    fn eval_identifier(_: *Interpreter, i: ast.Identifier, env: *Environment) EvalError!Value {
        if (env.get(i.name)) |entry| return entry.value;
        return EvalError.UndefinedVariable;
    }

    fn eval_infix(self: *Interpreter, expr: ast.InfixExpr, env: *Environment) EvalError!Value {
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

    fn eval_prefix(self: *Interpreter, expr: ast.PrefixExpr, env: *Environment) EvalError!Value {
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
        const fn_name = switch (expr.callee.*) {
            .identifier => |id| id.name,
            else => "<uttrykk>",
        };
        var call_env = Environment.init(self.alloc, func.env);
        defer call_env.deinit();
        if (self.debug) {
             self.dbg("kall '{s}' ({d} arg(ar)):", .{ fn_name, expr.args.len });
        }
        for (func.params, expr.args) |param, arg_node| {
            const arg_val = try self.eval(arg_node, env);
            if (self.debug) {
                self.dbg("  {s} = {s}", .{ param, self.dbg_val(arg_val) });
            }
            try call_env.define(param, .{ .value = arg_val, .mutable = false });
        }
        _ = try self.eval(func.body, &call_env);
        if (self.signal) |sig| {
            switch (sig) {
                .return_val => |v| {
                    self.signal = null;
                    self.dbg("  '{s}' returnerte {s}", .{ fn_name, self.dbg_val(v) });
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
        if (self.debug) {
            self.dbg("kall '{s}'.'{s}' ({d} arg(ar)):", .{ expr.object, expr.member, args_slice.len });
            for (args_slice, 0..) |arg, i| {
                self.dbg("  arg[{d}] = {s}", .{ i, self.dbg_val(arg) });
            }
        }
        const result = switch (member_val) {
            .builtin_fn => |f| try f(args_slice, self),
            .function => |f| try self.call_function(f, args_slice),
            else => return EvalError.TypeError,
        };
        self.dbg("  → {s}", .{self.dbg_val(result)});
        return result;
    }
};
