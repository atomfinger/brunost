const std = @import("std");
const main = @import("main.zig");
const parser = @import("parser.zig");

fn run_script(source: []const u8) ![]u8 {
    return run_script_with_args(source, &.{});
}

fn run_script_with_args(source: []const u8, script_args: []const []const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try main.run_with_args(std.testing.allocator, source, &aw.writer, "", script_args);
    return aw.toOwnedSlice();
}

fn expect_error(source: []const u8, expected: anyerror) !void {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try std.testing.expectError(
        expected,
        main.run(std.testing.allocator, source, &aw.writer, ""),
    );
}

fn expect_parse_error(source: []const u8, expected: parser.ParseError) !main.RunContext {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();

    var context: main.RunContext = .{};
    try std.testing.expectError(
        error.ParseFailed,
        main.run_with_context(
            std.testing.allocator,
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

test "boolean operators and simplified if/while syntax" {
    const out = try run_script(
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
    _ = try expect_parse_error(
        \\viss (sant) er sant gjer {
        \\}
    , error.ExpectedDo);
}

test "legacy while syntax is rejected" {
    _ = try expect_parse_error(
        \\medan (sant) erSameSom sant gjer {
        \\}
    , error.ExpectedDo);
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
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try main.run(
        std.testing.allocator,
        @embedFile("tests/fil_import_alias.brunost"),
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
        @embedFile("tests/fil_import.brunost"),
        &aw.writer,
        "src/tests",
    );
    const out = try aw.toOwnedSlice();
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
    const context = try expect_parse_error("låst foo er 1", error.NotNynorsk);
    const diagnostic = context.parse_diagnostic.?;
    try std.testing.expectEqualStrings("foo", diagnostic.literal);
    try std.testing.expectEqual(@as(usize, 1), diagnostic.line);
    try std.testing.expectEqual(@as(usize, 7), diagnostic.column);
}

test "identifiers with æøå from dictionary are accepted" {
    const out = try run_script(
        \\låst ære er 1
        \\låst høgd er 30
        \\låst år er 2026
        \\
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "plural identifiers are accepted when the lemma exists in the dictionary" {
    const out = try run_script(
        \\låst iterasjonar er 3
        \\låst nynorskIterasjonar er iterasjonar
        \\låst opne_iterasjonar er nynorskIterasjonar
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

test "desimaltal" {
    const out = try run_script(@embedFile("tests/desimaltal.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3.14\n4\n3.25\n7\n3.5\n-1.5\n", out);
}

test "desimaltal blanding med heiltal" {
    const out = try run_script(@embedFile("tests/desimaltal_blanding.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1.5\n3.5\n4.5\n4\nsant\nsant\n", out);
}

test "desimaltal i uttrykk" {
    const out = try run_script(
        \\bruk terminal
        \\terminal.skriv(3.14)
        \\terminal.skriv(1.0 + 0.5)
        \\terminal.skriv(10.0 / 4.0)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3.14\n1.5\n2.5\n", out);
}

test "desimaltal streng-samankopling" {
    const out = try run_script(
        \\bruk terminal
        \\terminal.skriv("pi er " + 3.14)
        \\terminal.skriv("svar: " + 2.5)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("pi er 3.14\nsvar: 2.5\n", out);
}

test "streng-samankopling med heiltal og boolsk" {
    const out = try run_script(
        \\bruk terminal
        \\terminal.skriv(42 + " er svaret")
        \\terminal.skriv("primtal: " + sant)
        \\terminal.skriv("primtal: " + usant)
        \\terminal.skriv(7 + " er eit primtal: " + sant)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("42 er svaret\nprimtal: sant\nprimtal: usant\n7 er eit primtal: sant\n", out);
}

test "desimaltal samanlikningar" {
    const out = try run_script(
        \\bruk terminal
        \\terminal.skriv(1.5 erMindreEnn 2.5)
        \\terminal.skriv(2.5 erStørreEnn 1.5)
        \\terminal.skriv(3.0 erSameEllerStørreEnn 3.0)
        \\terminal.skriv(1.0 erSameEllerMindreEnn 1.0)
        \\terminal.skriv(1.5 erSameSom 1.5)
        \\terminal.skriv(1.5 erSameSom 2.5)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("sant\nsant\nsant\nsant\nsant\nusant\n", out);
}

test "desimaltal likskap mellom heiltal og desimaltal" {
    const out = try run_script(
        \\bruk terminal
        \\terminal.skriv(3.0 erSameSom 3)
        \\terminal.skriv(3 erSameSom 3.0)
        \\terminal.skriv(3.5 erSameSom 3)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("sant\nsant\nusant\n", out);
}

test "desimaltal i kontrollflyt" {
    const out = try run_script(
        \\bruk terminal
        \\viss (0.0) gjer {
        \\  terminal.skriv("sant")
        \\} ellers {
        \\  terminal.skriv("usant")
        \\}
        \\viss (0.1) gjer {
        \\  terminal.skriv("sant")
        \\} ellers {
        \\  terminal.skriv("usant")
        \\}
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("usant\nsant\n", out);
}

test "desimaltal operatorprioritet" {
    const out = try run_script(
        \\bruk terminal
        \\terminal.skriv(2.0 + 3.0 * 4.0)
        \\terminal.skriv(10.0 - 2.0 * 3.0)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("14\n4\n", out);
}

test "feil: desimaltal divisjon med null" {
    try expect_error(
        \\bruk terminal
        \\terminal.skriv(1.5 / 0.0)
    , error.DivisionByZero);
}

test "desimaltal stdlib matte" {
    const out = try run_script(
        \\bruk matte
        \\bruk terminal
        \\terminal.skriv(matte.abs(-3.5))
        \\terminal.skriv(matte.maks(1.5, 2.5))
        \\terminal.skriv(matte.min(1.5, 2.5))
        \\terminal.skriv(matte.maks(1, 2.5))
        \\terminal.skriv(matte.min(3.5, 2))
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3.5\n2.5\n1.5\n2.5\n2\n", out);
}

test "kart (hashmap)" {
    const out = try run_script(@embedFile("tests/kart_test.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n2\n2\nsant\nusant\n1\n99\n10\n20\n", out);
}

test "prøv/fang fangar kast" {
    const out = try run_script(
        \\bruk terminal
        \\prøv {
        \\  kast "noko gjekk gale"
        \\  terminal.skriv("aldri nådd")
        \\} fang (feil) {
        \\  terminal.skriv("fanga: " + feil)
        \\}
        \\terminal.skriv("etter")
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("fanga: noko gjekk gale\netter\n", out);
}

test "prøv/fang fangar runtime eval-feil" {
    const out = try run_script(
        \\bruk kart
        \\bruk terminal
        \\låst minKart er {}
        \\prøv {
        \\  låst verdi er kart.hent(minKart, "nøkkel")
        \\  terminal.skriv("aldri nådd")
        \\} fang (feil) {
        \\  terminal.skriv("fanga: " + feil)
        \\}
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("fanga: KeyNotFound\n", out);
}

test "prøv/fang fangar IndexOutOfBounds" {
    const out = try run_script(
        \\bruk liste
        \\bruk terminal
        \\låst minListe er [1, 2, 3]
        \\prøv {
        \\  låst verdi er liste.hent(minListe, 99)
        \\  terminal.skriv("aldri nådd")
        \\} fang (feil) {
        \\  terminal.skriv("fanga: " + feil)
        \\}
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("fanga: IndexOutOfBounds\n", out);
}

test "prøv/fang: ingen feil fortset normalt" {
    const out = try run_script(
        \\bruk terminal
        \\prøv {
        \\  terminal.skriv("ok")
        \\} fang (feil) {
        \\  terminal.skriv("aldri nådd")
        \\}
        \\terminal.skriv("etter")
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("ok\netter\n", out);
}

test "prøv/fang: feil utanfor fangar ikkje" {
    try expect_error(
        \\bruk kart
        \\låst minKart er {}
        \\låst verdi er kart.hent(minKart, "nøkkel")
    , error.KeyNotFound);
}

test "type: les felt" {
    const out = try run_script(@embedFile("tests/type_grunnleggjande.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\n5\n", out);
}

test "type: oppdater open felt" {
    const out = try run_script(@embedFile("tests/type_oppdatering.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n", out);
}

test "type: standardverdiar" {
    const out = try run_script(@embedFile("tests/type_standard.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Honda\n0\n", out);
}

test "type: i liste" {
    const out = try run_script(@embedFile("tests/type_liste.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\nHonda\n", out);
}

test "type: som parameter" {
    const out = try run_script(@embedFile("tests/type_funksjon.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\n5\n", out);
}

test "type: skriv som json" {
    const out = try run_script(@embedFile("tests/type_json.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("{\"namn\": \"Toyota\", \"alder\": 5}\n", out);
}

test "type: viss med felt-samanlikning" {
    const out = try run_script(@embedFile("tests/type_viss.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Bilen er 5 år gamal\nDet er ein Toyota\nBilen er meir enn 3 år\n", out);
}

test "type: forKvart over listfelt" {
    const out = try run_script(@embedFile("tests/type_forkvart_felt.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("Toyota\nHonda\nVolvo\n1\n2\n3\n", out);
}

test "feil: endra låst felt" {
    try expect_error(
        \\type Bil {
        \\    låst namn er "ukjend"
        \\    open alder er 0
        \\}
        \\open minBil er Bil { namn er "Toyota", alder er 5 }
        \\minBil.namn er "Honda"
    , error.ImmutableField);
}

test "feil: påkravd felt manglar" {
    try expect_error(
        \\type Bil {
        \\    låst namn er "ukjend"
        \\    open alder
        \\}
        \\låst minBil er Bil { namn er "Toyota" }
    , error.UndefinedField);
}

test "feil: ukjent type" {
    try expect_error(
        \\låst minBil er ukjendType { namn er "Toyota" }
    , error.UndefinedVariable);
}

test "feil: type-namn er ikkje nynorsk" {
    _ = try expect_parse_error(
        \\type fooBar {
        \\    låst namn er "x"
        \\}
    , error.NotNynorsk);
}

test "feil: feltnamn er ikkje nynorsk" {
    _ = try expect_parse_error(
        \\type Bil {
        \\    låst fooField er "x"
        \\}
    , error.NotNynorsk);
}
