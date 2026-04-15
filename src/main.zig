const std = @import("std");
const token = @import("token.zig");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");

const FileWriter = std.io.GenericWriter(std.fs.File, std.fs.File.WriteError, std.fs.File.write);

fn stdout_writer() std.io.AnyWriter {
    return (FileWriter{ .context = std.fs.File.stdout() }).any();
}

fn stderr_writer() std.io.AnyWriter {
    return (FileWriter{ .context = std.fs.File.stderr() }).any();
}

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

fn print_parse_error(writer: std.io.AnyWriter, diagnostic: parser.ParseDiagnostic) !void {
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.skip(); // argv[0]
    const first_arg = args.next() orelse {
        stderr_writer().print("Bruk: brunost [--debug] <fil.brunost>\n", .{}) catch {};
        std.process.exit(1);
    };
    var debug = false;
    const filename: []const u8 = blk: {
        if (std.mem.eql(u8, first_arg, "--debug")) {
            debug = true;
            break :blk args.next() orelse {
                stderr_writer().print("Bruk: brunost [--debug] <fil.brunost>\n", .{}) catch {};
                std.process.exit(1);
            };
        }
        break :blk first_arg;
    };
    var script_args: std.ArrayList([]const u8) = .{};
    defer script_args.deinit(alloc);
    while (args.next()) |arg| {
        try script_args.append(alloc, arg);
    }

    const source = std.fs.cwd().readFileAlloc(alloc, filename, 10 * 1024 * 1024) catch |err| {
        stderr_writer().print("Feil: Kunne ikkje lesa fila '{s}': {s}\n", .{ filename, describe_error(err) }) catch {};
        std.process.exit(1);
    };
    defer alloc.free(source);

    const base_dir = std.fs.path.dirname(filename) orelse ".";
    var context: RunContext = .{ .debug = debug };
    run_with_context(alloc, source, stdout_writer(), base_dir, script_args.items, &context) catch |err| {
        if (err == error.ParseFailed) {
            if (context.parse_diagnostic) |diagnostic| {
                print_parse_error(stderr_writer(), diagnostic) catch {};
            } else {
                stderr_writer().print("Feil: {s}\n", .{describe_error(err)}) catch {};
            }
        } else {
            stderr_writer().print("Feil: {s}\n", .{describe_error(err)}) catch {};
        }
        std.process.exit(1);
    };
}

pub fn run(alloc: std.mem.Allocator, source: []const u8, output: std.io.AnyWriter, base_dir: []const u8) !void {
    try run_with_args(alloc, source, output, base_dir, &.{});
}

pub fn run_with_args(
    alloc: std.mem.Allocator,
    source: []const u8,
    output: std.io.AnyWriter,
    base_dir: []const u8,
    script_args: []const []const u8,
) !void {
    var context: RunContext = .{};
    try run_with_context(alloc, source, output, base_dir, script_args, &context);
}

pub fn run_with_context(
    alloc: std.mem.Allocator,
    source: []const u8,
    output: std.io.AnyWriter,
    base_dir: []const u8,
    script_args: []const []const u8,
    context: *RunContext,
) !void {
    const is_wasm = comptime @import("builtin").cpu.arch == .wasm32;

    if (comptime !is_wasm) {
        if (context.debug) {
            const dbg_w = stderr_writer();
            dbg_w.print("[debug] === Tokens ===\n", .{}) catch {};
            var dbg_lexer = token.Lexer.init(source);
            while (true) {
                const tok = dbg_lexer.next_token();
                dbg_w.print("[debug]   {s:<24} '{s}'\n", .{ @tagName(tok.type), tok.literal }) catch {};
                if (tok.type == .eof) break;
            }
            dbg_w.print("[debug] === Parsing ===\n", .{}) catch {};
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
            const dbg_w = stderr_writer();
            dbg_w.print("[debug]   {} setning(ar) tolka\n", .{program.program.statements.len}) catch {};
            dbg_w.print("[debug] === Evaluering ===\n", .{}) catch {};
        }
    }

    var interp = interpreter.Interpreter.init(alloc, output, base_dir, script_args);
    interp.debug = if (comptime is_wasm) false else context.debug;
    defer interp.deinit();
    _ = try interp.eval(program, &interp.global);
}
