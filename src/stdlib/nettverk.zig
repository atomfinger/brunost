const std = @import("std");
const builtin = @import("builtin");
const interp_mod = @import("../interpreter.zig");
const Value = interp_mod.Value;
const EvalError = interp_mod.EvalError;
const Interpreter = interp_mod.Interpreter;
const Io = interp_mod.Io;
const ModuleMember = interp_mod.ModuleMember;

const net = std.Io.net;

pub fn make(alloc: std.mem.Allocator) EvalError!Value {
    const members = try alloc.dupe(ModuleMember, &[_]ModuleMember{
        .{ .name = "lytt",      .value = .{ .builtin_fn = lytt } },
        .{ .name = "port",      .value = .{ .builtin_fn = port } },
        .{ .name = "godta",      .value = .{ .builtin_fn = godta } },
        .{ .name = "kopleTil",  .value = .{ .builtin_fn = kopleTil } },
        .{ .name = "les",       .value = .{ .builtin_fn = les } },
        .{ .name = "skriv",     .value = .{ .builtin_fn = skriv } },
        .{ .name = "lukk",      .value = .{ .builtin_fn = lukk } },
        .{ .name = "handter",   .value = .{ .builtin_fn = handter } },
    });
    return Value{ .module = members };
}

fn ensure_native() EvalError!void {
    if (comptime builtin.cpu.arch == .wasm32) return EvalError.UnsupportedPlatform;
}

fn parse_port(value: Value) EvalError!u16 {
    const raw = try value.as_int();
    if (raw < 0 or raw > std.math.maxInt(u16)) return EvalError.InvalidPort;
    return @intCast(raw);
}

fn parse_ip_address(host: []const u8, port_num: u16) EvalError!net.IpAddress {
    return net.IpAddress.parse(host, port_num) catch EvalError.InvalidAddress;
}

fn map_listen_error(err: anyerror) EvalError {
    return switch (err) {
        error.AddressInUse => EvalError.AddressInUse,
        error.AddressUnavailable => EvalError.AddressUnavailable,
        error.NetworkDown => EvalError.NetworkDown,
        error.SystemResources => EvalError.SystemResources,
        error.ProcessFdQuotaExceeded, error.SystemFdQuotaExceeded => EvalError.SocketLimitExceeded,
        error.AddressFamilyUnsupported,
        error.ProtocolUnsupportedBySystem,
        error.ProtocolUnsupportedByAddressFamily,
        error.SocketModeUnsupported,
        error.OptionUnsupported,
        => EvalError.UnsupportedPlatform,
        else => EvalError.SystemResources,
    };
}

fn map_connect_error(err: anyerror) EvalError {
    return switch (err) {
        error.AddressUnavailable => EvalError.AddressUnavailable,
        error.AddressFamilyUnsupported => EvalError.InvalidAddress,
        error.SystemResources => EvalError.SystemResources,
        error.ConnectionRefused => EvalError.ConnectionRefused,
        error.ConnectionResetByPeer => EvalError.ConnectionResetByPeer,
        error.HostUnreachable => EvalError.HostUnreachable,
        error.NetworkUnreachable => EvalError.NetworkUnreachable,
        error.Timeout => EvalError.Timeout,
        error.ProcessFdQuotaExceeded, error.SystemFdQuotaExceeded => EvalError.SocketLimitExceeded,
        error.AccessDenied => EvalError.AccessDenied,
        error.NetworkDown => EvalError.NetworkDown,
        error.ConnectionPending,
        error.OptionUnsupported,
        error.ProtocolUnsupportedBySystem,
        error.ProtocolUnsupportedByAddressFamily,
        error.SocketModeUnsupported,
        error.WouldBlock,
        => EvalError.UnsupportedPlatform,
        else => EvalError.SystemResources,
    };
}

fn map_accept_error(err: anyerror) EvalError {
    return switch (err) {
        error.ProcessFdQuotaExceeded, error.SystemFdQuotaExceeded => EvalError.SocketLimitExceeded,
        error.SystemResources => EvalError.SystemResources,
        error.SocketNotListening => EvalError.SocketNotListening,
        error.NetworkDown => EvalError.NetworkDown,
        error.WouldBlock => EvalError.Timeout,
        error.ConnectionAborted => EvalError.ConnectionAborted,
        error.BlockedByFirewall => EvalError.AccessDenied,
        error.ProtocolFailure => EvalError.ConnectionAborted,
        else => EvalError.SystemResources,
    };
}

fn map_read_error(err: anyerror) EvalError {
    return switch (err) {
        error.SystemResources => EvalError.SystemResources,
        error.ConnectionResetByPeer => EvalError.ConnectionResetByPeer,
        error.Timeout => EvalError.Timeout,
        error.SocketUnconnected => EvalError.InvalidHandle,
        error.AccessDenied => EvalError.AccessDenied,
        error.NetworkDown => EvalError.NetworkDown,
        else => EvalError.SystemResources,
    };
}

fn map_write_error(err: anyerror) EvalError {
    return switch (err) {
        error.ConnectionResetByPeer => EvalError.ConnectionResetByPeer,
        error.SystemResources => EvalError.SystemResources,
        error.NetworkUnreachable => EvalError.NetworkUnreachable,
        error.HostUnreachable => EvalError.HostUnreachable,
        error.NetworkDown => EvalError.NetworkDown,
        error.ConnectionRefused => EvalError.ConnectionRefused,
        error.AddressFamilyUnsupported => EvalError.InvalidAddress,
        error.SocketUnconnected, error.SocketNotBound => EvalError.InvalidHandle,
        error.FastOpenAlreadyInProgress => EvalError.UnsupportedPlatform,
        else => EvalError.SystemResources,
    };
}

