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
const stdlib_fil = @import("stdlib/fil.zig");
const stdlib_http = @import("stdlib/http.zig");
const stdlib_nettverk = @import("stdlib/nettverk.zig");

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
    UndefinedField,
    ImmutableField,
    NotAStructType,
    InvalidAddress,
    InvalidPort,
    InvalidHandle,
    UnsupportedPlatform,
    AddressInUse,
    AddressUnavailable,
    ConnectionRefused,
    ConnectionAborted,
    ConnectionResetByPeer,
    HostUnreachable,
    NetworkUnreachable,
    NetworkDown,
    SocketNotListening,
    AccessDenied,
    Timeout,
    SystemResources,
    SocketLimitExceeded,
    FileNotFound,
    PermissionDenied,
    FileTooLarge,
    MalformedHttpRequest,
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

/// Schema stored in environment when a `type` is declared.
pub const StructType = struct {
    name: []const u8,
    fields: []ast.StructFieldDecl,
};

/// One live field in a struct instance.
pub const StructFieldEntry = struct {
    name: []const u8,
    value: Value,
    mutable: bool,
};

/// Heap-allocated so all copies of Value.struct_instance share the same fields.
pub const StructInstance = struct {
    type_name: []const u8,
    fields: []StructFieldEntry,
};

pub const BrunostList = struct {
    items: []Value,
    cap: usize,
};

pub const ResourceHandleKind = enum {
    listener,
    stream,
};

pub const ResourceHandle = struct {
    id: usize,
    kind: ResourceHandleKind,
};

pub const RuntimeResource = union(ResourceHandleKind) {
    listener: std.Io.net.Server,
    stream: std.Io.net.Stream,
};

pub const ResourceSlot = struct {
    active: bool,
    resource: RuntimeResource,
};

