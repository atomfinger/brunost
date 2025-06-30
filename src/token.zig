const std = @import("std");

pub const Token = struct {
    kind: TokenType,
    literal: []const u8,

    pub fn init(kind: TokenType, literal: []const u8) Token {
        return Token{
            .kind = kind,
            .literal = literal,
        };
    }

    pub fn keyword(identifier: []const u8) ?TokenType {
        const map = std.ComptimeStringMap(TokenType, .{
            .{ "endreleg", .Endreleg },
            .{ "fast", .Fast },
            .{ "gjer", .Gjer },
            .{ "sant", .Sant },
            .{ "usant", .Usant },
            .{ "viss", .Viss },
            .{ "ellers", .Ellers },
            .{ "gjevTilbake", .GjevTilbake },
            .{ "er", .Er },
            .{ "erSameSom", .ErSameSom },
            .{ "medan", .Medan },
            .{ "forKvart", .ForKvart },
            .{ "prøv", .Prøv },
            .{ "fang", .Fang },
            .{ "kast", .Kast },
            .{ "modul", .Modul },
            .{ "bruk", .Bruk },
            .{ "i", .I }, // for "forKvart nummer i tall"
        });
        return map.get(identifier);
    }
};

// TokenType defines all possible token types in Brunost.
pub const TokenType = enum {
    Illegal, // Token/character not recognized
    Eof, // End of File

    // Identifiers + literals
    Ident, // add, foobar, x, y, ...
    Num, // 1343456
    String, // "hello world"

    // Operators
    Er, // =
    Plus, // +
    Minus, // -
    Bang, // ! (currently not in spec, but common)
    Asterisk, // *
    Slash, // /
    Dot, // . (for module access like matte.leggTil)

    Lt, // <
    Gt, // >

    ErSameSom, // ==
    IkkjeErSameSom, // != (derived from "er ikkje SameSom" or similar)

    // Delimiters
    Comma, // ,
    Semicolon, // ; (optional, for line endings if we want)

    Lparen, // (
    Rparen, // )
    Lbrace, // {
    Rbrace, // }
    Lbracket, // [
    Rbracket, // ]

    // Keywords
    Gjer, // Function definition
    Fast, // Immutable variable
    Endreleg, // Mutable variable
    Sant, // True
    Usant, // False
    Viss, // If
    Ellers, // Else
    GjevTilbake, // Return
    Medan, // While loop
    ForKvart, // For each loop
    I, // "in" keyword for ForKvart
    Prøv, // Try
    Fang, // Catch
    Kast, // Throw
    Modul, // Module definition
    Bruk, // Import module
};

fn isLetter(char: u8) bool {
    // Allow Norwegian characters in identifiers
    return std.ascii.isAlphabetic(char) or char == '_' or char > 127;
}

