const std = @import("std");
const builtin = @import("builtin");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const ModuleMember = interp_mod.ModuleMember;

const file_limit = std.Io.Limit.limited(50 * 1024 * 1024);

const RequestLine = struct {
    method: []const u8,
    target: []const u8,
};

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "metode", .value = .{ .builtin_fn = metode } },
        .{ .name = "sti",    .value = .{ .builtin_fn = sti } },
        .{ .name = "svar",   .value = .{ .builtin_fn = svar } },
        .{ .name = "statisk", .value = .{ .builtin_fn = statisk } },
    });
    return Value{ .module = members };
}

fn ensure_native() EvalError!void {
    if (comptime builtin.cpu.arch == .wasm32) return EvalError.UnsupportedPlatform;
}

fn parse_request_line(request: []const u8) EvalError!RequestLine {
    const line_end = std.mem.indexOfScalar(u8, request, '\n') orelse request.len;
    var line = request[0..line_end];
    if (std.mem.endsWith(u8, line, "\r")) line = line[0 .. line.len - 1];

    var it = std.mem.tokenizeScalar(u8, line, ' ');
    const method_name = it.next() orelse return EvalError.MalformedHttpRequest;
    const target = it.next() orelse return EvalError.MalformedHttpRequest;
    _ = it.next() orelse return EvalError.MalformedHttpRequest;
    return .{ .method = method_name, .target = target };
}

fn request_path(request: []const u8) EvalError![]const u8 {
    const line = try parse_request_line(request);
    if (line.target.len == 0 or line.target[0] != '/') return EvalError.MalformedHttpRequest;
    const end = std.mem.indexOfAny(u8, line.target, "?#") orelse line.target.len;
    return line.target[0..end];
}

fn status_text(status: i64) []const u8 {
    return switch (status) {
        200 => "OK",
        400 => "Bad Request",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        500 => "Internal Server Error",
        else => "OK",
    };
}

fn build_response(
    interp: *Interpreter,
    status: i64,
    content_type: []const u8,
    body: []const u8,
) EvalError!Value {
    var buf: std.ArrayList(u8) = .empty;
    const header = std.fmt.allocPrint(
        interp.str_alloc(),
        "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
        .{ status, status_text(status), content_type, body.len },
    ) catch return EvalError.OutOfMemory;
    buf.appendSlice(interp.str_alloc(), header) catch return EvalError.OutOfMemory;
    buf.appendSlice(interp.str_alloc(), body) catch return EvalError.OutOfMemory;
    return .{ .string = buf.toOwnedSlice(interp.str_alloc()) catch return EvalError.OutOfMemory };
}

fn resolve_root(interp: *Interpreter, root: []const u8) EvalError![]const u8 {
    if (std.fs.path.isAbsolute(root) or interp.base_dir.len == 0) return root;
    return std.fs.path.join(interp.str_alloc(), &.{ interp.base_dir, root }) catch EvalError.OutOfMemory;
}

fn append_segment(buf: *std.ArrayList(u8), alloc: std.mem.Allocator, segment: []const u8) EvalError!void {
    if (segment.len == 0 or std.mem.eql(u8, segment, ".")) return;
    if (std.mem.eql(u8, segment, "..")) return EvalError.AccessDenied;
    if (std.mem.indexOfScalar(u8, segment, '\\') != null) return EvalError.AccessDenied;
    if (std.mem.indexOfScalar(u8, segment, ':') != null) return EvalError.AccessDenied;
    if (buf.items.len > 0 and buf.items[buf.items.len - 1] != std.fs.path.sep) {
        buf.append(alloc, std.fs.path.sep) catch return EvalError.OutOfMemory;
    }
    buf.appendSlice(alloc, segment) catch return EvalError.OutOfMemory;
}

