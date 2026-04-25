const std = @import("std");
const builtin = @import("builtin");
const token = @import("token.zig");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");

pub fn describe_error(err: anyerror) []const u8 {
    return switch (err) {
        // Tolkarfeil
        error.ImmutableAssignment => "Kan ikkje endra ein uforanderleg variabel (deklarert med 'l\xc3\xa5st')",
        error.UndefinedVariable => "Variabelen er ikkje definert",
        error.TypeError => "Typefeil: operasjonen støttar ikkje desse typane",
        error.DivisionByZero => "Kan ikkje dela på null",
        error.IndexOutOfBounds => "Indeks er utanfor grensa til lista",
        error.UnknownBuiltin => "Ukjend innebygd funksjon",
        error.UnknownModule => "Ukjend innebygd modul",
        error.ModuleNameCollision => "Modulnamn-konflikt — bruk 'som' for å gje modulen eit anna namn",
        error.ModuleNotFound => "Kunne ikkje finna modulfila",
        error.UndefinedField => "Feltet er ikkje definert i typen",
        error.ImmutableField => "Kan ikkje endra eit uforanderleg felt (deklarert med 'l\xc3\xa5st')",
        error.NotAStructType => "Namnet er ikkje ein kjend type",
        error.InvalidAddress => "Ugyldig IP-adresse",
        error.InvalidPort => "Ugyldig portnummer",
        error.InvalidHandle => "Ugyldig eller lukka nettverkshandtak",
        error.UnsupportedPlatform => "Denne funksjonen er ikkje tilgjengeleg på denne plattforma",
        error.AddressInUse => "Adressa er allereie i bruk",
        error.AddressUnavailable => "Adressa er ikkje tilgjengeleg",
        error.ConnectionRefused => "Tilkoplinga vart avvist",
        error.ConnectionAborted => "Tilkoplinga vart avbroten",
        error.ConnectionResetByPeer => "Tilkoplinga vart avslutta av motparten",
        error.HostUnreachable => "Fann ikkje vegen til verten",
        error.NetworkUnreachable => "Nettverket er ikkje tilgjengeleg",
        error.NetworkDown => "Nettverket er nede",
        error.SocketNotListening => "Sokkelen lyttar ikkje lenger",
        error.AccessDenied => "Tilgang nekta",
        error.Timeout => "Operasjonen gjekk ut på tid",
        error.SystemResources => "Operativsystemet manglar ressursar til nettverksoperasjonen",
        error.SocketLimitExceeded => "For mange opne soklar",
        // Parserfeil
        error.UnexpectedToken => "Uventa teikn i koden",
        error.ExpectedIdentifier => "Forventa eit namn her",
        error.ExpectedAssign => "Forventa 'er'",
        error.ExpectedBoolVal => "Forventa 'sant' eller 'usant'",
        error.ExpectedDo => "Forventa 'gjer'",
        error.ExpectedIn => "Forventa 'i'",
        error.ExpectedOpenParen => "Forventa '('",
        error.ExpectedCloseParen => "Forventa ')'",
        error.ExpectedOpenBrace => "Forventa '{'",
        error.ExpectedCloseBrace => "Forventa '}'",
        error.ExpectedCloseBracket => "Forventa ']'",
        error.InvalidInteger => "Ugyldig heiltal",
        error.InvalidFloat => "Ugyldig desimaltal",
        error.NotNynorsk => "Namnet er ikkje gyldig nynorsk",
        error.ParseFailed => "Kunne ikkje tolka koden",
        // Generelt
        error.OutOfMemory => "Minnet er tomt",
        else => @errorName(err),
    };
}

pub const RunContext = struct {
    parse_diagnostic: ?parser.ParseDiagnostic = null,
    debug: bool = false,
};

fn print_parse_error(writer: *std.Io.Writer, diagnostic: parser.ParseDiagnostic) !void {
    const base_message = describe_error(diagnostic.err);
    if (diagnostic.literal.len > 0) {
        try writer.print(
            "Feil: {s}: '{s}' på linje {d}, kolonne {d}\n",
            .{ base_message, diagnostic.literal, diagnostic.line, diagnostic.column },
        );
        return;
    }

    try writer.print(
        "Feil: {s} ved token {s} på linje {d}, kolonne {d}\n",
        .{ base_message, @tagName(diagnostic.token_type), diagnostic.line, diagnostic.column },
    );
}