fn isDigit(char: u8) bool {
    return std.ascii.isDigit(char);
}

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0, // current position in input (points to current char)
    read_position: usize = 0, // current reading position in input (after current char)
    char: u8 = 0, // current char under examination

    pub fn init(input: []const u8) Lexer {
        var l = Lexer{ .input = input };
        l.readChar();
        return l;
    }

    fn readChar(l: *Lexer) void {
        if (l.read_position >= l.input.len) {
            l.char = 0; // ASCII code for "NUL" character, signifies EOF or not read yet
        } else {
            l.char = l.input[l.read_position];
        }
        l.position = l.read_position;
        l.read_position += 1;
    }

    fn peekChar(l: *Lexer) u8 {
        if (l.read_position >= l.input.len) {
            return 0;
        } else {
            return l.input[l.read_position];
        }
    }

    fn readIdentifier(l: *Lexer) []const u8 {
        const start_pos = l.position;
        while (isLetter(l.char)) {
            l.readChar();
        }
        return l.input[start_pos..l.position];
    }

    fn readNumber(l: *Lexer) []const u8 {
        const start_pos = l.position;
        while (isDigit(l.char)) {
            l.readChar();
        }
        return l.input[start_pos..l.position];
    }

    fn readString(l: *Lexer) []const u8 {
        const start_pos = l.position + 1; // Skip the opening "
        l.readChar(); // Consume opening "
        while (l.char != '"' and l.char != 0) {
            // TODO: Handle escape characters like \"
            l.readChar();
        }
        const end_pos = l.position;
        l.readChar(); // Consume closing "
        if (start_pos > end_pos) return ""; // Empty string if not closed properly or just ""
        return l.input[start_pos..end_pos];
    }

    fn skipWhitespace(l: *Lexer) void {
        while (l.char == ' ' or l.char == '\t' or l.char == '\n' or l.char == '\r') {
            l.readChar();
        }
    }

    pub fn nextToken(l: *Lexer) Token {
        var tok: Token = undefined;

        l.skipWhitespace();

        switch (l.char) {
            '=' => {
                // Check for "erSameSom" (==)
                if (l.peekChar() == '=') {
                    const ch = l.char;
                    l.readChar();
                    const literal = l.input[l.position - 1 .. l.position + 1];
                    tok = Token.init(TokenType.ErSameSom, literal);
                } else {
                    // This is "er" (=)
                    // The keyword "er" is handled by identifier logic
                    // So if we see '=', it's part of a multi-char token or illegal
                    // For now, let's assume "er" is always a keyword.
                    // This branch might need adjustment if '=' can be used alone.
                    // Based on readme, "er" is a keyword for assignment and conditional checks.
                    // "fast tall er 10", "viss (minVerdi er 1)"
                    // "erSameSom" is the equality operator.
                    // So a single '=' is not a token on its own.
                    tok = Token.init(TokenType.Illegal, l.input[l.position .. l.position + 1]);
                }
            },
            '+' => tok = Token.init(TokenType.Plus, l.input[l.position .. l.position + 1]),
            '-' => tok = Token.init(TokenType.Minus, l.input[l.position .. l.position + 1]),
            '!' => {
                 // Check for "!=" (ikkjeErSameSom)
                if (l.peekChar() == '=') {
                    const ch = l.char;
                    l.readChar();
                    const literal = l.input[l.position - 1 .. l.position + 1];
                    tok = Token.init(TokenType.IkkjeErSameSom, literal);
                } else {
                    tok = Token.init(TokenType.Bang, l.input[l.position .. l.position + 1]);
                }
            },
            '*' => tok = Token.init(TokenType.Asterisk, l.input[l.position .. l.position + 1]),
            '/' => tok = Token.init(TokenType.Slash, l.input[l.position .. l.position + 1]),
            '.' => tok = Token.init(TokenType.Dot, l.input[l.position .. l.position + 1]),
            '<' => tok = Token.init(TokenType.Lt, l.input[l.position .. l.position + 1]),
            '>' => tok = Token.init(TokenType.Gt, l.input[l.position .. l.position + 1]),
            ',' => tok = Token.init(TokenType.Comma, l.input[l.position .. l.position + 1]),
            ';' => tok = Token.init(TokenType.Semicolon, l.input[l.position .. l.position + 1]),
            '(' => tok = Token.init(TokenType.Lparen, l.input[l.position .. l.position + 1]),
            ')' => tok = Token.init(TokenType.Rparen, l.input[l.position .. l.position + 1]),
            '{' => tok = Token.init(TokenType.Lbrace, l.input[l.position .. l.position + 1]),
            '}' => tok = Token.init(TokenType.Rbrace, l.input[l.position .. l.position + 1]),
            '[' => tok = Token.init(TokenType.Lbracket, l.input[l.position .. l.position + 1]),
            ']' => tok = Token.init(TokenType.Rbracket, l.input[l.position .. l.position + 1]),
            '"' => {
                tok = Token.init(TokenType.String, l.readString());
                // readString advances l.char, so we don't call readChar() after this block
                return tok;
            },
            0 => {
                tok.literal = "";
                tok.kind = TokenType.Eof;
            },
            else => {
                if (isLetter(l.char)) {
                    tok.literal = l.readIdentifier();
                    tok.kind = Token.keyword(tok.literal) orelse TokenType.Ident;
                    // readIdentifier advances l.char, so we don't call readChar() after this block
                    return tok;
                } else if (isDigit(l.char)) {
                    tok.kind = TokenType.Num;
                    tok.literal = l.readNumber();
                    // readNumber advances l.char, so we don't call readChar() after this block
                    return tok;
                } else {
                    tok = Token.init(TokenType.Illegal, l.input[l.position .. l.position + 1]);
                }
            },
        }

        l.readChar(); // Advance to the next character
        return tok;
    }
};

