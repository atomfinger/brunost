const std = @import("std");
const ast = @import("ast.zig");
const token_mod = @import("token.zig");
const parser_mod = @import("parser.zig");
const types = @import("types.zig");
const stdlib_terminal = @import("stdlib/terminal.zig");
const stdlib_matte = @import("stdlib/matte.zig");
const stdlib_streng = @import("stdlib/streng.zig");
const stdlib_liste = @import("stdlib/liste.zig");
const stdlib_prosess = @import("stdlib/prosess.zig");
const stdlib_kart = @import("stdlib/kart.zig");
const stdlib_test = @import("stdlib/test.zig");

// Re-export all types so existing callers (stdlib, main.zig) need no changes.
pub const Io = types.Io;
pub const EvalError = types.EvalError;
pub const Signal = types.Signal;
pub const Value = types.Value;
pub const Function = types.Function;
pub const ModuleMember = types.ModuleMember;
pub const StructType = types.StructType;
pub const StructFieldEntry = types.StructFieldEntry;
pub const StructInstance = types.StructInstance;
pub const BrunostList = types.BrunostList;
pub const ResourceHandleKind = types.ResourceHandleKind;
pub const ResourceHandle = types.ResourceHandle;
pub const RuntimeResource = types.RuntimeResource;
pub const ResourceSlot = types.ResourceSlot;
pub const EnvEntry = types.EnvEntry;
pub const Environment = types.Environment;