pub fn main(init: std.process.Init.Minimal) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const io = std.Options.debug_io;

    var stdout_buf: [16384]u8 = undefined;
    var stdout_fw = std.Io.File.stdout().writer(io, &stdout_buf);
    defer stdout_fw.flush() catch {};

    var stderr_buf: [512]u8 = undefined;
    var stderr_fw = std.Io.File.stderr().writer(io, &stderr_buf);
    defer stderr_fw.flush() catch {};

    var args_it = if (comptime builtin.os.tag == .windows)
        try std.process.Args.Iterator.initAllocator(init.args, alloc)
    else
        std.process.Args.Iterator.init(init.args);
    defer if (comptime builtin.os.tag == .windows) args_it.deinit();
    _ = args_it.skip(); // skip argv[0]
    const first_arg = args_it.next() orelse {
        stderr_fw.interface.print("Bruk: brunost [--debug] <fil.brunost>\n", .{}) catch {};
        stderr_fw.flush() catch {};
        std.process.exit(1);
    };
    var debug = false;
    const filename: []const u8 = blk: {
        if (std.mem.eql(u8, first_arg, "--debug")) {
            debug = true;
            break :blk args_it.next() orelse {
                stderr_fw.interface.print("Bruk: brunost [--debug] <fil.brunost>\n", .{}) catch {};
                stderr_fw.flush() catch {};
                std.process.exit(1);
            };
        }
        break :blk first_arg;
    };
    var script_args: std.ArrayList([]const u8) = .empty;
    defer script_args.deinit(alloc);
    while (args_it.next()) |arg| {
        try script_args.append(alloc, arg);
    }

    const source = std.Io.Dir.cwd().readFileAlloc(io, filename, alloc, .limited(10 * 1024 * 1024)) catch |err| {
        stderr_fw.interface.print("Feil: Kunne ikkje lesa fila '{s}': {s}\n", .{ filename, describe_error(err) }) catch {};
        stderr_fw.flush() catch {};
        std.process.exit(1);
    };
    defer alloc.free(source);

    const base_dir = std.fs.path.dirname(filename) orelse ".";
    var context: RunContext = .{ .debug = debug };
    run_with_context(alloc, source, &stdout_fw.interface, base_dir, script_args.items, &context) catch |err| {
        if (err == error.ParseFailed) {
            if (context.parse_diagnostic) |diagnostic| {
                print_parse_error(&stderr_fw.interface, diagnostic) catch {};
            } else {
                stderr_fw.interface.print("Feil: {s}\n", .{describe_error(err)}) catch {};
            }
        } else {
            stderr_fw.interface.print("Feil: {s}\n", .{describe_error(err)}) catch {};
        }
        stderr_fw.flush() catch {};
        std.process.exit(1);
    };
}

pub fn run(alloc: std.mem.Allocator, source: []const u8, output: *std.Io.Writer, base_dir: []const u8) !void {
    try run_with_args(alloc, source, output, base_dir, &.{});
}

pub fn run_with_args(
    alloc: std.mem.Allocator,
    source: []const u8,
    output: *std.Io.Writer,
    base_dir: []const u8,
    script_args: []const []const u8,
) !void {
    var context: RunContext = .{};
    try run_with_context(alloc, source, output, base_dir, script_args, &context);
}

pub fn run_with_context(
    alloc: std.mem.Allocator,
    source: []const u8,
    output: *std.Io.Writer,
    base_dir: []const u8,
    script_args: []const []const u8,
    context: *RunContext,
) !void {
    const is_wasm = comptime @import("builtin").cpu.arch == .wasm32;

    if (comptime !is_wasm) {
        if (context.debug) {
            std.debug.print("[debug] === Tokens ===\n", .{});
            var dbg_lexer = token.Lexer.init(source);
            while (true) {
                const tok = dbg_lexer.next_token();
                std.debug.print("[debug]   {s:<24} '{s}'\n", .{ @tagName(tok.type), tok.literal });
                if (tok.type == .eof) break;
            }
            std.debug.print("[debug] === Parsing ===\n", .{});
        }
    }

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const lexer = token.Lexer.init(source);
    var p = parser.Parser.init(lexer, arena_alloc);
    const program = p.parse_program() catch |err| {
        context.parse_diagnostic = p.current_diagnostic(err);
        return error.ParseFailed;
    };

    if (comptime !is_wasm) {
        if (context.debug) {
            std.debug.print("[debug]   {} setning(ar) tolka\n", .{program.program.statements.len});
            std.debug.print("[debug] === Evaluering ===\n", .{});
        }
    }

    var interp = interpreter.Interpreter.init(alloc, output, base_dir, script_args);
    interp.debug = if (comptime is_wasm) false else context.debug;
    defer interp.deinit();
    _ = try interp.eval(program, &interp.global);
}
