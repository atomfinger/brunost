const std = @import("std");

pub const Token = struct {
    type: token_types,
    literal: []const u8,

    pub fn init(kind: token_types, literal: []const u8) Token {
        return Token{
            .kind = kind,
            .literal = literal,
        };
    }

    pub fn keyword(identifier: []const u8) ?token_types {
        const map = std.ComptimeStringMap(token_types, .{
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
            .{ "medan", .for_loop },
            .{ "forKvart", .foreach_loop },
        });
        return map.get(identifier);
    }
};

//insp: https://github.com/heldrida/interpreter-in-zig/blob/main/src/token.zig
// https://github.com/aryanrsuri/zigterpreter/blob/master/src/lexer.zig

pub const token_types = enum {
    nul,
    eof,
    assign,
    plus,
    minus,
    bang,
    asterisk,
    comma,
    semicolon,
    lparen,
    rparen,
    lbrace,
    rbrace,
    ltag,
    rtag,
    equal,
    function,
    let_mutable,
    let_immutable,
    return_op,
    if_op,
    true_val,
    false_val,
    else_op,
    for_loop,
    foreach_loop,
};

fn is_letter(char: u8) bool {
    return std.ascii.isAlphabetic(char) or char == '_';
}

fn is_integer(char: u8) bool {
    return std.ascii.isDigit(char);
}

pub const Lexer = struct {
    input: []const u8,
    curr_position: u8 = 0,
    next_position: u8 = 0,
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

    pub fn read_identifier(self: *@This()) []const u8 {
        const position = self.curr_position;
        while (is_letter(self.curr_char)) {
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

    pub fn next_token(self: *@This()) Token {
        self.skip_whitespace();
        const sch: []const u8 = self.curr_string();
        var token = Token.init(.illegal, sch);
        switch (self.curr_char) {
            '(' => token.type = .lparen,
            ')' => token.type = .rparen,
            ',' => token.type = .comma,
            '+' => token.type = .plus,
            '-' => token.type = .minus,
            '*' => token.type = .asterisk,
            '/' => token.type = .fslash,
            '{' => token.type = .lbrace,
            '}' => token.type = .rbrace,
            '<' => token.type = .ltag,
            '>' => token.type = .rtag,
            'a'...'z', 'A'...'Z', '_' => {
                token.literal = self.read_identifier();
                if (Token.keyword(token.literal)) |tok| {
                    token.kind = tok;
                    return token;
                }
                token.kind = .identifier;
                return token;
            },
            '0'...'9' => {
                token.literal = self.read_integer();
                token.kind = .integer;
                return token;
            },
            0 => token.kind = .eof,
            else => token.kind = .illegal,
        }
        self.read_char();
        return token;
    }
};