fn build_static_file_path(interp: *Interpreter, root: []const u8, path: []const u8) EvalError![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    buf.appendSlice(interp.str_alloc(), root) catch return EvalError.OutOfMemory;

    const needs_index = std.mem.endsWith(u8, path, "/");
    var splitter = std.mem.splitScalar(u8, path, '/');
    while (splitter.next()) |segment| {
        try append_segment(&buf, interp.str_alloc(), segment);
    }

    if (path.len == 0 or std.mem.eql(u8, path, "/") or needs_index) {
        try append_segment(&buf, interp.str_alloc(), "index.html");
    }

    return buf.toOwnedSlice(interp.str_alloc()) catch return EvalError.OutOfMemory;
}

fn map_file_error(err: anyerror) EvalError {
    return switch (err) {
        error.FileNotFound, error.NotDir => EvalError.FileNotFound,
        error.AccessDenied => EvalError.AccessDenied,
        error.PermissionDenied => EvalError.PermissionDenied,
        error.IsDir => EvalError.AccessDenied,
        error.FileTooBig, error.StreamTooLong => EvalError.FileTooLarge,
        error.SystemResources,
        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        => EvalError.SystemResources,
        else => EvalError.SystemResources,
    };
}

fn guess_content_type(path: []const u8) []const u8 {
    const ext = std.fs.path.extension(path);
    if (std.mem.eql(u8, ext, ".html")) return "text/html; charset=utf-8";
    if (std.mem.eql(u8, ext, ".css")) return "text/css; charset=utf-8";
    if (std.mem.eql(u8, ext, ".js")) return "application/javascript; charset=utf-8";
    if (std.mem.eql(u8, ext, ".json")) return "application/json; charset=utf-8";
    if (std.mem.eql(u8, ext, ".svg")) return "image/svg+xml";
    if (std.mem.eql(u8, ext, ".png")) return "image/png";
    if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) return "image/jpeg";
    if (std.mem.eql(u8, ext, ".ico")) return "image/x-icon";
    if (std.mem.eql(u8, ext, ".txt")) return "text/plain; charset=utf-8";
    return "application/octet-stream";
}

fn metode(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    const line = try parse_request_line(try args[0].as_str());
    return .{ .string = line.method };
}

fn sti(args: []const Value, _: *Interpreter) EvalError!Value {
    if (args.len != 1) return EvalError.TypeError;
    return .{ .string = try request_path(try args[0].as_str()) };
}

fn svar(args: []const Value, interp: *Interpreter) EvalError!Value {
    if (args.len != 3) return EvalError.TypeError;
    const status = try args[0].as_int();
    const content_type = try args[1].as_str();
    const body = try args[2].to_string(interp.str_alloc());
    return build_response(interp, status, content_type, body);
}

fn statisk(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 2) return EvalError.TypeError;

    const root = try resolve_root(interp, try args[0].as_str());
    const request = try args[1].as_str();
    const line = parse_request_line(request) catch {
        return build_response(interp, 400, "text/plain; charset=utf-8", "Bad Request");
    };

    if (!std.mem.eql(u8, line.method, "GET") and !std.mem.eql(u8, line.method, "HEAD")) {
        return build_response(interp, 405, "text/plain; charset=utf-8", "Method Not Allowed");
    }

    const path = request_path(request) catch {
        return build_response(interp, 400, "text/plain; charset=utf-8", "Bad Request");
    };
    const file_path = build_static_file_path(interp, root, path) catch |err| switch (err) {
        EvalError.AccessDenied => return build_response(interp, 403, "text/plain; charset=utf-8", "Forbidden"),
        else => return err,
    };

    const body = std.Io.Dir.cwd().readFileAlloc(interp.io, file_path, interp.str_alloc(), file_limit) catch |err| switch (map_file_error(err)) {
        EvalError.FileNotFound => return build_response(interp, 404, "text/plain; charset=utf-8", "Not Found"),
        EvalError.AccessDenied, EvalError.PermissionDenied => return build_response(interp, 403, "text/plain; charset=utf-8", "Forbidden"),
        else => return build_response(interp, 500, "text/plain; charset=utf-8", "Internal Server Error"),
    };

    if (std.mem.eql(u8, line.method, "HEAD")) {
        return build_response(interp, 200, guess_content_type(file_path), "");
    }
    return build_response(interp, 200, guess_content_type(file_path), body);
}