pub const Interpreter = struct {
    alloc: std.mem.Allocator,
    str_arena: std.heap.ArenaAllocator,
    global: Environment,
    signal: ?Signal,
    io: Io,
    output: *std.Io.Writer,
    base_dir: []const u8,
    script_args: []const []const u8,
    module_envs: std.ArrayList(*Environment),
    resource_slots: std.ArrayList(ResourceSlot),
    debug: bool,
    last_undefined_name: []const u8,

    pub fn init(
        alloc: std.mem.Allocator,
        io: Io,
        output: *std.Io.Writer,
        base_dir: []const u8,
        script_args: []const []const u8,
    ) Interpreter {
        return .{
            .alloc = alloc,
            .str_arena = std.heap.ArenaAllocator.init(alloc),
            .global = Environment.init(alloc, null),
            .signal = null,
            .io = io,
            .output = output,
            .base_dir = base_dir,
            .script_args = script_args,
            .module_envs = .empty,
            .resource_slots = .empty,
            .debug = false,
            .last_undefined_name = "",
        };
    }

    pub fn init_for_handler_thread(
        alloc: std.mem.Allocator,
        io: Io,
        output: *std.Io.Writer,
        base_dir: []const u8,
        debug: bool,
    ) Interpreter {
        return .{
            .alloc = alloc,
            .str_arena = std.heap.ArenaAllocator.init(alloc),
            .global = Environment.init(alloc, null),
            .signal = null,
            .io = io,
            .output = output,
            .base_dir = base_dir,
            .script_args = &.{},
            .module_envs = .empty,
            .resource_slots = .empty,
            .debug = debug,
            .last_undefined_name = "",
        };
    }

    pub fn deinit(self: *Interpreter) void {
        if (comptime @import("builtin").cpu.arch != .wasm32) {
            for (self.resource_slots.items) |*slot| {
                if (!slot.active) continue;
                if (slot.paired_slot != null) {
                    slot.active = false;
                    continue;
                }
                switch (slot.resource) {
                    .listener => |*server| {
                        self.io.vtable.netShutdown(self.io.userdata, server.socket.handle, .recv) catch {};
                        server.deinit(self.io);
                    },
                    .stream => |*stream| stream.close(self.io),
                }
                slot.active = false;
            }
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
        return .{ .resource_handle = .{ .id = self.resource_slots.items.len, .kind = .listener } };
    }

    pub fn register_listener_mirrored(self: *Interpreter, server: std.Io.net.Server, main_slot: *ResourceSlot) EvalError!Value {
        try self.resource_slots.append(self.alloc, .{
            .active = true,
            .resource = .{ .listener = server },
            .paired_slot = main_slot,
        });
        return .{ .resource_handle = .{ .id = self.resource_slots.items.len, .kind = .listener } };
    }

    pub fn listener_slot(self: *Interpreter, value: Value) EvalError!*ResourceSlot {
        const handle = try value.as_resource_handle();
        return self.get_active_slot(handle);
    }

    pub fn register_stream(self: *Interpreter, stream: std.Io.net.Stream) EvalError!Value {
        try self.resource_slots.append(self.alloc, .{
            .active = true,
            .resource = .{ .stream = stream },
        });
        return .{ .resource_handle = .{ .id = self.resource_slots.items.len, .kind = .stream } };
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
        if (slot.paired_slot) |paired| paired.active = false;
        switch (slot.resource) {
            .listener => |*server| {
                if (comptime @import("builtin").cpu.arch != .wasm32) {
                    self.io.vtable.netShutdown(self.io.userdata, server.socket.handle, .recv) catch {};
                }
                server.deinit(self.io);
            },
            .stream => |*stream| stream.close(self.io),
        }
        slot.active = false;
    }

    pub fn dbg(self: *Interpreter, comptime fmt: []const u8, args: anytype) void {
        if (!self.debug) return;
        if (comptime @import("builtin").cpu.arch == .wasm32) return;
        std.debug.print("[debug] " ++ fmt ++ "\n", args);
    }

    pub fn dbg_val(self: *Interpreter, v: Value) []const u8 {
        return v.to_string(self.str_alloc()) catch "<minnefeil>";
    }

    pub fn eval(self: *Interpreter, node: *ast.Node, env: *Environment) EvalError!Value {
        const stmts = @import("interpreter_stmts.zig");
        const exprs = @import("interpreter_exprs.zig");
        const mods = @import("interpreter_modules.zig");
        return switch (node.*) {
            .program => |p| stmts.eval_program(self, p, env),
            .block => |b| stmts.eval_block(self, b, env),
            .var_decl => |d| stmts.eval_var_decl(self, d, env),
            .assign_stmt => |a| stmts.eval_assign(self, a, env),
            .return_stmt => |r| stmts.eval_return(self, r, env),
            .throw_stmt => |t| stmts.eval_throw(self, t, env),
            .expr_stmt => |e| self.eval(e.expr, env),
            .fn_decl => |f| stmts.eval_fn_decl(self, f, env),
            .if_stmt => |i| stmts.eval_if(self, i, env),
            .while_stmt => |w| stmts.eval_while(self, w, env),
            .foreach_stmt => |f| stmts.eval_foreach(self, f, env),
            .try_stmt => |t| stmts.eval_try(self, t, env),
            .import_stmt => |s| mods.eval_import(self, s, env),
            .module_decl => |m| mods.eval_module_decl(self, m, env),
            .struct_decl => |d| exprs.eval_struct_decl(self, d, env),
            .field_assign => |a| exprs.eval_field_assign(self, a, env),
            .struct_lit => |l| exprs.eval_struct_lit(self, l, env),
            .field_access => |a| exprs.eval_field_access(self, a, env),
            .break_stmt => stmts.eval_break(self),
            .continue_stmt => stmts.eval_continue(self),
            .index_expr => |i| stmts.eval_index_expr(self, i, env),
            .integer_lit => |i| Value{ .integer = i.value },
            .float_lit => |f| Value{ .float = f.value },
            .string_lit => |s| stmts.eval_string_lit(self, s.value),
            .bool_lit => |b| Value{ .boolean = b.value },
            .list_lit => |l| exprs.eval_list(self, l, env),
            .hashmap_lit => |h| exprs.eval_hashmap(self, h, env),
            .identifier => |i| exprs.eval_identifier(self, i, env),
            .infix_expr => |i| exprs.eval_infix(self, i, env),
            .prefix_expr => |p| exprs.eval_prefix(self, p, env),
            .call_expr => |c| exprs.eval_call(self, c, env),
            .member_call => |m| exprs.eval_member_call(self, m, env),
            .lambda_expr => |l| exprs.eval_lambda_expr(self, l, env),
        };
    }

    // Public delegation used by stdlib modules.
    pub fn call_callable(self: *Interpreter, callable: Value, args: []const Value) EvalError!Value {
        return @import("interpreter_exprs.zig").call_callable(self, callable, args);
    }

    // make_builtin_module is called from interpreter_modules.zig and must be accessible.
    pub fn make_builtin_module(self: *Interpreter, name: []const u8) EvalError!Value {
        const alloc = self.str_alloc();
        const builtins = comptime [_]struct {
            name: []const u8,
            make: *const fn (std.mem.Allocator) EvalError!Value,
        }{
            .{ .name = "terminal", .make = stdlib_terminal.make },
            .{ .name = "matte", .make = stdlib_matte.make },
            .{ .name = "streng", .make = stdlib_streng.make },
            .{ .name = "liste", .make = stdlib_liste.make },
            .{ .name = "prosess", .make = stdlib_prosess.make },
            .{ .name = "kart", .make = stdlib_kart.make },
            .{ .name = "test", .make = stdlib_test.make },
        };
        for (builtins) |b| {
            if (std.mem.eql(u8, name, b.name)) return b.make(alloc);
        }
        if (comptime @import("builtin").cpu.arch != .wasm32) {
            if (std.mem.eql(u8, name, "fil")) return @import("stdlib/fil.zig").make(alloc);
            if (std.mem.eql(u8, name, "http")) return @import("stdlib/http.zig").make(alloc);
            if (std.mem.eql(u8, name, "nettverk")) return @import("stdlib/nettverk.zig").make(alloc);
        }
        return EvalError.UnknownModule;
    }
};
