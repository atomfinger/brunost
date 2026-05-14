const std = @import("std");
const ast = @import("ast.zig");
const token_mod = @import("token.zig");
const parser_mod = @import("parser.zig");
const interp_mod = @import("interpreter.zig");
const Interpreter = interp_mod.Interpreter;
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Environment = interp_mod.Environment;
const ModuleMember = interp_mod.ModuleMember;

pub fn eval_import(self: *Interpreter, stmt: ast.ImportStmt, env: *Environment) EvalError!Value {
    const effective_name = stmt.alias orelse stmt.segments[stmt.segments.len - 1];

    if (env.store.contains(effective_name)) return EvalError.ModuleNameCollision;

    const mod = if (stmt.segments.len == 1)
        self.make_builtin_module(stmt.segments[0]) catch |e| switch (e) {
            EvalError.UnknownModule => blk: {
                if (self.base_dir.len == 0) return EvalError.UnknownModule;
                break :blk try load_file_module(self, stmt.segments);
            },
            else => return e,
        }
    else
        try load_file_module(self, stmt.segments);

    try env.define(effective_name, .{ .value = mod, .mutable = false });
    self.dbg("bruk '{s}' som '{s}'", .{ stmt.segments[stmt.segments.len - 1], effective_name });
    return Value{ .null_val = {} };
}

pub fn eval_module_decl(self: *Interpreter, decl: ast.ModuleDecl, env: *Environment) EvalError!Value {
    var members: std.ArrayList(ModuleMember) = .empty;
    for (decl.functions) |fn_node| {
        const f = fn_node.fn_decl;
        members.append(self.str_alloc(), .{
            .name = f.name,
            .value = .{ .function = .{
                .params = f.params,
                .body = f.body,
                .env = env,
                .implicit_return = false,
            } },
        }) catch return EvalError.OutOfMemory;
    }
    const mod = Value{ .module = members.toOwnedSlice(self.str_alloc()) catch return EvalError.OutOfMemory };
    try env.define(decl.name, .{ .value = mod, .mutable = false });
    return Value{ .null_val = {} };
}

pub fn load_file_module(self: *Interpreter, segments: [][]const u8) EvalError!Value {
    if (comptime @import("builtin").cpu.arch == .wasm32) return EvalError.ModuleNotFound;

    if (self.base_dir.len == 0) return EvalError.ModuleNotFound;

    var path_parts: std.ArrayList([]const u8) = .empty;
    path_parts.append(self.str_alloc(), self.base_dir) catch return EvalError.OutOfMemory;
    for (segments) |seg| {
        path_parts.append(self.str_alloc(), seg) catch return EvalError.OutOfMemory;
    }
    const joined = std.fs.path.join(self.str_alloc(), path_parts.items) catch return EvalError.OutOfMemory;
    const path = std.fmt.allocPrint(self.str_alloc(), "{s}.brunost", .{joined}) catch return EvalError.OutOfMemory;

    const source = std.Io.Dir.cwd().readFileAlloc(
        self.io,
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
