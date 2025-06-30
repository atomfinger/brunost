const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("Brunost_Parser.zig");
const ast = @import("ast.zig");
const evaluator = @import("evaluator.zig");
const object = @import("object.zig");
const environment = @import("environment.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout_writer = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_writer);
    const stdout = bw.writer();

    if (args.len < 2) {
        try stdout.print("Bruk: brunost <filnavn.brunost>\n", .{});
        return;
    }

    const file_name = args[1];

    if (!std.mem.endsWith(u8, file_name, ".brunost")) {
        try stdout.print("Filnamnet må enda med '.brunost'\n", .{});
        return;
    }

    std.debug.print("--- Kjører Brunost-skript: {s} ---\n", .{file_name});
    try runFile(allocator, file_name, stdout);
    try bw.flush();
    std.debug.print("\n--- Ferdig med skript: {s} ---\n", .{file_name});
}

pub fn runFile(
    allocator: Allocator,
    file_name: []const u8,
    stdout: anytype,
) !void {
    const source_file_contents = std.fs.cwd().readFileAlloc(allocator, file_name, 1024 * 1024) catch |err| {
        try stdout.print("Kunne ikkje lesa fil '{s}': {s}\n", .{ file_name, @errorName(err) });
        return;
    };
    defer allocator.free(source_file_contents);

    std.debug.print("--- Kjeldekode ---\n{s}\n------------------\n", .{source_file_contents});

    // 1. Parsing
    var program_ast = parser.parse(source_file_contents, allocator) catch |parse_err| {
        try stdout.print("Parser-feil under kompilering av '{s}': {s}\n", .{ file_name, @errorName(parse_err) });
        // Even if parse returns an error, it might have accumulated errors in its internal list.
        // The current `parser.parse` signature returns `!ast.Program`, so internal errors are printed by `parse`.
        return;
    };
    defer program_ast.deinit(); // Ensure AST is deinitialized

    // `parser.parse` already prints its specific errors.
    // If `program_ast` is empty and no errors were printed by `parser.parse` itself throwing,
    // it implies syntax errors were found and handled by adding to internal error list.
    // The current `parser.parse` prints these errors.

    // For debugging: Print AST
    // var ast_buffer: [2048]u8 = undefined;
    // var ast_fbs = std.io.fixedBufferStream(&ast_buffer);
    // try program_ast.format(ast_fbs.writer(), 0);
    // std.debug.print("--- Parsa AST ---\n{s}\n---------------\n", .{ast_fbs.getWritten()});


    // 2. Evaluation (if parsing was successful, indicated by parse not throwing and AST possibly having statements)
    // We assume parser.parse would have printed specific errors if it couldn't produce a valid (even if empty) AST.
    // A more robust check could be if program_ast.statements.len > 0 or if parser had no errors explicitly.
    // For now, let's proceed to evaluation if parse didn't throw.

    std.debug.print("--- Startar evaluering ---\n", .{});
    var env = environment.Environment.init(allocator);
    defer env.deinit();

    // TODO: Add built-in functions to the environment here
    // E.g., env.declare("terminal", terminal_module_object, false);

    const evaluated_result = evaluator.eval(ast.Node{ .Program = program_ast }, &env, allocator) catch |eval_err| {
        try stdout.print("Runtime-feil: {s}\n", .{@errorName(eval_err)});
        // Potentially print more details if eval_err is a structured error object
        return;
    };

    // Deallocate the result object if it's not a singleton and was allocated by evaluator.eval
    // evaluator.eval is designed so that its direct return (if not Error/ReturnValue) is owned by caller.
    // Error and ReturnValue objects have their contents deallocated by their own .deinit if they wrap allocated things.
    if (evaluated_result != &object.TRUE and
        evaluated_result != &object.FALSE and
        evaluated_result != &object.NULL)
    {
        // If it's an Error or ReturnValue, its .deinit will handle the wrapped value.
        evaluated_result.deinit(allocator);
        allocator.destroy(evaluated_result);
    }


    std.debug.print("--- Evalueringsresultat (rå) ---\n", .{});
    // For now, just inspect the final object from the program evaluation (often NULL for programs)
    if (evaluated_result) |res| {
        var inspect_buffer: [1024]u8 = undefined;
        var inspect_fbs = std.io.fixedBufferStream(&inspect_buffer);
        res.inspect(inspect_fbs.writer()) catch {}; // Ignore inspect error for this debug print
        std.debug.print("{s}\n", .{inspect_fbs.getWritten()});
    } else {
        std.debug.print("Ingenting evaluert (resultat er nullpeikar).\n", .{});
    }
     std.debug.print("---------------------------\n", .{});
}

test "simple test" {
    // This test is not very relevant for the compiler/interpreter itself
    // but keeping it to ensure `zig build test` still has something to run from main.
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

// TODO: Add integration tests here that run small Brunost scripts
// For example:
// test "Run simple brunost script" {
//     const allocator = std.testing.allocator;
//     const test_script_content =
//         \\fast melding er "Hei frå Brunost!";
//         \\terminal.skriv(melding);
//     ;
//     // Need to mock terminal.skriv or capture its output
//     // This requires more setup for testing the evaluator's side effects.
// }
