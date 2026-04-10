const std = @import("std");
const token = @import("token.zig");
const ast = @import("ast.zig");

pub const ParseError = error{
    UnexpectedToken,
    ExpectedIdentifier,
    ExpectedAssign,
    ExpectedBoolVal,
    ExpectedDo,
    ExpectedIn,
    ExpectedOpenParen,
    ExpectedCloseParen,
    ExpectedOpenBrace,
    ExpectedCloseBrace,
    ExpectedCloseBracket,
    InvalidInteger,
    OutOfMemory,
};

pub const Parser = struct {
    lexer: token.Lexer,
    curr: token.Token,
    peek: token.Token,
    arena: std.mem.Allocator,

    pub fn init(lexer: token.Lexer, arena: std.mem.Allocator) Parser {
        var p = Parser{
            .lexer = lexer,
            .curr = token.Token.init(.nul, ""),
            .peek = token.Token.init(.nul, ""),
            .arena = arena,
        };
        p.advance();
        p.advance();
        return p;
    }

    fn advance(self: *Parser) void {
        self.curr = self.peek;
        self.peek = self.lexer.next_token();
    }

    fn expect(self: *Parser, kind: token.token_types) ParseError!void {
        if (self.curr.type != kind) return ParseError.UnexpectedToken;
        self.advance();
    }

    fn alloc_node(self: *Parser, node: ast.Node) ParseError!*ast.Node {
        const n = try self.arena.create(ast.Node);
        n.* = node;
        return n;
    }

    pub fn parse_program(self: *Parser) ParseError!*ast.Node {
        var stmts: std.ArrayList(*ast.Node) = .{};
        while (self.curr.type != .eof) {
            const stmt = try self.parse_statement();
            try stmts.append(self.arena, stmt);
        }
        return self.alloc_node(.{ .program = .{ .statements = try stmts.toOwnedSlice(self.arena) } });
    }

    fn parse_statement(self: *Parser) ParseError!*ast.Node {
        return switch (self.curr.type) {
            .let_immutable => self.parse_var_decl(false),
            .let_mutable => self.parse_var_decl(true),
            .return_op => self.parse_return(),
            .if_op => self.parse_if(),
            .while_loop => self.parse_while(),
            .foreach_loop => self.parse_foreach(),
            .try_op => self.parse_try(),
            .throw_op => self.parse_throw(),
            .function => self.parse_fn_decl(),
            else => self.parse_assign_or_expr(),
        };
    }

    fn parse_var_decl(self: *Parser, mutable: bool) ParseError!*ast.Node {
        self.advance(); // consume fast / endreleg
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const name = self.curr.literal;
        self.advance();
        try self.expect(.assign); // er
        const value = try self.parse_expr(0);
        return self.alloc_node(.{ .var_decl = .{ .mutable = mutable, .name = name, .value = value } });
    }

    fn parse_return(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume gjevTilbake
        const value = try self.parse_expr(0);
        return self.alloc_node(.{ .return_stmt = .{ .value = value } });
    }

    fn parse_throw(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume kast
        const value = try self.parse_expr(0);
        return self.alloc_node(.{ .throw_stmt = .{ .value = value } });
    }

    fn parse_fn_decl(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume gjer
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const name = self.curr.literal;
        self.advance();
        try self.expect(.lparen);
        var params: std.ArrayList([]const u8) = .{};
        while (self.curr.type != .rparen and self.curr.type != .eof) {
            if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
            try params.append(self.arena, self.curr.literal);
            self.advance();
            if (self.curr.type == .comma) self.advance();
        }
        try self.expect(.rparen);
        const body = try self.parse_block();
        return self.alloc_node(.{ .fn_decl = .{
            .name = name,
            .params = try params.toOwnedSlice(self.arena),
            .body = body,
        } });
    }

    fn parse_if(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume viss
        if (self.curr.type != .lparen) return ParseError.ExpectedOpenParen;
        self.advance();
        const condition = try self.parse_expr(0);
        if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
        self.advance();
        // er sant / er usant
        if (self.curr.type != .assign) return ParseError.ExpectedAssign;
        self.advance();
        const expected = switch (self.curr.type) {
            .true_val => true,
            .false_val => false,
            else => return ParseError.ExpectedBoolVal,
        };
        self.advance();
        // gjer (the "do" keyword)
        if (self.curr.type != .function) return ParseError.ExpectedDo;
        self.advance();
        const consequence = try self.parse_block();
        var alternative: ?*ast.Node = null;
        if (self.curr.type == .else_op) {
            self.advance(); // consume ellers
            if (self.curr.type == .if_op) {
                alternative = try self.parse_if();
            } else {
                alternative = try self.parse_block();
            }
        }
        return self.alloc_node(.{ .if_stmt = .{
            .condition = condition,
            .expected = expected,
            .consequence = consequence,
            .alternative = alternative,
        } });
    }

    fn parse_while(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume medan
        if (self.curr.type != .lparen) return ParseError.ExpectedOpenParen;
        self.advance();
        const condition = try self.parse_expr(0);
        if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
        self.advance();
        // erSameSom sant / erSameSom usant
        if (self.curr.type != .equal) return ParseError.ExpectedAssign;
        self.advance();
        const expected = switch (self.curr.type) {
            .true_val => true,
            .false_val => false,
            else => return ParseError.ExpectedBoolVal,
        };
        self.advance();
        if (self.curr.type != .function) return ParseError.ExpectedDo;
        self.advance();
        const body = try self.parse_block();
        return self.alloc_node(.{ .while_stmt = .{
            .condition = condition,
            .expected = expected,
            .body = body,
        } });
    }

    fn parse_foreach(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume forKvart
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const iter_name = self.curr.literal;
        self.advance();
        if (self.curr.type != .in_op) return ParseError.ExpectedIn;
        self.advance();
        const iterable = try self.parse_expr(0);
        const body = try self.parse_block();
        return self.alloc_node(.{ .foreach_stmt = .{
            .iterator_name = iter_name,
            .iterable = iterable,
            .body = body,
        } });
    }

    fn parse_try(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume prøv
        const body = try self.parse_block();
        if (self.curr.type != .catch_op) return ParseError.UnexpectedToken;
        self.advance();
        if (self.curr.type != .lparen) return ParseError.ExpectedOpenParen;
        self.advance();
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const error_name = self.curr.literal;
        self.advance();
        if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
        self.advance();
        const catch_body = try self.parse_block();
        return self.alloc_node(.{ .try_stmt = .{
            .body = body,
            .error_name = error_name,
            .catch_body = catch_body,
        } });
    }

    fn parse_assign_or_expr(self: *Parser) ParseError!*ast.Node {
        if (self.curr.type == .identifier and self.peek.type == .assign) {
            const name = self.curr.literal;
            self.advance(); // consume identifier
            self.advance(); // consume er
            const value = try self.parse_expr(0);
            return self.alloc_node(.{ .assign_stmt = .{ .name = name, .value = value } });
        }
        const expr = try self.parse_expr(0);
        return self.alloc_node(.{ .expr_stmt = .{ .expr = expr } });
    }

    fn parse_block(self: *Parser) ParseError!*ast.Node {
        if (self.curr.type != .lbrace) return ParseError.ExpectedOpenBrace;
        self.advance();
        var stmts: std.ArrayList(*ast.Node) = .{};
        while (self.curr.type != .rbrace and self.curr.type != .eof) {
            const stmt = try self.parse_statement();
            try stmts.append(self.arena, stmt);
        }
        if (self.curr.type != .rbrace) return ParseError.ExpectedCloseBrace;
        self.advance();
        return self.alloc_node(.{ .block = .{ .statements = try stmts.toOwnedSlice(self.arena) } });
    }

    // -------------------------------------------------------------------------
    // Expression parsing (Pratt)
    // -------------------------------------------------------------------------

    fn infix_precedence(tok: token.token_types) u8 {
        return switch (tok) {
            .assign => 1, // er as equality in expression context
            .ltag, .rtag => 2,
            .plus, .minus => 3,
            .asterisk, .fslash => 4,
            else => 0,
        };
    }

    pub fn parse_expr(self: *Parser, min_prec: u8) ParseError!*ast.Node {
        var left = try self.parse_primary();
        while (true) {
            const prec = infix_precedence(self.curr.type);
            if (prec <= min_prec) break;
            const op_tok = self.curr;
            self.advance();
            const right = try self.parse_expr(prec);
            const op_str: []const u8 = switch (op_tok.type) {
                .assign => "er",
                .equal => "erSameSom",
                .plus => "+",
                .minus => "-",
                .asterisk => "*",
                .fslash => "/",
                .ltag => "<",
                .rtag => ">",
                else => op_tok.literal,
            };
            left = try self.alloc_node(.{ .infix_expr = .{ .op = op_str, .left = left, .right = right } });
        }
        return left;
    }

    fn parse_primary(self: *Parser) ParseError!*ast.Node {
        switch (self.curr.type) {
            .integer => {
                const val = std.fmt.parseInt(i64, self.curr.literal, 10) catch return ParseError.InvalidInteger;
                const node = try self.alloc_node(.{ .integer_lit = .{ .value = val } });
                self.advance();
                return node;
            },
            .string => {
                const node = try self.alloc_node(.{ .string_lit = .{ .value = self.curr.literal } });
                self.advance();
                return node;
            },
            .true_val => {
                const node = try self.alloc_node(.{ .bool_lit = .{ .value = true } });
                self.advance();
                return node;
            },
            .false_val => {
                const node = try self.alloc_node(.{ .bool_lit = .{ .value = false } });
                self.advance();
                return node;
            },
            .bang, .minus => {
                const op: []const u8 = if (self.curr.type == .bang) "!" else "-";
                self.advance();
                const right = try self.parse_primary();
                return self.alloc_node(.{ .prefix_expr = .{ .op = op, .right = right } });
            },
            .lparen => {
                self.advance();
                const expr = try self.parse_expr(0);
                if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
                self.advance();
                return expr;
            },
            .lbracket => {
                return self.parse_list();
            },
            .identifier => {
                const name = self.curr.literal;
                self.advance();
                // member access: terminal.skriv(...)
                if (self.curr.type == .dot) {
                    self.advance();
                    if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
                    const member = self.curr.literal;
                    self.advance();
                    if (self.curr.type == .lparen) {
                        const args = try self.parse_call_args();
                        return self.alloc_node(.{ .member_call = .{ .object = name, .member = member, .args = args } });
                    }
                    return ParseError.UnexpectedToken;
                }
                // function call: foo(...)
                if (self.curr.type == .lparen) {
                    const callee = try self.alloc_node(.{ .identifier = .{ .name = name } });
                    const args = try self.parse_call_args();
                    return self.alloc_node(.{ .call_expr = .{ .callee = callee, .args = args } });
                }
                return self.alloc_node(.{ .identifier = .{ .name = name } });
            },
            else => return ParseError.UnexpectedToken,
        }
    }

    fn parse_call_args(self: *Parser) ParseError![]*ast.Node {
        try self.expect(.lparen);
        var args: std.ArrayList(*ast.Node) = .{};
        while (self.curr.type != .rparen and self.curr.type != .eof) {
            const arg = try self.parse_expr(0);
            try args.append(self.arena, arg);
            if (self.curr.type == .comma) self.advance();
        }
        try self.expect(.rparen);
        return args.toOwnedSlice(self.arena);
    }

    fn parse_list(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume [
        var elements: std.ArrayList(*ast.Node) = .{};
        while (self.curr.type != .rbracket and self.curr.type != .eof) {
            const elem = try self.parse_expr(0);
            try elements.append(self.arena, elem);
            if (self.curr.type == .comma) self.advance();
        }
        if (self.curr.type != .rbracket) return ParseError.ExpectedCloseBracket;
        self.advance();
        return self.alloc_node(.{ .list_lit = .{ .elements = try elements.toOwnedSlice(self.arena) } });
    }
};
