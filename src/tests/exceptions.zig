const std = @import("std");
const h = @import("../../src/test_helpers.zig");

test "prøv/fang fangar kast" {
    const out = try h.run_script(
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
    const out = try h.run_script(
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
    const out = try h.run_script(
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
    const out = try h.run_script(
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
    try h.expect_error(
        \\bruk kart
        \\låst minKart er {}
        \\låst verdi er kart.hent(minKart, "nøkkel")
    , error.KeyNotFound);
}

test "endelig køyrer utan feil" {
    const out = try h.run_script(
        \\bruk terminal
        \\prøv {
        \\  terminal.skriv("prøv")
        \\} fang (feil) {
        \\  terminal.skriv("aldri nådd")
        \\} endelig {
        \\  terminal.skriv("endelig")
        \\}
        \\terminal.skriv("etter")
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("prøv\nendelig\netter\n", out);
}

test "endelig køyrer etter fang" {
    const out = try h.run_script(
        \\bruk terminal
        \\prøv {
        \\  kast "feil"
        \\} fang (e) {
        \\  terminal.skriv("fanga: " + e)
        \\} endelig {
        \\  terminal.skriv("endelig")
        \\}
        \\terminal.skriv("etter")
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("fanga: feil\nendelig\netter\n", out);
}

test "prøv/endelig utan catch, ingen feil" {
    const out = try h.run_script(
        \\bruk terminal
        \\prøv {
        \\  terminal.skriv("prøv")
        \\} endelig {
        \\  terminal.skriv("endelig")
        \\}
        \\terminal.skriv("etter")
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("prøv\nendelig\netter\n", out);
}

test "prøv/endelig forplantar eval-feil" {
    try h.expect_error(
        \\bruk kart
        \\låst minKart er {}
        \\prøv {
        \\  låst verdi er kart.hent(minKart, "nøkkel")
        \\} endelig {
        \\}
    , error.KeyNotFound);
}

test "gjevTilbake gjennom endelig" {
    const out = try h.run_script(
        \\bruk terminal
        \\gjer sjekk() {
        \\  prøv {
        \\    gjevTilbake 42
        \\  } fang (e) {
        \\    terminal.skriv("aldri nådd")
        \\  } endelig {
        \\    terminal.skriv("endelig")
        \\  }
        \\  gjevTilbake 0
        \\}
        \\terminal.skriv(sjekk())
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("endelig\n42\n", out);
}

test "endelig overstyrer med kast" {
    const out = try h.run_script(
        \\bruk terminal
        \\prøv {
        \\  prøv {
        \\    kast "original"
        \\  } fang (e) {
        \\    terminal.skriv("fanga: " + e)
        \\  } endelig {
        \\    kast "ny feil"
        \\  }
        \\} fang (e) {
        \\  terminal.skriv("ytre fang: " + e)
        \\}
    );
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("fanga: original\nytre fang: ny feil\n", out);
}
