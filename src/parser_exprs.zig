const std = @import("std");
const token = @import("token.zig");
const ast = @import("ast.zig");
const nynorsk = @import("nynorsk.zig");
const parser_mod = @import("parser.zig");
const Parser = parser_mod.Parser;
const ParseError = parser_mod.ParseError;

const logical_not_precedence = 2;

fn infix_precedence(tok: token.token_types) u8 {
    return switch (tok) {
        .or_op => 1,
        .and_op => 2,
        .assign, .equal => 3,
        .ltag, .rtag, .lt, .gt, .lte, .gte => 4,
        .plus, .minus => 5,
        .asterisk, .fslash => 6,
        else => 0,
    };
}

pub fn parse_assign_or_expr(self: *Parser) ParseError!*ast.Node {
    // Field assignment or member call: identifier.member ...
    if (self.curr.type == .identifier and self.peek.type == .dot) {
        const obj = self.curr.literal;
        self.advance();
        self.advance();
        if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
        const member = self.curr.literal;
        self.advance();
        if (self.curr.type == .assign) {
            self.advance();
            const value = try parse_expr(self, 0);
            return self.alloc_node(.{ .field_assign = .{ .object = obj, .field = member, .value = value } });
        }
        if (self.curr.type == .lparen or is_lambda_start(self)) {
            const args = if (self.curr.type == .lparen)
                try parse_call_args(self)
            else
                try parse_implicit_lambda_call_args(self);
            const call_node = try self.alloc_node(.{ .member_call = .{ .object = obj, .member = member, .args = args } });
            return self.alloc_node(.{ .expr_stmt = .{ .expr = call_node } });
        }
        const fa = try self.alloc_node(.{ .field_access = .{ .object = obj, .field = member } });
        return self.alloc_node(.{ .expr_stmt = .{ .expr = fa } });
    }
    // Compound assignment: name += expr, name -= expr, etc.
    if (self.curr.type == .identifier) {
        const name = self.curr.literal;
        const compound_op: ?[]const u8 = switch (self.peek.type) {
            .plus_assign => "+",
            .minus_assign => "-",
            .star_assign => "*",
            .slash_assign => "/",
            else => null,
        };
        if (compound_op) |op| {
            self.advance();
            self.advance();
            const rhs = try parse_expr(self, 0);
            const name_node = try self.alloc_node(.{ .identifier = .{ .name = name } });
            const bin_node = try self.alloc_node(.{ .infix_expr = .{ .op = op, .left = name_node, .right = rhs } });
            return self.alloc_node(.{ .assign_stmt = .{ .name = name, .value = bin_node } });
        }
    }
    // Simple variable assignment: name er expr
    if (self.curr.type == .identifier and self.peek.type == .assign) {
        const name = self.curr.literal;
        self.advance();
        self.advance();
        const value = try parse_expr(self, 0);
        return self.alloc_node(.{ .assign_stmt = .{ .name = name, .value = value } });
    }
    const expr = try parse_expr(self, 0);
    return self.alloc_node(.{ .expr_stmt = .{ .expr = expr } });
}

