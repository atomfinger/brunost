const std = @import("std");
const token = @import("token.zig");
const ast = @import("ast.zig");
const nynorsk = @import("nynorsk.zig");
const pexprs = @import("parser_exprs.zig");

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
    ExpectedArrow,
    InvalidInteger,
    InvalidFloat,
    OutOfMemory,
    NotNynorsk,
};

pub const ParseDiagnostic = struct {
    err: ParseError,
    token_type: token.token_types,
    literal: []const u8,
    line: usize,
    column: usize,
};

pub const Parser = struct {
    lexer: token.Lexer,
    curr: token.Token,
    peek: token.Token,
    arena: std.mem.Allocator,
    /// When true, `parse_primary` will not try to parse `identifier {` as a
    /// struct literal. Used in contexts where `{` starts a block (e.g. forKvart body).
    no_struct_lit: bool = false,

    pub fn init(lexer: token.Lexer, arena: std.mem.Allocator) Parser {
        var p = Parser{
            .lexer = lexer,
            .curr = token.Token.init(.nul, "", 0),
            .peek = token.Token.init(.nul, "", 0),
            .arena = arena,
        };
        p.advance();
        p.advance();
        return p;
    }

    pub fn advance(self: *Parser) void {
        self.curr = self.peek;
        self.peek = self.lexer.next_token();
    }

    pub fn expect(self: *Parser, kind: token.token_types) ParseError!void {
        if (self.curr.type != kind) return ParseError.UnexpectedToken;
        self.advance();
    }

    pub fn alloc_node(self: *Parser, node: ast.Node) ParseError!*ast.Node {
        const n = try self.arena.create(ast.Node);
        n.* = node;
        return n;
    }

    pub fn current_diagnostic(self: *const Parser, err: ParseError) ParseDiagnostic {
        const location = line_and_column(self.lexer.input, self.curr.offset);
        return .{
            .err = err,
            .token_type = self.curr.type,
            .literal = self.curr.literal,
            .line = location.line,
            .column = location.column,
        };
    }

    fn line_and_column(source: []const u8, offset: usize) struct { line: usize, column: usize } {
        var line: usize = 1;
        var column: usize = 1;
        var index: usize = 0;
        while (index < source.len and index < offset) : (index += 1) {
            if (source[index] == '\n') {
                line += 1;
                column = 1;
            } else {
                column += 1;
            }
        }
        return .{ .line = line, .column = column };
    }

    pub fn parse_program(self: *Parser) ParseError!*ast.Node {
        var stmts: std.ArrayList(*ast.Node) = .empty;
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
            .import_op => self.parse_import(),
            .module_op => self.parse_module_decl(),
            .type_op => self.parse_struct_decl(),
            .break_op => self.parse_break(),
            .continue_op => self.parse_continue(),
            else => pexprs.parse_assign_or_expr(self),
        };
    }

    fn parse_break(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume bryt
        return self.alloc_node(.{ .break_stmt = .{} });
    }

    fn parse_continue(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume fortset
        return self.alloc_node(.{ .continue_stmt = .{} });
    }

    fn parse_var_decl(self: *Parser, mutable: bool) ParseError!*ast.Node {
        self.advance(); // consume open / låst
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const name = self.curr.literal;
        if (!nynorsk.isValidIdentifier(name)) return ParseError.NotNynorsk;
        self.advance();
        try self.expect(.assign); // er
        const value = try pexprs.parse_expr(self, 0);
        return self.alloc_node(.{ .var_decl = .{ .mutable = mutable, .name = name, .value = value } });
    }

    fn parse_return(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume gjevTilbake
        const value = try pexprs.parse_expr(self, 0);
        return self.alloc_node(.{ .return_stmt = .{ .value = value } });
    }

    fn parse_throw(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume kast
        const value = try pexprs.parse_expr(self, 0);
        return self.alloc_node(.{ .throw_stmt = .{ .value = value } });
    }

    fn parse_fn_decl(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume gjer
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const name = self.curr.literal;
        if (!nynorsk.isValidIdentifier(name)) return ParseError.NotNynorsk;
        self.advance();
        try self.expect(.lparen);
        var params: std.ArrayList([]const u8) = .empty;
        while (self.curr.type != .rparen and self.curr.type != .eof) {
            if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
            if (!nynorsk.isValidIdentifier(self.curr.literal)) return ParseError.NotNynorsk;
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
        const condition = try pexprs.parse_expr(self, 0);
        if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
        self.advance();
        // gjer (the "do" keyword)
        if (self.curr.type != .function) return ParseError.ExpectedDo;
        self.advance();
        const consequence = try self.parse_block();
        var alternative: ?*ast.Node = null;
        if (self.curr.type == .else_op) {
            self.advance(); // consume elles
            if (self.curr.type == .if_op) {
                alternative = try self.parse_if();
            } else {
                alternative = try self.parse_block();
            }
        }
        return self.alloc_node(.{ .if_stmt = .{
            .condition = condition,
            .consequence = consequence,
            .alternative = alternative,
        } });
    }

    fn parse_while(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume medan
        if (self.curr.type != .lparen) return ParseError.ExpectedOpenParen;
        self.advance();
        const condition = try pexprs.parse_expr(self, 0);
        if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
        self.advance();
        if (self.curr.type != .function) return ParseError.ExpectedDo;
        self.advance();
        const body = try self.parse_block();
        return self.alloc_node(.{ .while_stmt = .{
            .condition = condition,
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
        self.no_struct_lit = true;
        const iterable = try pexprs.parse_expr(self, 0);
        self.no_struct_lit = false;
        const body = try self.parse_block();
        return self.alloc_node(.{ .foreach_stmt = .{
            .iterator_name = iter_name,
            .iterable = iterable,
            .body = body,
        } });
    }

    fn parse_import(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume bruk
        var segments: std.ArrayList([]const u8) = .empty;
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        try segments.append(self.arena, self.curr.literal);
        self.advance();
        while (self.curr.type == .dot) {
            self.advance(); // consume .
            if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
            try segments.append(self.arena, self.curr.literal);
            self.advance();
        }
        var alias: ?[]const u8 = null;
        if (self.curr.type == .as_op) {
            self.advance(); // consume som
            if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
            alias = self.curr.literal;
            self.advance();
        }
        return self.alloc_node(.{ .import_stmt = .{
            .segments = try segments.toOwnedSlice(self.arena),
            .alias = alias,
        } });
    }

    fn parse_module_decl(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume modul
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const name = self.curr.literal;
        self.advance();
        if (self.curr.type != .lbrace) return ParseError.ExpectedOpenBrace;
        self.advance();
        var functions: std.ArrayList(*ast.Node) = .empty;
        while (self.curr.type != .rbrace and self.curr.type != .eof) {
            if (self.curr.type != .function) return ParseError.UnexpectedToken;
            const fn_node = try self.parse_fn_decl();
            try functions.append(self.arena, fn_node);
        }
        if (self.curr.type != .rbrace) return ParseError.ExpectedCloseBrace;
        self.advance();
        return self.alloc_node(.{ .module_decl = .{
            .name = name,
            .functions = try functions.toOwnedSlice(self.arena),
        } });
    }

    fn parse_struct_decl(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume type
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const name = self.curr.literal;
        if (!nynorsk.isValidIdentifier(name)) return ParseError.NotNynorsk;
        self.advance();
        if (self.curr.type != .lbrace) return ParseError.ExpectedOpenBrace;
        self.advance(); // consume {
        var fields: std.ArrayList(ast.StructFieldDecl) = .empty;
        while (self.curr.type != .rbrace and self.curr.type != .eof) {
            const mutable = switch (self.curr.type) {
                .let_immutable => false,
                .let_mutable => true,
                else => return ParseError.UnexpectedToken,
            };
            self.advance(); // consume låst/open
            if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
            const field_name = self.curr.literal;
            if (!nynorsk.isValidIdentifier(field_name)) return ParseError.NotNynorsk;
            self.advance();
            var default_value: ?*ast.Node = null;
            if (self.curr.type == .assign) {
                self.advance(); // consume er
                default_value = try pexprs.parse_expr(self, 0);
            }
            try fields.append(self.arena, .{
                .name = field_name,
                .default_value = default_value,
                .mutable = mutable,
            });
        }
        if (self.curr.type != .rbrace) return ParseError.ExpectedCloseBrace;
        self.advance(); // consume }
        return self.alloc_node(.{ .struct_decl = .{
            .name = name,
            .fields = try fields.toOwnedSlice(self.arena),
        } });
    }

    fn parse_try(self: *Parser) ParseError!*ast.Node {
        self.advance(); // consume prøv
        const body = try self.parse_block();

        var error_name: []const u8 = "";
        var catch_body: ?*ast.Node = null;
        var finally_body: ?*ast.Node = null;

        if (self.curr.type == .catch_op) {
            self.advance();
            if (self.curr.type != .lparen) return ParseError.ExpectedOpenParen;
            self.advance();
            if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
            error_name = self.curr.literal;
            self.advance();
            if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
            self.advance();
            catch_body = try self.parse_block();
        }

        if (self.curr.type == .finally_op) {
            self.advance();
            finally_body = try self.parse_block();
        }

        if (catch_body == null and finally_body == null) {
            return ParseError.UnexpectedToken;
        }

        return self.alloc_node(.{ .try_stmt = .{
            .body = body,
            .error_name = error_name,
            .catch_body = catch_body,
            .finally_body = finally_body,
        } });
    }

    fn parse_block(self: *Parser) ParseError!*ast.Node {
        if (self.curr.type != .lbrace) return ParseError.ExpectedOpenBrace;
        self.advance();
        var stmts: std.ArrayList(*ast.Node) = .empty;
        while (self.curr.type != .rbrace and self.curr.type != .eof) {
            const stmt = try self.parse_statement();
            try stmts.append(self.arena, stmt);
        }
        if (self.curr.type != .rbrace) return ParseError.ExpectedCloseBrace;
        self.advance();
        return self.alloc_node(.{ .block = .{ .statements = try stmts.toOwnedSlice(self.arena) } });
    }

    pub fn parse_expr(self: *Parser, min_prec: u8) ParseError!*ast.Node {
        return pexprs.parse_expr(self, min_prec);
    }
};
