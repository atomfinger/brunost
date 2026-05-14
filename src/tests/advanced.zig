const std = @import("std");
const h = @import("../../src/test_helpers.zig");

test "strengescapes: \\n \\t \\\\ og \\\"" {
    const out = try h.run_script(@embedFile("strengescapes.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("linje1\nlinje2\ntab\there\nskråstrek\\\nsitat\"tekst\"\n", out);
}

test "blokkkommentar /* ... */" {
    const out = try h.run_script(@embedFile("blokkkommentar.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("før\netter\n", out);
}

test "bryt og fortset i løkker" {
    const out = try h.run_script(@embedFile("bryt_haldfram.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("0\n1\n2\n1\n2\n4\n5\n1\n2\n3\n", out);
}

test "subscript: liste[idx] og kart[\"nøkkel\"]" {
    const out = try h.run_script(@embedFile("subscript.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("10\n30\nOla\n42\n", out);
}

test "samansett tilordning +=, -=, *=, /=" {
    const out = try h.run_script(@embedFile("samansett_tilordning.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("15\n12\n24\n6\n", out);
}

test "streng: del, trim, tilStoreBokstavar, tilSmåBokstavar, byt, startarMed, slutarMed, format" {
    const out = try h.run_script(@embedFile("streng_utvida.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("[a, b, c]\nhei\nHEI\nhei\nhei Noreg\nsant\nsant\nHei, Ola!\n", out);
}

test "test: krev (assert)" {
    const out = try h.run_script(@embedFile("debug_krev.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("ok\nfeil!\n", out);
}

test "matte.potens" {
    const out = try h.run_script(@embedFile("matte_potens.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1024\n27\n2\n", out);
}

test "liste.sorter med og utan komparator" {
    const out = try h.run_script(@embedFile("liste_sorter.brunost"));
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("[1, 1, 2, 3, 4, 5, 6, 9]\n[appelsin, banan, eple]\n[9, 6, 5, 4, 3, 2, 1, 1]\n", out);
}
