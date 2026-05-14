const std = @import("std");
const main = @import("../../src/main.zig");
const h = @import("../../src/test_helpers.zig");

test "hello world" {
    const out = try h.run_script(@embedFile("hello.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Hei, verd!\n", out);
}

test "variables" {
    const out = try h.run_script(@embedFile("variables.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n15\nHei\nsant\n", out);
}

test "arithmetic" {
    const out = try h.run_script(@embedFile("arithmetic.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("7\n7\n42\n5\n14\n", out);
}

test "functions" {
    const out = try h.run_script(@embedFile("functions.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\nHei, Ola!\n", out);
}

test "user-defined higher-order functions" {
    const out = try h.run_script(@embedFile("funksjon_hof.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3\n4\n8\n12\n", out);
}

test "lambda functions and trailing lambdas" {
    const out = try h.run_script(@embedFile("lambda_funksjon.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n12\n12\n3\n5\n7\n6\n", out);
}

test "control flow" {
    const out = try h.run_script(@embedFile("control_flow.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("ein\nstort\n", out);
}

test "boolean operators and simplified if/while syntax" {
    const out = try h.run_script(
        \\bruk terminal
        \\
        \\låst tal er -1
        \\låst nummer er 5
        \\
        \\viss (ikkje tal erSameEllerStørreEnn 0) gjer {
        \\  terminal.skriv("negativ")
        \\}
        \\
        \\viss (tal erMindreEnn 0 og nummer erStørreEnn 0) gjer {
        \\  terminal.skriv("og")
        \\}
        \\
        \\viss (tal erStørreEnn 0 eller nummer erStørreEnn 0) gjer {
        \\  terminal.skriv("eller")
        \\}
        \\
        \\open teljar er 0
        \\medan (teljar erMindreEnn 2) gjer {
        \\  terminal.skriv(teljar)
        \\  teljar er teljar + 1
        \\}
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("negativ\nog\neller\n0\n1\n", out);
}

test "legacy if syntax is rejected" {
    _ = try h.expect_parse_error(
        \\viss (sant) er sant gjer {
        \\}
    , error.ExpectedDo);
}

test "legacy while syntax is rejected" {
    _ = try h.expect_parse_error(
        \\medan (sant) erSameSom sant gjer {
        \\}
    , error.ExpectedDo);
}

test "loops" {
    const out = try h.run_script(@embedFile("loops.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n2\n3\n1\n2\n3\n", out);
}

test "stdlib matte" {
    const out = try h.run_script(@embedFile("stdlib_matte.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("5\n7\n3\n", out);
}

test "comparisons" {
    const out = try h.run_script(@embedFile("comparisons.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("sant\nsant\nsant\nsant\nsant\nsant\nusant\nusant\nusant\nusant\n", out);
}

test "fizzbuzz" {
    const out = try h.run_script(@embedFile("fizzbuzz.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz\n", out);
}

test "fibonacci" {
    const out = try h.run_script(@embedFile("fibonacci.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("0\n1\n1\n2\n3\n5\n8\n", out);
}

test "stdlib streng" {
    const out = try h.run_script(@embedFile("stdlib_streng.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("5\n42\n", out);
}

test "stdlib liste" {
    const out = try h.run_script(@embedFile("stdlib_liste.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3\n10\n30\n4\n20\n80\n2\n60\n140\n2\n40\nsant\nusant\n40\ninkje\nsant\nusant\n", out);
}

test "brukar modul" {
    const out = try h.run_script(@embedFile("brukar_modul.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n16\n", out);
}

test "modulus" {
    const out = try h.run_script(@embedFile("modulus.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n", out);
}

test "fil-import: bruk hjelp.rekning som rekn" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try main.run(
        std.testing.allocator,
        std.testing.io,
        @embedFile("fil_import_alias.brunost"),
        &aw.writer,
        "src/tests",
    );
    const out = try aw.toOwnedSlice();
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("15\n42\n", out);
}

test "fil-import: bruk hjelp.rekning" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try main.run(
        std.testing.allocator,
        std.testing.io,
        @embedFile("fil_import.brunost"),
        &aw.writer,
        "src/tests",
    );
    const out = try aw.toOwnedSlice();
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("7\n12\n", out);
}

test "feil: endra uforanderleg variabel" {
    try h.expect_error(@embedFile("feil_uforanderleg.brunost"), error.ImmutableAssignment);
}

test "feil: udefinert variabel" {
    try h.expect_error(@embedFile("feil_udefinert.brunost"), error.UndefinedVariable);
}

test "feil: divisjon med null" {
    try h.expect_error(@embedFile("feil_del_paa_null.brunost"), error.DivisionByZero);
}

test "feil: typefeil aritmetikk" {
    try h.expect_error(@embedFile("feil_typefeil.brunost"), error.TypeError);
}

test "feil: ugyldig syntaks" {
    _ = try h.expect_parse_error(@embedFile("feil_parse.brunost"), error.ExpectedIdentifier);
}

test "feil: parse diagnostic includes offending identifier" {
    const context = try h.expect_parse_error("låst foo er 1", error.NotNynorsk);
    const diagnostic = context.parse_diagnostic.?;
    try std.testing.expectEqualStrings("foo", diagnostic.literal);
    try std.testing.expectEqual(@as(usize, 1), diagnostic.line);
    try std.testing.expectEqual(@as(usize, 7), diagnostic.column);
}

test "identifiers with æøå from dictionary are accepted" {
    const out = try h.run_script(
        \\låst ære er 1
        \\låst høgd er 30
        \\låst år er 2026
        \\
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "plural identifiers are accepted when the lemma exists in the dictionary" {
    const out = try h.run_script(
        \\låst iterasjonar er 3
        \\låst nynorskIterasjonar er iterasjonar
        \\låst opne_iterasjonar er nynorskIterasjonar
        \\
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "acronyms (2-5 uppercase letters) are accepted as identifiers" {
    const out = try h.run_script(
        \\låst BMI er 22
        \\låst CPU er 4
        \\låst API er 1
        \\
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "acronyms embedded in camelCase identifiers are accepted" {
    const out = try h.run_script(
        \\låst reknarBMI er 1
        \\låst BMIreknar er reknarBMI
        \\
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "feil: akronym med meir enn 5 teikn er ikkje gyldig" {
    _ = try h.expect_parse_error("låst NASDAQ er 1", error.NotNynorsk);
}

test "camelCase words starting with one uppercase letter still work" {
    const out = try h.run_script(
        \\låst raudBil er 1
        \\
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "feil: ukjend modul" {
    try h.expect_error("bruk ukjendmodul", error.UnknownModule);
}

test "feil: modulnamn-konflikt" {
    try h.expect_error("bruk matte\nbruk matte", error.ModuleNameCollision);
}

test "terminal argument les frå script-argument" {
    const out = try h.run_script_with_args(
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
    try h.expect_error(
        \\bruk terminal
        \\terminal.skriv(terminal.argument(0))
    , error.IndexOutOfBounds);
}
