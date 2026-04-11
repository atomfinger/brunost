const std = @import("std");
const main = @import("main.zig");

fn run_script(source: []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(std.testing.allocator);
    try main.run(std.testing.allocator, source, buf.writer(std.testing.allocator).any(), "");
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
    try expect_error(@embedFile("tests/feil_parse.brunost"), error.ExpectedIdentifier);
}

test "feil: ukjend modul" {
    try expect_error("bruk ukjendmodul", error.UnknownModule);
}

test "feil: modulnamn-konflikt" {
    try expect_error("bruk matte\nbruk matte", error.ModuleNameCollision);
}