pub fn parse_expr(self: *Parser, min_prec: u8) ParseError!*ast.Node {
    var left = try parse_primary(self);
    while (true) {
        if (self.curr.type == .lbracket) {
            self.advance();
            const index = try parse_expr(self, 0);
            if (self.curr.type != .rbracket) return ParseError.ExpectedCloseBracket;
            self.advance();
            left = try self.alloc_node(.{ .index_expr = .{ .object = left, .index = index } });
            continue;
        }
        const prec = infix_precedence(self.curr.type);
        if (prec <= min_prec) break;
        const op_tok = self.curr;
        self.advance();
        const right = try parse_expr(self, prec);
        const op_str: []const u8 = switch (op_tok.type) {
            .or_op => "eller",
            .and_op => "og",
            .assign => "er",
            .equal => "erSameSom",
            .plus => "+",
            .minus => "-",
            .asterisk => "*",
            .fslash => "/",
            .ltag, .lt => "<",
            .rtag, .gt => ">",
            .lte => "<=",
            .gte => ">=",
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
        .float => {
            const val = std.fmt.parseFloat(f64, self.curr.literal) catch return ParseError.InvalidFloat;
            const node = try self.alloc_node(.{ .float_lit = .{ .value = val } });
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
        .bang, .not_op => {
            self.advance();
            const right = try parse_expr(self, logical_not_precedence);
            return self.alloc_node(.{ .prefix_expr = .{ .op = "!", .right = right } });
        },
        .minus => {
            self.advance();
            const right = try parse_primary(self);
            return self.alloc_node(.{ .prefix_expr = .{ .op = "-", .right = right } });
        },
        .lparen => {
            self.advance();
            const expr = try parse_expr(self, 0);
            if (self.curr.type != .rparen) return ParseError.ExpectedCloseParen;
            self.advance();
            return expr;
        },
        .lbracket => {
            return parse_list(self);
        },
        .lbrace => {
            if (is_lambda_start(self)) {
                return parse_lambda_expr(self);
            }
            return parse_hashmap(self);
        },
        .identifier => {
            const name = self.curr.literal;
            self.advance();
            if (self.curr.type == .dot) {
                self.advance();
                if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
                const member = self.curr.literal;
                self.advance();
                if (self.curr.type == .lparen) {
                    const args = try parse_call_args(self);
                    return self.alloc_node(.{ .member_call = .{ .object = name, .member = member, .args = args } });
                }
                if (is_lambda_start(self)) {
                    const args = try parse_implicit_lambda_call_args(self);
                    return self.alloc_node(.{ .member_call = .{ .object = name, .member = member, .args = args } });
                }
                return self.alloc_node(.{ .field_access = .{ .object = name, .field = member } });
            }
            if (!self.no_struct_lit and self.curr.type == .lbrace) {
                self.advance();
                var lit_fields: std.ArrayList(ast.StructLitField) = .empty;
                while (self.curr.type != .rbrace and self.curr.type != .eof) {
                    if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
                    const field_name = self.curr.literal;
                    if (!nynorsk.isValidIdentifier(field_name)) return ParseError.NotNynorsk;
                    self.advance();
                    try self.expect(.assign);
                    const val = try parse_expr(self, 0);
                    try lit_fields.append(self.arena, .{ .name = field_name, .value = val });
                    if (self.curr.type == .comma) self.advance();
                }
                if (self.curr.type != .rbrace) return ParseError.UnexpectedToken;
                self.advance();
                return self.alloc_node(.{ .struct_lit = .{
                    .type_name = name,
                    .fields = try lit_fields.toOwnedSlice(self.arena),
                } });
            }
            if (self.curr.type == .lparen) {
                const callee = try self.alloc_node(.{ .identifier = .{ .name = name } });
                const args = try parse_call_args(self);
                return self.alloc_node(.{ .call_expr = .{ .callee = callee, .args = args } });
            }
            if (is_lambda_start(self)) {
                const callee = try self.alloc_node(.{ .identifier = .{ .name = name } });
                const args = try parse_implicit_lambda_call_args(self);
                return self.alloc_node(.{ .call_expr = .{ .callee = callee, .args = args } });
            }
            return self.alloc_node(.{ .identifier = .{ .name = name } });
        },
        else => return ParseError.UnexpectedToken,
    }
}

fn parse_call_args(self: *Parser) ParseError![]*ast.Node {
    try self.expect(.lparen);
    var args: std.ArrayList(*ast.Node) = .empty;
    while (self.curr.type != .rparen and self.curr.type != .eof) {
        const arg = try parse_expr(self, 0);
        try args.append(self.arena, arg);
        if (self.curr.type == .comma) self.advance();
    }
    try self.expect(.rparen);
    try maybe_append_trailing_lambda(self, &args);
    return args.toOwnedSlice(self.arena);
}

fn parse_implicit_lambda_call_args(self: *Parser) ParseError![]*ast.Node {
    var args: std.ArrayList(*ast.Node) = .empty;
    try maybe_append_trailing_lambda(self, &args);
    return args.toOwnedSlice(self.arena);
}

fn maybe_append_trailing_lambda(self: *Parser, args: *std.ArrayList(*ast.Node)) ParseError!void {
    if (!is_lambda_start(self)) return;
    const lambda = try parse_lambda_expr(self);
    try args.append(self.arena, lambda);
}

fn is_lambda_start(self: *Parser) bool {
    if (self.curr.type != .lbrace) return false;

    var look_token = self.peek;
    var look_lexer = self.lexer;

    if (look_token.type == .arrow) return true;
    if (look_token.type != .identifier) return false;

    while (true) {
        const next = look_lexer.next_token();
        switch (next.type) {
            .arrow => return true,
            .comma => {
                look_token = look_lexer.next_token();
                if (look_token.type != .identifier) return false;
            },
            else => return false,
        }
    }
}

fn parse_lambda_expr(self: *Parser) ParseError!*ast.Node {
    try self.expect(.lbrace);
    var params: std.ArrayList([]const u8) = .empty;
    if (self.curr.type != .arrow) {
        while (true) {
            if (self.curr.type != .identifier) return ParseError.ExpectedIdentifier;
            if (!nynorsk.isValidIdentifier(self.curr.literal)) return ParseError.NotNynorsk;
            try params.append(self.arena, self.curr.literal);
            self.advance();
            if (self.curr.type != .comma) break;
            self.advance();
        }
    }
    if (self.curr.type != .arrow) return ParseError.ExpectedArrow;
    self.advance();
    const body = try parse_expr(self, 0);
    if (self.curr.type != .rbrace) return ParseError.ExpectedCloseBrace;
    self.advance();
    return self.alloc_node(.{ .lambda_expr = .{
        .params = try params.toOwnedSlice(self.arena),
        .body = body,
    } });
}

fn parse_list(self: *Parser) ParseError!*ast.Node {
    self.advance();
    var elements: std.ArrayList(*ast.Node) = .empty;
    while (self.curr.type != .rbracket and self.curr.type != .eof) {
        const elem = try parse_expr(self, 0);
        try elements.append(self.arena, elem);
        if (self.curr.type == .comma) self.advance();
    }
    if (self.curr.type != .rbracket) return ParseError.ExpectedCloseBracket;
    self.advance();
    return self.alloc_node(.{ .list_lit = .{ .elements = try elements.toOwnedSlice(self.arena) } });
}

fn parse_hashmap(self: *Parser) ParseError!*ast.Node {
    self.advance();
    var pairs: std.ArrayList(ast.HashmapPair) = .empty;
    while (self.curr.type != .rbrace and self.curr.type != .eof) {
        const key = try parse_expr(self, 0);
        if (self.curr.type != .colon) return ParseError.UnexpectedToken;
        self.advance();
        const value = try parse_expr(self, 0);
        try pairs.append(self.arena, .{ .key = key, .value = value });
        if (self.curr.type == .comma) self.advance();
    }
    if (self.curr.type != .rbrace) return ParseError.UnexpectedToken;
    self.advance();
    return self.alloc_node(.{ .hashmap_lit = .{ .pairs = try pairs.toOwnedSlice(self.arena) } });
}
