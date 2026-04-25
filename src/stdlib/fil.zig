const std = @import("std");
const builtin = @import("builtin");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

const io = std.Options.debug_io;
const file_limit = std.Io.Limit.limited(50 * 1024 * 1024);

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "les",   .value = .{ .builtin_fn = les } },
        .{ .name = "finnas", .value = .{ .builtin_fn = finnas } },
    });
    return Value{ .module = members };
}

fn ensure_native() EvalError!void {
    if (comptime builtin.cpu.arch == .wasm32) return EvalError.UnsupportedPlatform;
}

fn resolve_path(interp: *Interpreter, path: []const u8) EvalError![]const u8 {
    if (std.fs.path.isAbsolute(path) or interp.base_dir.len == 0) return path;
    return std.fs.path.join(interp.str_alloc(), &.{ interp.base_dir, path }) catch EvalError.OutOfMemory;
}

fn map_file_error(err: anyerror) EvalError {
    return switch (err) {
        error.FileNotFound, error.NotDir => EvalError.FileNotFound,
        error.AccessDenied => EvalError.AccessDenied,
        error.PermissionDenied => EvalError.PermissionDenied,
        error.IsDir => EvalError.TypeError,
        error.FileTooBig, error.StreamTooLong => EvalError.FileTooLarge,
        error.SystemResources,
        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        => EvalError.SystemResources,
        else => EvalError.SystemResources,
    };
}

fn les(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 1) return EvalError.TypeError;
    const path = try resolve_path(interp, try args[0].as_str());
    const contents = std.Io.Dir.cwd().readFileAlloc(io, path, interp.str_alloc(), file_limit) catch |err| {
        return map_file_error(err);
    };
    return .{ .string = contents };
}

fn finnas(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 1) return EvalError.TypeError;
    const path = try resolve_path(interp, try args[0].as_str());
    var file = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return .{ .boolean = false },
        else => return map_file_error(err),
    };
    defer file.close(io);
    return .{ .boolean = true };
}
