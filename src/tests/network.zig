const std = @import("std");
const h = @import("../../src/test_helpers.zig");

test "nettverk: kopleTil, skriv, les og lukk" {
    const address = std.Io.net.IpAddress{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
    const server = try address.listen(std.testing.io, .{ .reuse_address = true });
    const port = server.socket.address.getPort();

    var server_result: h.EchoServerResult = .{};
    const server_thread = try std.Thread.spawn(.{}, h.run_echo_server, .{ &server_result, server });
    defer server_thread.join();

    const port_arg = try std.fmt.allocPrint(std.testing.allocator, "{d}", .{port});
    defer std.testing.allocator.free(port_arg);

    const out = try h.run_script_with_args(
        \\bruk nettverk
        \\bruk terminal
        \\bruk streng
        \\
        \\låst sokkel er nettverk.kopleTil("127.0.0.1", streng.tilTal(terminal.argument(0)))
        \\nettverk.skriv(sokkel, "ping")
        \\låst svar er nettverk.les(sokkel, 4)
        \\terminal.skriv(svar)
        \\nettverk.lukk(sokkel)
    ,
        &.{port_arg},
    );
    defer std.testing.allocator.free(out);

    try std.testing.expect(server_result.err == null);
    try std.testing.expectEqualStrings("ping", server_result.received[0..server_result.received_len]);
    try std.testing.expectEqualStrings("pong\n", out);
}

test "nettverk: lytt, godta, port og lukk" {
    const out = try h.run_script(
        \\bruk nettverk
        \\bruk terminal
        \\
        \\låst lyttar er nettverk.lytt("127.0.0.1", 0)
        \\terminal.skriv(nettverk.port(lyttar))
        \\nettverk.lukk(lyttar)
    );
    defer std.testing.allocator.free(out);

    const trimmed = std.mem.trim(u8, out, "\n");
    const parsed_port = try std.fmt.parseInt(u16, trimmed, 10);
    try std.testing.expect(parsed_port > 0);
}

test "fil: les og finnas" {
    const out = try h.run_script_with_base_dir(
        \\bruk fil
        \\bruk streng
        \\bruk terminal
        \\
        \\låst tekst er fil.les("www/index.html")
        \\terminal.skriv(streng.inneheld(tekst, "Brunost testside"))
        \\terminal.skriv(fil.finnas("www/style.css"))
        \\terminal.skriv(fil.finnas("www/manglar.txt"))
    ,
        "src/tests",
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("sant\nsant\nusant\n", out);
}

test "http: svar byggjer gyldig respons" {
    const out = try h.run_script(
        \\bruk http
        \\bruk terminal
        \\
        \\terminal.skriv(http.svar(200, "text/plain; charset=utf-8", "Hei"))
    );
    defer std.testing.allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "HTTP/1.1 200 OK\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "Content-Length: 3\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\r\n\r\nHei\n") != null);
}

test "nettverk: Brunost kan vere server" {
    const port = try h.choose_loopback_port();
    const port_arg = try std.fmt.allocPrint(std.testing.allocator, "{d}", .{port});
    defer std.testing.allocator.free(port_arg);

    var server_result: h.ThreadedScriptResult = .{};
    const server_thread = try std.Thread.spawn(.{}, h.run_script_in_thread, .{
        &server_result,
        \\bruk nettverk
        \\bruk terminal
        \\bruk streng
        \\
        \\låst tal er streng.tilTal(terminal.argument(0))
        \\låst lyttar er nettverk.lytt("127.0.0.1", tal)
        \\låst klient er nettverk.godta(lyttar)
        \\låst svar er nettverk.les(klient, 4)
        \\terminal.skriv(svar)
        \\nettverk.skriv(klient, "pong")
        \\nettverk.lukk(klient)
        \\nettverk.lukk(lyttar)
        ,
        &.{port_arg},
    });
    var joined = false;
    var stream = h.connect_loopback_with_retry(port) catch |err| {
        server_thread.join();
        joined = true;
        if (server_result.err) |thread_err| return thread_err;
        return err;
    };
    defer stream.close(std.testing.io);

    var writer_buffer: [128]u8 = undefined;
    var writer = stream.writer(std.testing.io, &writer_buffer);
    try writer.interface.writeAll("ping");
    try writer.interface.flush();

    var reader_buffer: [128]u8 = undefined;
    var reader = stream.reader(std.testing.io, &reader_buffer);
    var reply: [4]u8 = undefined;
    const reply_len = try reader.interface.readSliceShort(&reply);

    if (!joined) {
        server_thread.join();
        joined = true;
    }

    try std.testing.expect(server_result.err == null);
    defer if (server_result.output.len > 0) std.heap.page_allocator.free(server_result.output);
    try std.testing.expectEqualStrings("ping\n", server_result.output);
    try std.testing.expectEqualStrings("pong", reply[0..reply_len]);
}

test "http: Brunost kan serve statiske filer" {
    const port = try h.choose_loopback_port();
    const port_arg = try std.fmt.allocPrint(std.testing.allocator, "{d}", .{port});
    defer std.testing.allocator.free(port_arg);

    var server_result: h.ThreadedScriptResult = .{};
    const server_thread = try std.Thread.spawn(.{}, h.run_script_in_thread_with_base_dir, .{
        &server_result,
        \\bruk nettverk
        \\bruk http
        \\bruk streng
        \\bruk terminal
        \\
        \\låst tal er streng.tilTal(terminal.argument(0))
        \\låst lyttar er nettverk.lytt("127.0.0.1", tal)
        \\låst klient er nettverk.godta(lyttar)
        \\låst tekst er nettverk.les(klient, 4096)
        \\nettverk.skriv(klient, http.statisk("www", tekst))
        \\nettverk.lukk(klient)
        \\nettverk.lukk(lyttar)
        ,
        "src/tests",
        &.{port_arg},
    });

    var stream = h.connect_loopback_with_retry(port) catch |err| {
        server_thread.join();
        if (server_result.err) |thread_err| return thread_err;
        return err;
    };
    defer stream.close(std.testing.io);

    var writer_buffer: [256]u8 = undefined;
    var writer = stream.writer(std.testing.io, &writer_buffer);
    try writer.interface.writeAll("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n");
    try writer.interface.flush();

    var reader_buffer: [256]u8 = undefined;
    var reader = stream.reader(std.testing.io, &reader_buffer);
    const response = try reader.interface.allocRemaining(std.testing.allocator, .limited(8192));
    defer std.testing.allocator.free(response);

    server_thread.join();

    try std.testing.expect(server_result.err == null);
    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 200 OK\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "Content-Type: text/html; charset=utf-8\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "Brunost testside") != null);
}

test "nettverk: handter - enkelt ekko" {
    const port = try h.choose_loopback_port();
    const port_arg = try std.fmt.allocPrint(std.testing.allocator, "{d}", .{port});
    defer std.testing.allocator.free(port_arg);

    var server_result: h.ThreadedScriptResult = .{};
    const server_thread = try std.Thread.spawn(.{}, h.run_script_in_thread, .{
        &server_result,
        \\bruk nettverk
        \\bruk terminal
        \\bruk streng
        \\
        \\låst tal er streng.tilTal(terminal.argument(0))
        \\låst lyttar er nettverk.lytt("127.0.0.1", tal)
        \\
        \\gjer handlar(straum) {
        \\    låst tekst er nettverk.les(straum, 1024)
        \\    nettverk.skriv(straum, tekst)
        \\    nettverk.lukk(straum)
        \\    nettverk.lukk(lyttar)
        \\}
        \\
        \\nettverk.handter(lyttar, handlar)
        ,
        &.{port_arg},
    });

    var stream = h.connect_loopback_with_retry(port) catch |err| {
        server_thread.join();
        if (server_result.err) |thread_err| {
            std.debug.print("\nserver thread error: {}\n", .{thread_err});
            return thread_err;
        }
        std.debug.print("\nclient connect error (server_result.err null): {}\n", .{err});
        return err;
    };
    defer stream.close(std.testing.io);

    var writer_buffer: [128]u8 = undefined;
    var writer = stream.writer(std.testing.io, &writer_buffer);
    try writer.interface.writeAll("ping");
    try writer.interface.flush();

    var reader_buffer: [128]u8 = undefined;
    var reader = stream.reader(std.testing.io, &reader_buffer);
    var reply: [4]u8 = undefined;
    const reply_len = try reader.interface.readSliceShort(&reply);

    server_thread.join();

    try std.testing.expect(server_result.err == null);
    try std.testing.expectEqualStrings("ping", reply[0..reply_len]);
}

test "nettverk: handter - samtidige tilkoplingar" {
    const port = try h.choose_loopback_port();
    const port_arg = try std.fmt.allocPrint(std.testing.allocator, "{d}", .{port});
    defer std.testing.allocator.free(port_arg);

    var server_result: h.ThreadedScriptResult = .{};
    const server_thread = try std.Thread.spawn(.{}, h.run_script_in_thread, .{
        &server_result,
        \\bruk nettverk
        \\bruk streng
        \\bruk terminal
        \\
        \\låst tal er streng.tilTal(terminal.argument(0))
        \\låst lyttar er nettverk.lytt("127.0.0.1", tal)
        \\
        \\gjer handlar(straum) {
        \\    låst tekst er nettverk.les(straum, 1024)
        \\    viss (tekst erSameSom "stopp") gjer {
        \\        nettverk.lukk(straum)
        \\        nettverk.lukk(lyttar)
        \\    } elles {
        \\        nettverk.skriv(straum, tekst)
        \\        nettverk.lukk(straum)
        \\    }
        \\}
        \\
        \\nettverk.handter(lyttar, handlar)
        ,
        &.{port_arg},
    });

    const ClientResult = struct {
        reply: [8]u8 = undefined,
        reply_len: usize = 0,
        err: ?anyerror = null,
    };

    const connect_and_exchange = struct {
        fn run(result: *ClientResult, p: u16, msg: []const u8) void {
            const addr = std.Io.net.IpAddress{ .ip4 = std.Io.net.Ip4Address.loopback(p) };
            var attempts: usize = 0;
            var s = while (true) : (attempts += 1) {
                const conn = addr.connect(std.testing.io, .{ .mode = .stream, .protocol = .tcp }) catch |err| switch (err) {
                    error.ConnectionRefused => {
                        if (attempts >= 19) { result.err = err; return; }
                        std.Io.sleep(std.testing.io, .fromMilliseconds(25), .awake) catch {};
                        continue;
                    },
                    else => { result.err = err; return; },
                };
                break conn;
            };
            defer s.close(std.testing.io);
            var wb: [32]u8 = undefined;
            var w = s.writer(std.testing.io, &wb);
            w.interface.writeAll(msg) catch |err| { result.err = err; return; };
            w.interface.flush() catch |err| { result.err = err; return; };
            var rb: [32]u8 = undefined;
            var r = s.reader(std.testing.io, &rb);
            result.reply_len = r.interface.readSliceShort(result.reply[0..msg.len]) catch |err| { result.err = err; return; };
        }
    }.run;

    var r1: ClientResult = .{};
    var r2: ClientResult = .{};
    const t1 = try std.Thread.spawn(.{}, connect_and_exchange, .{ &r1, port, "hei" });
    const t2 = try std.Thread.spawn(.{}, connect_and_exchange, .{ &r2, port, "bye" });
    t1.join();
    t2.join();

    try std.testing.expect(r1.err == null);
    try std.testing.expect(r2.err == null);
    try std.testing.expectEqualStrings("hei", r1.reply[0..r1.reply_len]);
    try std.testing.expectEqualStrings("bye", r2.reply[0..r2.reply_len]);

    var stop_stream = h.connect_loopback_with_retry(port) catch |err| {
        server_thread.join();
        return err;
    };
    var wb: [8]u8 = undefined;
    var w = stop_stream.writer(std.testing.io, &wb);
    try w.interface.writeAll("stopp");
    try w.interface.flush();
    stop_stream.close(std.testing.io);

    server_thread.join();
    try std.testing.expect(server_result.err == null);
}

test "http: statisk sperrar vegklatring" {
    const out = try h.run_script(
        \\bruk http
        \\bruk terminal
        \\
        \\terminal.skriv(http.statisk("www", "GET /../hemmelig.txt HTTP/1.1\r\n\r\n"))
    );
    defer std.testing.allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "HTTP/1.1 403 Forbidden\r\n") != null);
}
