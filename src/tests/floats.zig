const std = @import("std");
const h = @import("../../src/test_helpers.zig");

test "desimaltal" {
    const out = try h.run_script(@embedFile("desimaltal.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3.14\n4\n3.25\n7\n3.5\n-1.5\n", out);
}

test "desimaltal blanding med heiltal" {
    const out = try h.run_script(@embedFile("desimaltal_blanding.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1.5\n3.5\n4.5\n4\nsant\nsant\n", out);
}

test "desimaltal i uttrykk" {
    const out = try h.run_script(
        \\bruk terminal
        \\terminal.skriv(3.14)
        \\terminal.skriv(1.0 + 0.5)
        \\terminal.skriv(10.0 / 4.0)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("3.14\n1.5\n2.5\n", out);
}

test "desimaltal streng-samankopling" {
    const out = try h.run_script(
        \\bruk terminal
        \\terminal.skriv("pi er " + 3.14)
        \\terminal.skriv("svar: " + 2.5)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("pi er 3.14\nsvar: 2.5\n", out);
}

test "streng-samankopling med heiltal og boolsk" {
    const out = try h.run_script(
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
    const out = try h.run_script(
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
    const out = try h.run_script(
        \\bruk terminal
        \\terminal.skriv(3.0 erSameSom 3)
        \\terminal.skriv(3 erSameSom 3.0)
        \\terminal.skriv(3.5 erSameSom 3)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("sant\nsant\nusant\n", out);
}

test "desimaltal i kontrollflyt" {
    const out = try h.run_script(
        \\bruk terminal
        \\viss (0.0) gjer {
        \\  terminal.skriv("sant")
        \\} elles {
        \\  terminal.skriv("usant")
        \\}
        \\viss (0.1) gjer {
        \\  terminal.skriv("sant")
        \\} elles {
        \\  terminal.skriv("usant")
        \\}
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("usant\nsant\n", out);
}

test "desimaltal operatorprioritet" {
    const out = try h.run_script(
        \\bruk terminal
        \\terminal.skriv(2.0 + 3.0 * 4.0)
        \\terminal.skriv(10.0 - 2.0 * 3.0)
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("14\n4\n", out);
}

test "feil: desimaltal divisjon med null" {
    try h.expect_error(
        \\bruk terminal
        \\terminal.skriv(1.5 / 0.0)
    , error.DivisionByZero);
}

test "desimaltal stdlib matte" {
    const out = try h.run_script(
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
    const out = try h.run_script(@embedFile("kart_test.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1\n2\n2\nsant\nusant\n1\n99\n10\n20\n10\n20\n1\n20\n", out);
}
