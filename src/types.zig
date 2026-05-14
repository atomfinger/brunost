const std = @import("std");
const ast = @import("ast.zig");
// Circular import: only *Interpreter is used as a function-pointer parameter type.
// Pointer size is always known regardless of pointee layout, so this is safe —
// the same pattern already used by all stdlib modules.
const interp_mod = @import("interpreter.zig");

pub const Io = if (@import("builtin").cpu.arch != .wasm32) std.Io else void;

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
    break_loop: void,
    continue_loop: void,
};

pub const Function = struct {
    params: [][]const u8,
    body: *ast.Node,
    env: *Environment,
    implicit_return: bool,
};

pub const ModuleMember = struct {
    name: []const u8,
    value: Value,
};

pub const StructType = struct {
    name: []const u8,
    fields: []ast.StructFieldDecl,
};

pub const StructFieldEntry = struct {
    name: []const u8,
    value: Value,
    mutable: bool,
};

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

pub const RuntimeResource = if (@import("builtin").cpu.arch == .wasm32)
    union(ResourceHandleKind) { listener: void, stream: void }
else
    union(ResourceHandleKind) {
        listener: std.Io.net.Server,
        stream: std.Io.net.Stream,
    };

pub const ResourceSlot = struct {
    active: bool,
    resource: RuntimeResource,
    paired_slot: ?*ResourceSlot = null,
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
    builtin_fn: *const fn (args: []const Value, interp: *interp_mod.Interpreter) EvalError!Value,
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