// Test suite for the lexer
const testing = std.testing;

test "Next Token basic" {
    const input =
        \\fast fem er 5;
        \\fast ti er 10;
        \\
        \\gjer leggSaman(x, y) {
        \\  gjevTilbake x + y;
        \\};
        \\
        \\fast resultat er leggSaman(fem, ti);
        \\terminal.skriv(resultat);
        \\medan (resultat > 0) erSameSom sant gjer {
        \\  resultat er resultat - 1;
        \\}
        \\forKvart item i [1, "to", sant] {
        \\  terminal.skriv(item);
        \\}
        \\viss (1 < 2) er sant gjer {
        \\  terminal.skriv("mindre");
        \\} ellers viss (1 > 2) er usant gjer {
        \\  terminal.skriv("større");
        \\} ellers {
        \\  terminal.skriv("likt");
        \\}
        \\prøv { kast "feil"; } fang (e) { terminal.skriv(e); }
        \\modul testModul {}
        \\bruk testModul;
        \\1 != 2;
        \\fast b er usant;
    ;

    const expected_tokens = [_]Token{
        Token.init(TokenType.Fast, "fast"),
        Token.init(TokenType.Ident, "fem"),
        Token.init(TokenType.Er, "er"),
        Token.init(TokenType.Num, "5"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Fast, "fast"),
        Token.init(TokenType.Ident, "ti"),
        Token.init(TokenType.Er, "er"),
        Token.init(TokenType.Num, "10"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Gjer, "gjer"),
        Token.init(TokenType.Ident, "leggSaman"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Ident, "x"),
        Token.init(TokenType.Comma, ","),
        Token.init(TokenType.Ident, "y"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.GjevTilbake, "gjevTilbake"),
        Token.init(TokenType.Ident, "x"),
        Token.init(TokenType.Plus, "+"),
        Token.init(TokenType.Ident, "y"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Fast, "fast"),
        Token.init(TokenType.Ident, "resultat"),
        Token.init(TokenType.Er, "er"),
        Token.init(TokenType.Ident, "leggSaman"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Ident, "fem"),
        Token.init(TokenType.Comma, ","),
        Token.init(TokenType.Ident, "ti"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Ident, "terminal"),
        Token.init(TokenType.Dot, "."),
        Token.init(TokenType.Ident, "skriv"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Ident, "resultat"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Medan, "medan"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Ident, "resultat"),
        Token.init(TokenType.Gt, ">"),
        Token.init(TokenType.Num, "0"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.ErSameSom, "erSameSom"),
        Token.init(TokenType.Sant, "sant"),
        Token.init(TokenType.Gjer, "gjer"), // "gjer" from "medan ... gjer {}"
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Ident, "resultat"),
        Token.init(TokenType.Er, "er"),
        Token.init(TokenType.Ident, "resultat"),
        Token.init(TokenType.Minus, "-"),
        Token.init(TokenType.Num, "1"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.ForKvart, "forKvart"),
        Token.init(TokenType.Ident, "item"),
        Token.init(TokenType.I, "i"),
        Token.init(TokenType.Lbracket, "["),
        Token.init(TokenType.Num, "1"),
        Token.init(TokenType.Comma, ","),
        Token.init(TokenType.String, "to"),
        Token.init(TokenType.Comma, ","),
        Token.init(TokenType.Sant, "sant"),
        Token.init(TokenType.Rbracket, "]"),
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Ident, "terminal"),
        Token.init(TokenType.Dot, "."),
        Token.init(TokenType.Ident, "skriv"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Ident, "item"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Viss, "viss"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Num, "1"),
        Token.init(TokenType.Lt, "<"),
        Token.init(TokenType.Num, "2"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Er, "er"), // "er" from "viss ... er sant"
        Token.init(TokenType.Sant, "sant"),
        Token.init(TokenType.Gjer, "gjer"), // "gjer" from "viss ... gjer {}"
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Ident, "terminal"),
        Token.init(TokenType.Dot, "."),
        Token.init(TokenType.Ident, "skriv"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.String, "mindre"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Ellers, "ellers"),
        Token.init(TokenType.Viss, "viss"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Num, "1"),
        Token.init(TokenType.Gt, ">"),
        Token.init(TokenType.Num, "2"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Er, "er"), // "er" from "ellers viss ... er usant"
        Token.init(TokenType.Usant, "usant"),
        Token.init(TokenType.Gjer, "gjer"), // "gjer" from "ellers viss ... gjer {}"
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Ident, "terminal"),
        Token.init(TokenType.Dot, "."),
        Token.init(TokenType.Ident, "skriv"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.String, "større"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Ellers, "ellers"),
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Ident, "terminal"),
        Token.init(TokenType.Dot, "."),
        Token.init(TokenType.Ident, "skriv"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.String, "likt"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Prøv, "prøv"),
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Kast, "kast"),
        Token.init(TokenType.String, "feil"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Fang, "fang"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Ident, "e"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Ident, "terminal"),
        Token.init(TokenType.Dot, "."),
        Token.init(TokenType.Ident, "skriv"),
        Token.init(TokenType.Lparen, "("),
        Token.init(TokenType.Ident, "e"),
        Token.init(TokenType.Rparen, ")"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Modul, "modul"),
        Token.init(TokenType.Ident, "testModul"),
        Token.init(TokenType.Lbrace, "{"),
        Token.init(TokenType.Rbrace, "}"),
        Token.init(TokenType.Bruk, "bruk"),
        Token.init(TokenType.Ident, "testModul"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Num, "1"),
        Token.init(TokenType.IkkjeErSameSom, "!="),
        Token.init(TokenType.Num, "2"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Fast, "fast"),
        Token.init(TokenType.Ident, "b"),
        Token.init(TokenType.Er, "er"),
        Token.init(TokenType.Usant, "usant"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Eof, ""),
    };

    var l = Lexer.init(input);

    for (expected_tokens) |expected_tok| {
        const tok = l.nextToken();
        try testing.expectEqual(expected_tok.kind, tok.kind);
        try testing.expectEqualStrings(expected_tok.literal, tok.literal);
    }
}

test "String literal tokenization" {
    const input = "\"dette er ein streng\"";
    var l = Lexer.init(input);
    var tok = l.nextToken();
    try testing.expectEqual(TokenType.String, tok.kind);
    try testing.expectEqualStrings("dette er ein streng", tok.literal);

    tok = l.nextToken();
    try testing.expectEqual(TokenType.Eof, tok.kind);
}

test "Nynorsk characters in identifiers" {
    const input = "fast æøåVariabel er \"test\";";
    var l = Lexer.init(input);

    var expected_tokens = [_]Token{
        Token.init(TokenType.Fast, "fast"),
        Token.init(TokenType.Ident, "æøåVariabel"),
        Token.init(TokenType.Er, "er"),
        Token.init(TokenType.String, "test"),
        Token.init(TokenType.Semicolon, ";"),
        Token.init(TokenType.Eof, ""),
    };

    for (expected_tokens) |expected_tok| {
        const tok = l.nextToken();
        try testing.expectEqual(expected_tok.kind, tok.kind);
        try testing.expectEqualStrings(expected_tok.literal, tok.literal);
    }
}
