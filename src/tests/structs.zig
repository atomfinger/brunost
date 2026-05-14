const std = @import("std");
const h = @import("../../src/test_helpers.zig");

test "type: les felt" {
    const out = try h.run_script(@embedFile("type_grunnleggjande.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\n5\n", out);
}

test "type: oppdater open felt" {
    const out = try h.run_script(@embedFile("type_oppdatering.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n", out);
}

test "type: standardverdiar" {
    const out = try h.run_script(@embedFile("type_standard.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Honda\n0\n", out);
}

test "type: i liste" {
    const out = try h.run_script(@embedFile("type_liste.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\nHonda\n", out);
}

test "type: som parameter" {
    const out = try h.run_script(@embedFile("type_funksjon.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\n5\n", out);
}

test "type: skriv som json" {
    const out = try h.run_script(@embedFile("type_json.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("{\"namn\": \"Toyota\", \"alder\": 5}\n", out);
}

test "type: viss med felt-samanlikning" {
    const out = try h.run_script(@embedFile("type_viss.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Bilen er 5 år gamal\nDet er ein Toyota\nBilen er meir enn 3 år\n", out);
}

test "type: forKvart over listfelt" {
    const out = try h.run_script(@embedFile("type_forkvart_felt.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\nHonda\nVolvo\n1\n2\n3\n", out);
}

test "streng: reverser" {
    const out = try h.run_script(
        \\bruk terminal
        \\bruk streng
        \\terminal.skriv(streng.reverser("123"))
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("321\n", out);
}

test "streng: inneheld" {
    const out = try h.run_script(
        \\bruk streng
        \\bruk terminal
        \\terminal.skriv(streng.inneheld("Hello verda!", "verda"))
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("sant\n", out);
}

test "feil: endra låst felt" {
    try h.expect_error(
        \\type Bil {
        \\    låst namn er "ukjend"
        \\    open alder er 0
        \\}
        \\open minBil er Bil { namn er "Toyota", alder er 5 }
        \\minBil.namn er "Honda"
    , error.ImmutableField);
}

test "feil: påkravd felt manglar" {
    try h.expect_error(
        \\type Bil {
        \\    låst namn er "ukjend"
        \\    open alder
        \\}
        \\låst minBil er Bil { namn er "Toyota" }
    , error.UndefinedField);
}

test "feil: ukjent type" {
    try h.expect_error(
        \\låst minBil er ukjendType { namn er "Toyota" }
    , error.UndefinedVariable);
}

test "feil: type-namn er ikkje nynorsk" {
    _ = try h.expect_parse_error(
        \\type fooBar {
        \\    låst namn er "x"
        \\}
    , error.NotNynorsk);
}

test "feil: feltnamn er ikkje nynorsk" {
    _ = try h.expect_parse_error(
        \\type Bil {
        \\    låst fooField er "x"
        \\}
    , error.NotNynorsk);
}
