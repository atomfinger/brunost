const std = @import("std");
const main = @import("main.zig");
const parser = @import("parser.zig");

pub fn run_script(source: []const u8) ![]u8 {
    return run_script_with_args(source, &.{});
}

pub fn run_script_with_args(source: []const u8, script_args: []const []const u8) ![]u8 {
    return run_script_with_base_dir_and_args(source, "", script_args);
}

pub fn run_script_with_base_dir(source: []const u8, base_dir: []const u8) ![]u8 {
    return run_script_with_base_dir_and_args(source, base_dir, &.{});
}

pub fn run_script_with_base_dir_and_args(
    source: []const u8,
    base_dir: []const u8,
    script_args: []const []const u8,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try main.run_with_args(std.testing.allocator, std.testing.io, source, &aw.writer, base_dir, script_args);
    return aw.toOwnedSlice();
}

pub fn expect_error(source: []const u8, expected: anyerror) !void {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try std.testing.expectError(
        expected,
        main.run(std.testing.allocator, std.testing.io, source, &aw.writer, ""),
    );
}

pub fn expect_parse_error(source: []const u8, expected: parser.ParseError) !main.RunContext {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();

    var context: main.RunContext = .{};
    try std.testing.expectError(
        error.ParseFailed,
        main.run_with_context(
            std.testing.allocator,
            std.testing.io,
            source,
            &aw.writer,
            "",
            &.{},
            &context,
        ),
    );
    try std.testing.expect(context.parse_diagnostic != null);
    try std.testing.expectEqual(expected, context.parse_diagnostic.?.err);
    return context;
}

pub const ThreadedScriptResult = struct {
    err: ?anyerror = null,
    output: []u8 = &.{},
};

pub fn run_script_in_thread(result: *ThreadedScriptResult, source: []const u8, script_args: []const []const u8) void {
    run_script_in_thread_with_base_dir(result, source, "", script_args);
}

pub fn run_script_in_thread_with_base_dir(
    result: *ThreadedScriptResult,
    source: []const u8,
    base_dir: []const u8,
    script_args: []const []const u8,
) void {
    var aw: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer aw.deinit();

    main.run_with_args(std.heap.page_allocator, std.testing.io, source, &aw.writer, base_dir, script_args) catch |err| {
        result.err = err;
        return;
    };

    result.output = aw.toOwnedSlice() catch |err| {
        result.err = err;
        return;
    };
}

pub const EchoServerResult = struct {
    err: ?anyerror = null,
    received: [16]u8 = undefined,
    received_len: usize = 0,
};

pub fn run_echo_server(result: *EchoServerResult, server: std.Io.net.Server) void {
    var local_server = server;
    defer local_server.deinit(std.testing.io);

    var stream = local_server.accept(std.testing.io) catch |err| {
        result.err = err;
        return;
    };
    defer stream.close(std.testing.io);

    var reader_buffer: [128]u8 = undefined;
    var reader = stream.reader(std.testing.io, &reader_buffer);
    result.received_len = reader.interface.readSliceShort(result.received[0..4]) catch |err| {
        result.err = reader.err orelse err;
        return;
    };

    var writer_buffer: [128]u8 = undefined;
    var writer = stream.writer(std.testing.io, &writer_buffer);
    writer.interface.writeAll("pong") catch |err| {
        result.err = writer.err orelse err;
        return;
    };
    writer.interface.flush() catch |err| {
        result.err = writer.err orelse err;
        return;
    };
}

pub fn choose_loopback_port() !u16 {
    const address = std.Io.net.IpAddress{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
    var server = try address.listen(std.testing.io, .{ .reuse_address = true });
    defer server.deinit(std.testing.io);
    return server.socket.address.getPort();
}

pub fn connect_loopback_with_retry(port: u16) !std.Io.net.Stream {
    const address = std.Io.net.IpAddress{ .ip4 = std.Io.net.Ip4Address.loopback(port) };
    var attempts: usize = 0;
    while (true) : (attempts += 1) {
        return address.connect(std.testing.io, .{ .mode = .stream, .protocol = .tcp }) catch |err| switch (err) {
            error.ConnectionRefused => {
                if (attempts >= 19) return err;
                std.Io.sleep(std.testing.io, .fromMilliseconds(25), .awake) catch {};
                continue;
            },
            else => return err,
        };
    }
}