pub const Value = union(enum) {
    integer: i64,
    float: f64,
    string: []const u8,
    boolean: bool,
    list: BrunostList,
    hashmap: *std.StringHashMapUnmanaged(Value),
    function: Function,
    module: []ModuleMember,
    builtin_fn: *const fn (args: []const Value, interp: *Interpreter) EvalError!Value,
    null_val: void,
    struct_type: StructType,
    struct_instance: *StructInstance,
    resource_handle: ResourceHandle,

    pub fn is_truthy(self: Value) bool {
        return switch (self) {
            .boolean => |b| b,
            .integer => |n| n != 0,
            .float => |n| n != 0.0,
            .string => |s| s.len > 0,
            .list => |l| l.items.len > 0,
            .hashmap => |h| h.count() > 0,
            .null_val => false,
            .function, .module, .builtin_fn, .resource_handle => true,
            .struct_type, .struct_instance => true,
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
            .resource_handle => |a| switch (other) {
                .resource_handle => |b| a.id == b.id and a.kind == b.kind,
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
                var buf: std.ArrayList(u8) = .empty;
                buf.append(alloc, '[') catch return EvalError.OutOfMemory;
                for (l.items, 0..) |elem, idx| {
                    const s = try elem.to_string(alloc);
                    buf.appendSlice(alloc, s) catch return EvalError.OutOfMemory;
                    if (idx + 1 < l.items.len) buf.appendSlice(alloc, ", ") catch return EvalError.OutOfMemory;
                }
                buf.append(alloc, ']') catch return EvalError.OutOfMemory;
                break :blk buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory;
            },
            .hashmap => |h| blk: {
                var buf: std.ArrayList(u8) = .empty;
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
            .struct_type => "<type>",
            .resource_handle => |h| std.fmt.allocPrint(
                alloc,
                "<{s}#{d}>",
                .{
                    switch (h.kind) {
                        .listener => "lyttar",
                        .stream => "straum",
                    },
                    h.id,
                },
            ) catch return EvalError.OutOfMemory,
            .struct_instance => |s| blk: {
                var buf: std.ArrayList(u8) = .empty;
                buf.append(alloc, '{') catch return EvalError.OutOfMemory;
                for (s.fields, 0..) |f, i| {
                    const pair = switch (f.value) {
                        .string => |str| std.fmt.allocPrint(alloc, "\"{s}\": \"{s}\"", .{ f.name, str }) catch return EvalError.OutOfMemory,
                        .boolean => |b| std.fmt.allocPrint(alloc, "\"{s}\": {s}", .{ f.name, if (b) "true" else "false" }) catch return EvalError.OutOfMemory,
                        .null_val => std.fmt.allocPrint(alloc, "\"{s}\": null", .{f.name}) catch return EvalError.OutOfMemory,
                        else => blk2: {
                            const vs = try f.value.to_string(alloc);
                            break :blk2 std.fmt.allocPrint(alloc, "\"{s}\": {s}", .{ f.name, vs }) catch return EvalError.OutOfMemory;
                        },
                    };
                    buf.appendSlice(alloc, pair) catch return EvalError.OutOfMemory;
                    if (i + 1 < s.fields.len) buf.appendSlice(alloc, ", ") catch return EvalError.OutOfMemory;
                }
                buf.append(alloc, '}') catch return EvalError.OutOfMemory;
                break :blk buf.toOwnedSlice(alloc) catch return EvalError.OutOfMemory;
            },
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
            .list => |l| l.items,
            else => EvalError.TypeError,
        };
    }

    pub fn as_hashmap(self: Value) EvalError!*std.StringHashMapUnmanaged(Value) {
        return switch (self) {
            .hashmap => |h| h,
            else => EvalError.TypeError,
        };
    }

    pub fn as_resource_handle(self: Value) EvalError!ResourceHandle {
        return switch (self) {
            .resource_handle => |h| h,
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
    output: *std.Io.Writer,
    base_dir: []const u8,
    script_args: []const []const u8,
    module_envs: std.ArrayList(*Environment),
    resource_slots: std.ArrayList(ResourceSlot),
    debug: bool,
    last_undefined_name: []const u8,

    pub fn init(
        alloc: std.mem.Allocator,
        output: *std.Io.Writer,
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
            .module_envs = .empty,
            .resource_slots = .empty,
            .debug = false,
            .last_undefined_name = "",
        };
    }

    pub fn deinit(self: *Interpreter) void {
        for (self.resource_slots.items) |*slot| {
            if (!slot.active) continue;
            switch (slot.resource) {
                .listener => |*server| server.deinit(std.Options.debug_io),
                .stream => |*stream| stream.close(std.Options.debug_io),
            }
            slot.active = false;
        }
        self.resource_slots.deinit(self.alloc);
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

    pub fn register_listener(self: *Interpreter, server: std.Io.net.Server) EvalError!Value {
        try self.resource_slots.append(self.alloc, .{
            .active = true,
            .resource = .{ .listener = server },
        });
        return .{
            .resource_handle = .{
                .id = self.resource_slots.items.len,
                .kind = .listener,
            },
        };
    }

    pub fn register_stream(self: *Interpreter, stream: std.Io.net.Stream) EvalError!Value {
        try self.resource_slots.append(self.alloc, .{
            .active = true,
            .resource = .{ .stream = stream },
        });
        return .{
            .resource_handle = .{
                .id = self.resource_slots.items.len,
                .kind = .stream,
            },
        };
    }

    fn get_active_slot(self: *Interpreter, handle: ResourceHandle) EvalError!*ResourceSlot {
        if (handle.id == 0 or handle.id > self.resource_slots.items.len) return EvalError.InvalidHandle;
        const slot = &self.resource_slots.items[handle.id - 1];
        if (!slot.active) return EvalError.InvalidHandle;
        return slot;
    }

    pub fn require_listener(self: *Interpreter, value: Value) EvalError!*std.Io.net.Server {
        const handle = try value.as_resource_handle();
        const slot = try self.get_active_slot(handle);
        return switch (slot.resource) {
            .listener => |*server| server,
            else => EvalError.TypeError,
        };
    }

    pub fn require_stream(self: *Interpreter, value: Value) EvalError!*std.Io.net.Stream {
        const handle = try value.as_resource_handle();
        const slot = try self.get_active_slot(handle);
        return switch (slot.resource) {
            .stream => |*stream| stream,
            else => EvalError.TypeError,
        };
    }

    pub fn local_port(self: *Interpreter, value: Value) EvalError!u16 {
        const server = try self.require_listener(value);
        return server.socket.address.getPort();
    }

    pub fn close_handle(self: *Interpreter, value: Value) EvalError!void {
        const handle = try value.as_resource_handle();
        const slot = try self.get_active_slot(handle);
        switch (slot.resource) {
            .listener => |*server| server.deinit(std.Options.debug_io),
            .stream => |*stream| stream.close(std.Options.debug_io),
        }
        slot.active = false;
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
            .struct_decl => |d| self.eval_struct_decl(d, env),
            .field_assign => |a| self.eval_field_assign(a, env),
            .struct_lit => |l| self.eval_struct_lit(l, env),
            .field_access => |a| self.eval_field_access(a, env),
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
        env.assign(a.name, value) catch |err| {
            if (err == EvalError.UndefinedVariable) self.last_undefined_name = a.name;
            return err;
        };
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
            .list => |bl| {
                self.dbg("forKvart '{s}': {d} element(ar)", .{ stmt.iterator_name, bl.items.len });
                for (bl.items, 0..) |item, i| {
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
        var members: std.ArrayList(ModuleMember) = .empty;
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
            .{ .name = "fil",      .make = stdlib_fil.make      },
            .{ .name = "http",     .make = stdlib_http.make     },
            .{ .name = "nettverk", .make = stdlib_nettverk.make },
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
        var path_parts: std.ArrayList([]const u8) = .empty;
        path_parts.append(self.str_alloc(), self.base_dir) catch return EvalError.OutOfMemory;
        for (segments) |seg| {
            path_parts.append(self.str_alloc(), seg) catch return EvalError.OutOfMemory;
        }
        const joined = std.fs.path.join(self.str_alloc(), path_parts.items) catch return EvalError.OutOfMemory;
        const path = std.fmt.allocPrint(self.str_alloc(), "{s}.brunost", .{joined}) catch return EvalError.OutOfMemory;

        const source = std.Io.Dir.cwd().readFileAlloc(
            std.Options.debug_io,
            path,
            self.str_alloc(),
            .unlimited,
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

        var members: std.ArrayList(ModuleMember) = .empty;
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
        var items: std.ArrayList(Value) = .empty;
        for (l.elements) |elem| {
            const v = try self.eval(elem, env);
            items.append(self.str_alloc(), v) catch return EvalError.OutOfMemory;
        }
        const slice = items.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory;
        return Value{ .list = .{ .items = slice, .cap = slice.len } };
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

    fn eval_identifier(self: *Interpreter, i: ast.Identifier, env: *Environment) EvalError!Value {
        if (env.get(i.name)) |entry| return entry.value;
        self.last_undefined_name = i.name;
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

    fn eval_struct_decl(self: *Interpreter, decl: ast.StructDecl, env: *Environment) EvalError!Value {
        const fields = self.str_alloc().dupe(ast.StructFieldDecl, decl.fields) catch return EvalError.OutOfMemory;
        try env.define(decl.name, .{
            .value = .{ .struct_type = .{ .name = decl.name, .fields = fields } },
            .mutable = false,
        });
        return .{ .null_val = {} };
    }

    fn eval_struct_lit(self: *Interpreter, lit: ast.StructLit, env: *Environment) EvalError!Value {
        const entry = env.get(lit.type_name) orelse {
            self.last_undefined_name = lit.type_name;
            return EvalError.UndefinedVariable;
        };
        const schema = switch (entry.value) {
            .struct_type => |t| t,
            else => return EvalError.NotAStructType,
        };
        const instance = self.str_alloc().create(StructInstance) catch return EvalError.OutOfMemory;
        const fields = self.str_alloc().alloc(StructFieldEntry, schema.fields.len) catch return EvalError.OutOfMemory;
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

    fn eval_field_access(self: *Interpreter, access: ast.FieldAccess, env: *Environment) EvalError!Value {
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

    fn eval_field_assign(self: *Interpreter, a: ast.FieldAssign, env: *Environment) EvalError!Value {
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

    fn eval_member_call(self: *Interpreter, expr: ast.MemberCall, env: *Environment) EvalError!Value {
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
        const result = switch (member_val) {
            .builtin_fn => |f| try f(args_slice, self),
            .function => |f| try self.call_function(f, args_slice),
            else => return EvalError.TypeError,
        };
        if (self.debug) self.dbg("  → {s}", .{self.dbg_val(result)});
        return result;
    }
};
