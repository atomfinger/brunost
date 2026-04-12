const std = @import("std");
const main = @import("main.zig");
const parser = @import("parser.zig");

fn run_script(source: []const u8) ![]u8 {
    return run_script_with_args(source, &.{});
}

fn run_script_with_args(source: []const u8, script_args: []const []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(std.testing.allocator);
    try main.run_with_args(std.testing.allocator, source, buf.writer(std.testing.allocator).any(), "", script_args);
    return buf.toOwnedSlice(std.testing.allocator);
}

fn expect_error(source: []const u8, expected: anyerror) !void {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(std.testing.allocator);
    try std.testing.expectError(
        expected,
        main.run(std.testing.allocator, source, buf.writer(std.testing.allocator).any(), ""),
    );
}

fn expect_parse_error(source: []const u8, expected: parser.ParseError) !main.RunContext {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(std.testing.allocator);

    var context: main.RunContext = .{};
    try std.testing.expectError(
        error.ParseFailed,
        main.run_with_context(
            std.testing.allocator,
            source,
            buf.writer(std.testing.allocator).any(),
            "",
            &.{},
            &context,
        ),
    );
    try std.testing.expect(context.parse_diagnostic != null);
    try std.testing.expectEqual(expected, context.parse_diagnostic.?.err);
    return context;
}

test "hello world" {
    const out = try run_script(@embedFile("tests/hello.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Hei, verd!\n", out);
}

test "variables" {
    const out = try run_script(@embedFile("tests/variables.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n15\nHei\nsant\n", out);
}

test "arithmetic" {
    const out = try run_script(@embedFile("tests/arithmetic.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("7\n7\n42\n5\n14\n", out);
}

test "functions" {
    const out = try run_script(@embedFile("tests/functions.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\nHei, Ola!\n", out);
}

test "control flow" {
    const out = try run_script(@embedFile("tests/control_flow.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("ein\nstort\n", out);
}

test "loops" {
    const out = try run_script(@embedFile("tests/loops.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n2\n3\n1\n2\n3\n", out);
}

test "stdlib matte" {
    const out = try run_script(@embedFile("tests/stdlib_matte.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("5\n7\n3\n", out);
}

test "comparisons" {
    const out = try run_script(@embedFile("tests/comparisons.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("sant\nsant\nsant\nsant\nsant\nsant\nusant\nusant\nusant\nusant\n", out);
}

test "fizzbuzz" {
    const out = try run_script(@embedFile("tests/fizzbuzz.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz\n", out);
}

test "fibonacci" {
    const out = try run_script(@embedFile("tests/fibonacci.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("0\n1\n1\n2\n3\n5\n8\n", out);
}

test "stdlib streng" {
    const out = try run_script(@embedFile("tests/stdlib_streng.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("5\n42\n", out);
}

test "stdlib liste" {
    const out = try run_script(@embedFile("tests/stdlib_liste.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3\n10\n30\n4\n", out);
}

test "brukar modul" {
    const out = try run_script(@embedFile("tests/brukar_modul.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n16\n", out);
}

test "modulus" {
    const out = try run_script(@embedFile("tests/modulus.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n", out);
}

test "fil-import: bruk hjelp.rekning som rekn" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(std.testing.allocator);
    try main.run(
        std.testing.allocator,
        @embedFile("tests/fil_import_alias.brunost"),
        buf.writer(std.testing.allocator).any(),
        "src/tests",
    );
    const out = try buf.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("15\n42\n", out);
}

test "fil-import: bruk hjelp.rekning" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(std.testing.allocator);
    try main.run(
        std.testing.allocator,
        @embedFile("tests/fil_import.brunost"),
        buf.writer(std.testing.allocator).any(),
        "src/tests",
    );
    const out = try buf.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("7\n12\n", out);
}

test "feil: endra uforanderleg variabel" {
    try expect_error(@embedFile("tests/feil_uforanderleg.brunost"), error.ImmutableAssignment);
}

test "feil: udefinert variabel" {
    try expect_error(@embedFile("tests/feil_udefinert.brunost"), error.UndefinedVariable);
}

test "feil: divisjon med null" {
    try expect_error(@embedFile("tests/feil_del_paa_null.brunost"), error.DivisionByZero);
}

test "feil: typefeil aritmetikk" {
    try expect_error(@embedFile("tests/feil_typefeil.brunost"), error.TypeError);
}

test "feil: ugyldig syntaks" {
    _ = try expect_parse_error(@embedFile("tests/feil_parse.brunost"), error.ExpectedIdentifier);
}

test "feil: parse diagnostic includes offending identifier" {
    const context = try expect_parse_error("fast foo er 1", error.NotNynorsk);
    const diagnostic = context.parse_diagnostic.?;
    try std.testing.expectEqualStrings("foo", diagnostic.literal);
    try std.testing.expectEqual(@as(usize, 1), diagnostic.line);
    try std.testing.expectEqual(@as(usize, 6), diagnostic.column);
}

test "identifiers with æøå from dictionary are accepted" {
    const out = try run_script(
        \\fast ære er 1
        \\fast høgd er 30
        \\fast år er 2026
        \\
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "feil: ukjend modul" {
    try expect_error("bruk ukjendmodul", error.UnknownModule);
}

test "feil: modulnamn-konflikt" {
    try expect_error("bruk matte\nbruk matte", error.ModuleNameCollision);
}

test "terminal argument les frå script-argument" {
    const out = try run_script_with_args(
        \\bruk terminal
        \\terminal.skriv(terminal.argument(0))
        \\terminal.skriv(terminal.argument(1))
        ,
        &.{ "12", "34" },
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("12\n34\n", out);
}

test "terminal argument gir indeksfeil utan verdi" {
    try expect_error(
        \\bruk terminal
        \\terminal.skriv(terminal.argument(0))
    , error.IndexOutOfBounds);
}