fn lytt(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 2) return EvalError.TypeError;
    const host = try args[0].as_str();
    const port_num = try parse_port(args[1]);
    const address = try parse_ip_address(host, port_num);
    const server = address.listen(interp.io, .{ .reuse_address = true }) catch |err| return map_listen_error(err);
    return interp.register_listener(server);
}

fn port(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 1) return EvalError.TypeError;
    return .{ .integer = try interp.local_port(args[0]) };
}

fn godta(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 1) return EvalError.TypeError;
    const server = try interp.require_listener(args[0]);
    const stream = server.accept(interp.io) catch |err| return map_accept_error(err);
    return interp.register_stream(stream);
}

fn kopleTil(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 2) return EvalError.TypeError;
    const host = try args[0].as_str();
    const port_num = try parse_port(args[1]);
    const address = try parse_ip_address(host, port_num);
    const stream = address.connect(interp.io, .{ .mode = .stream, .protocol = .tcp }) catch |err| return map_connect_error(err);
    return interp.register_stream(stream);
}

fn les(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 2) return EvalError.TypeError;
    const stream = try interp.require_stream(args[0]);
    const max_bytes = try args[1].as_int();
    if (max_bytes < 0) return EvalError.TypeError;
    if (max_bytes == 0) return .{ .string = "" };

    const dest = interp.str_alloc().alloc(u8, @intCast(max_bytes)) catch return EvalError.OutOfMemory;
    var reader_buffer: [1024]u8 = undefined;
    var reader = stream.reader(interp.io, &reader_buffer);
    var vecs: [1][]u8 = .{dest};
    const n = reader.interface.readVec(&vecs) catch |err| switch (err) {
        error.ReadFailed => return map_read_error(reader.err orelse err),
        error.EndOfStream => return .{ .null_val = {} },
    };
    return .{ .string = dest[0..n] };
}

fn skriv(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 2) return EvalError.TypeError;
    const stream = try interp.require_stream(args[0]);
    const bytes = try args[1].to_string(interp.str_alloc());
    var writer_buffer: [1024]u8 = undefined;
    var writer = stream.writer(interp.io, &writer_buffer);
    writer.interface.writeAll(bytes) catch |err| switch (err) {
        error.WriteFailed => return map_write_error(writer.err orelse err),
    };
    writer.interface.flush() catch |err| switch (err) {
        error.WriteFailed => return map_write_error(writer.err orelse err),
    };
    return .{ .integer = @intCast(bytes.len) };
}

fn lukk(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 1) return EvalError.TypeError;
    try interp.close_handle(args[0]);
    return .{ .null_val = {} };
}

const HandlerThreadContext = struct {
    func: Value,
    stream: net.Stream,
    listener_server: net.Server,
    main_listener_slot: *interp_mod.ResourceSlot,
    alloc: std.mem.Allocator,
    io: Io,
    output: *std.Io.Writer,
    base_dir: []const u8,
    debug: bool,
};

fn handler_thread_fn(ctx: *HandlerThreadContext) void {
    defer ctx.alloc.destroy(ctx);
    var thread_interp = Interpreter.init_for_handler_thread(
        ctx.alloc,
        ctx.io,
        ctx.output,
        ctx.base_dir,
        ctx.debug,
    );
    defer thread_interp.deinit();
    // Register listener first (id=1) so it aligns with the closure's lyttar handle.
    // Mirrored: closing this slot also deactivates the main interpreter's listener slot,
    // which causes the main accept() call to fail and handter to return.
    _ = thread_interp.register_listener_mirrored(ctx.listener_server, ctx.main_listener_slot) catch return;
    const stream_val = thread_interp.register_stream(ctx.stream) catch return;
    _ = thread_interp.call_callable(ctx.func, &[_]Value{stream_val}) catch {};
}

fn handter(args: []const Value, interp: *Interpreter) EvalError!Value {
    try ensure_native();
    if (args.len != 2) return EvalError.TypeError;
    const server = try interp.require_listener(args[0]);
    switch (args[1]) {
        .function, .builtin_fn => {},
        else => return EvalError.TypeError,
    }
    const callback = args[1];
    const main_listener_slot = try interp.listener_slot(args[0]);

    var threads: std.ArrayListUnmanaged(std.Thread) = .empty;
    defer threads.deinit(interp.alloc);

    while (true) {
        const stream = server.accept(interp.io) catch break;
        const ctx = interp.alloc.create(HandlerThreadContext) catch {
            stream.close(interp.io);
            break;
        };
        ctx.* = .{
            .func = callback,
            .stream = stream,
            .listener_server = server.*,
            .main_listener_slot = main_listener_slot,
            .alloc = interp.alloc,
            .io = interp.io,
            .output = interp.output,
            .base_dir = interp.base_dir,
            .debug = interp.debug,
        };
        const thread = std.Thread.spawn(.{}, handler_thread_fn, .{ctx}) catch {
            stream.close(interp.io);
            interp.alloc.destroy(ctx);
            continue;
        };
        threads.append(interp.alloc, thread) catch thread.detach();
    }

    for (threads.items) |t| t.join();
    return .{ .null_val = {} };
}
