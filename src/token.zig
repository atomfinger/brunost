const std = @import("std");

pub const token_types = enum {
    nul,
    eof,
    illegal,
    // literals
    identifier,
    integer,
    string,
    // operators
    assign, // er (context-dependent)
    plus,
    minus,
    bang,
    asterisk,
    fslash,
    dot,
    comma,
    semicolon,
    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,
    rbracket,
    ltag,
    rtag,
    gt,
    lt,
    gte,
    lte,
    // keywords
    equal, // erSameSom
    function, // gjer
    let_mutable, // endreleg
    let_immutable, // fast
    return_op, // gjevTilbake
    if_op, // viss
    else_op, // ellers
    true_val, // sant
    false_val, // usant
    while_loop, // medan
    foreach_loop, // forKvart
    in_op, // i
    try_op, // prøv
    catch_op, // fang
    throw_op, // kast
    import_op, // bruk
    module_op, // modul
    as_op, // som
};

pub const Token = struct {
    type: token_types,
    literal: []const u8,

    pub fn init(kind: token_types, literal: []const u8) Token {
        return Token{
            .type = kind,
            .literal = literal,
        };
    }

    pub fn keyword(identifier: []const u8) ?token_types {
        const map = std.StaticStringMap(token_types).initComptime(.{
            .{ "endreleg", .let_mutable },
            .{ "fast", .let_immutable },
            .{ "gjer", .function },
            .{ "sant", .true_val },
            .{ "usant", .false_val },
            .{ "viss", .if_op },
            .{ "ellers", .else_op },
            .{ "gjevTilbake", .return_op },
            .{ "er", .assign },
            .{ "erSameSom", .equal },
            .{ "medan", .while_loop },
            .{ "forKvart", .foreach_loop },
            .{ "i", .in_op },
            .{ "pr\xc3\xb8v", .try_op }, // prøv in UTF-8
            .{ "fang", .catch_op },
            .{ "kast", .throw_op },
            .{ "bruk", .import_op },
            .{ "modul", .module_op },
            .{ "som", .as_op },
            .{ "erSt\xc3\xb8rreEnn", .gt }, // erStørreEnn
            .{ "erMindreEnn", .lt },
            .{ "erSameEllerSt\xc3\xb8rreEnn", .gte }, // erSameEllerStørreEnn
            .{ "erSameEllerMindreEnn", .lte },
        });
        return map.get(identifier);
    }
};

fn is_identifier_byte(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_' or c == '?' or c >= 0x80;
}

fn is_integer(char: u8) bool {
    return std.ascii.isDigit(char);
}

pub const Lexer = struct {
    input: []const u8,
    curr_position: usize = 0,
    next_position: usize = 0,
    curr_char: u8 = 0,

    pub fn init(input: []const u8) @This() {
        var lexer = @This(){
            .input = input,
        };
        lexer.read_char();
        return lexer;
    }

    pub fn read_char(self: *@This()) void {
        if (self.next_position >= self.input.len) {
            self.curr_char = 0;
        } else {
            self.curr_char = self.input[self.next_position];
        }
        self.curr_position = self.next_position;
        self.next_position += 1;
    }

    fn peek_char(self: *@This()) u8 {
        if (self.next_position >= self.input.len) return 0;
        return self.input[self.next_position];
    }

    fn skip_whitespace(self: *@This()) void {
        while (true) {
            // Skip whitespace characters
            while (self.curr_char == ' ' or self.curr_char == '\t' or
                self.curr_char == '\n' or self.curr_char == '\r')
            {
                self.read_char();
            }
            // Skip line comments (//)
            if (self.curr_char == '/' and self.peek_char() == '/') {
                while (self.curr_char != '\n' and self.curr_char != 0) {
                    self.read_char();
                }
            } else {
                break;
            }
        }
    }

    fn curr_string(self: *@This()) []const u8 {
        if (self.curr_position >= self.input.len) return "";
        return self.input[self.curr_position .. self.curr_position + 1];
    }

    pub fn read_identifier(self: *@This()) []const u8 {
        const position = self.curr_position;
        while (is_identifier_byte(self.curr_char)) {
            self.read_char();
        }
        return self.input[position..self.curr_position];
    }

    pub fn read_integer(self: *@This()) []const u8 {
        const position = self.curr_position;
        while (is_integer(self.curr_char)) {
            self.read_char();
        }
        return self.input[position..self.curr_position];
    }

    fn read_string(self: *@This()) []const u8 {
        self.read_char(); // consume opening "
        const start = self.curr_position;
        while (self.curr_char != '"' and self.curr_char != 0) {
            self.read_char();
        }
        const result = self.input[start..self.curr_position];
        self.read_char(); // consume closing "
        return result;
    }

    pub fn next_token(self: *@This()) Token {
        self.skip_whitespace();
        const sch: []const u8 = self.curr_string();
        var tok = Token.init(.illegal, sch);
        switch (self.curr_char) {
            '(' => tok.type = .lparen,
            ')' => tok.type = .rparen,
            ',' => tok.type = .comma,
            ';' => tok.type = .semicolon,
            '+' => tok.type = .plus,
            '-' => tok.type = .minus,
            '*' => tok.type = .asterisk,
            '/' => tok.type = .fslash,
            '{' => tok.type = .lbrace,
            '}' => tok.type = .rbrace,
            '[' => tok.type = .lbracket,
            ']' => tok.type = .rbracket,
            '<' => tok.type = .ltag,
            '>' => tok.type = .rtag,
            '!' => tok.type = .bang,
            '.' => tok.type = .dot,
            '"' => {
                tok.literal = self.read_string();
                tok.type = .string;
                return tok;
            },
            0 => {
                tok.type = .eof;
                tok.literal = "";
            },
            else => {
                if (is_identifier_byte(self.curr_char)) {
                    tok.literal = self.read_identifier();
                    if (Token.keyword(tok.literal)) |kw| {
                        tok.type = kw;
                    } else {
                        tok.type = .identifier;
                    }
                    return tok;
                } else if (is_integer(self.curr_char)) {
                    tok.literal = self.read_integer();
                    tok.type = .integer;
                    return tok;
                } else {
                    tok.type = .illegal;
                }
            },
        }
        self.read_char();
        return tok;
    }
};
