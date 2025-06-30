const std = @import("std");
const token = @import("token.zig");
const ast = @import("ast.zig");
const Lexer = token.Lexer;
const Token = token.Token;
const TokenType = token.TokenType;
const Allocator = std.mem.Allocator;

pub const Parser = struct {
    lexer: Lexer,
    allocator: Allocator,

    current_token: Token,
    peek_token: Token,

    errors: std.ArrayList([]const u8),

    // Pratt parser related fields for expressions
    // prefix_parse_fns: std.HashMap(TokenType, fn(*Parser) !ast.Expression, ...),
    // infix_parse_fns: std.HashMap(TokenType, fn(*Parser, ast.Expression) !ast.Expression, ...),
    // precedences: std.HashMap(TokenType, Precedence, ...),

    const Self = @This();

    pub fn init(lexer: Lexer, allocator: Allocator) Parser {
        var p = Parser{
            .lexer = lexer,
            .allocator = allocator,
            .current_token = undefined, // Will be set by two nextToken calls
            .peek_token = undefined, // Will be set by two nextToken calls
            .errors = std.ArrayList([]const u8).init(allocator),
        };

        // Read two tokens, so current_token and peek_token are both set
        p.nextToken();
        p.nextToken();

        return p;
    }

    pub fn deinit(p: *Parser) void {
        for (p.errors.items) |err_msg| {
            p.allocator.free(err_msg);
        }
        p.errors.deinit();
    }

    fn nextToken(p: *Parser) void {
        p.current_token = p.peek_token;
        p.peek_token = p.lexer.nextToken();
    }

    pub fn parseProgram(p: *Parser) !ast.Program {
        var program = ast.Program.init(p.allocator);

        while (p.current_token.kind != TokenType.Eof) {
            const stmt = p.parseStatement();
            if (stmt) |s| {
                try program.statements.append(s);
            } else |_| { // Error occurred during parsing statement
                // Error already recorded by parseStatement or a sub-parser
                // We could choose to synchronize here to find the next statement
            }
            p.nextToken();
        }
        return program;
    }

    fn parseStatement(p: *Parser) !?ast.Statement {
        return switch (p.current_token.kind) {
            TokenType.Fast, TokenType.Endreleg => blk: {
                const var_decl = try p.parseVariableDeclarationStatement();
                break :blk var_decl orelse null; // Propagate null if error
            },
            // TokenType.GjevTilbake => try p.parseReturnStatement(),
            // TokenType.Viss => try p.parseIfStatement(),
            // TokenType.Medan => try p.parseWhileStatement(),
            // TokenType.ForKvart => try p.parseForStatement(),
            // TokenType.Prøv => try p.parseTryCatchStatement(),
            // TokenType.Kast => try p.parseThrowStatement(),
            // TokenType.Modul => try p.parseModuleStatement(),
            // TokenType.Bruk => try p.parseImportStatement(),
            // TokenType.Lbrace => try p.parseBlockStatement(),
            else => { // ExpressionStatement
                // const expr_stmt = try p.parseExpressionStatement();
                // return expr_stmt orelse null;
                // For now, just log an error for unhandled statements
                try p.addError(std.fmt.allocPrint(p.allocator, "parseStatement: Unhandled token {s} ('{s}')", .{
                    @tagName(p.current_token.kind),
                    p.current_token.literal,
                }));
                return null;
            }
        };
    }

    fn parseVariableDeclarationStatement(p: *Parser) !?ast.Statement {
        const stmt_token = p.current_token; // 'fast' or 'endreleg'
        const is_mutable = stmt_token.kind == TokenType.Endreleg;

        if (!p.expectPeek(TokenType.Ident)) {
            // Error already added by expectPeek
            return null;
        }

        const name_ident = ast.Identifier{
            .token = p.current_token,
            .value = p.current_token.literal,
        };

        if (!p.expectPeek(TokenType.Er)) {
             // "fast foo" or "endreleg foo" without "er" is an error
            try p.addError(std.fmt.allocPrint(p.allocator, "Expected 'er' after identifier in variable declaration, got {s}", .{
                @tagName(p.peek_token.kind)
            }));
            return null;
        }
        // p.nextToken(); // Consume 'er' - expectPeek already did this if it returned true

        p.nextToken(); // Consume the expression's first token (current_token is now it)

        // TODO: Parse expression for the value
        // For now, we'll skip parsing the expression and assume no value or a dummy one
        // const value_expr = try p.parseExpression(Precedence.LOWEST);

        var var_decl = p.allocator.create(ast.VariableDeclarationStatement) catch |err| {
            try p.addError(std.fmt.allocPrint(p.allocator, "Memory allocation failed for VariableDeclarationStatement: {s}", .{@errorName(err)}));
            return null;
        };
        var_decl.* = .{
            .token = stmt_token,
            .name = name_ident,
            .value = null, // Placeholder for parsed expression
            .is_mutable = is_mutable,
        };

        // If semicolon is optional, we might not peek for it or just consume if present
        if (p.peekTokenIs(TokenType.Semicolon)) {
            p.nextToken(); // Consume ';'
        }

        return ast.Statement{ .VariableDeclaration = var_decl.* };
    }


    // --- Helper methods ---

    fn currentTokenIs(p: *Parser, t: TokenType) bool {
        return p.current_token.kind == t;
    }

    fn peekTokenIs(p: *Parser, t: TokenType) bool {
        return p.peek_token.kind == t;
    }

    // Advances tokens if peek_token is of expected type `t`.
    // Returns true if expectation met, false otherwise (and adds an error).
    fn expectPeek(p: *Parser, t: TokenType) bool {
        if (p.peekTokenIs(t)) {
            p.nextToken();
            return true;
        } else {
            p.peekError(t);
            return false;
        }
    }

    pub fn getErrors(p: *Parser) std.ArrayList([]const u8) {
        return p.errors;
    }

    fn peekError(p: *Parser, expected_type: TokenType) void {
        const msg = std.fmt.allocPrint(
            p.allocator,
            "Expected next token to be {s}, got {s} instead (literal: '{s}')",
            .{ @tagName(expected_type), @tagName(p.peek_token.kind), p.peek_token.literal },
        ) catch |err| {
            // If we can't even allocate memory for the error message, print a static one
             _ = p.errors.append(.("Failed to allocate error message for peekError.") ** 0) catch {};
            return;
        };
        _ = p.errors.append(msg) catch |err| {
            // If appending fails, free the allocated message
            p.allocator.free(msg);
        };
    }

    fn addError(p: *Parser, msg: []const u8) !void {
        try p.errors.append(msg);
    }
};


// Main parse function, entry point
pub fn parse(
    source: []const u8,
    // filename: [:0]const u8, // filename might be useful for error reporting later
    allocator: Allocator,
) !ast.Program {
    var lexer = Lexer.init(source);
    var parser = Parser.init(lexer, allocator);
    defer parser.deinit();

    const program = parser.parseProgram() catch |err| {
        // If parseProgram itself throws an error (e.g. OOM), wrap it or handle
        // For now, let's assume errors are collected in parser.errors
        // This path might be for unrecoverable errors from parseProgram directly
        std.debug.print("Error during parseProgram: {s}\n", .{@errorName(err)});
        return ast.Program.init(allocator); // Return an empty program
    };

    if (parser.errors.items.len > 0) {
        std.debug.print("Parser has {d} errors:\n", .{parser.errors.items.len});
        for (parser.errors.items) |errMsg| {
            std.debug.print("- {s}\n", .{errMsg});
        }
        // Depending on desired behavior, we might still return the partially parsed program
        // or indicate failure more strongly.
    }

    return program;
}


test "Parser: Variable Declaration Statements" {
    const input =
        \\fast x er 5;
        \\endreleg y er 10;
        \\fast z er sant;
    ;
    const allocator = std.testing.allocator;
    var program = try parse(input, allocator);
    defer program.deinit();

    try testing.expectEqual(@as(usize, 3), program.statements.items.len);
    if (program.errors.items.len > 0) {
        std.debug.print("Errors found during test:\n", .{});
        for(program.errors.items) |err| {
            std.debug.print("- {s}\n", .{err});
        }
    }
    try testing.expectEqual(@as(usize, 0), program.errors.items.len);


    const expected_vars = [_]struct {
        name: []const u8,
        is_mutable: bool,
        // We are not parsing expression values yet
        // value_type: ?std.meta.Tag(ast.Expression),
    }{
        .{ .name = "x", .is_mutable = false },
        .{ .name = "y", .is_mutable = true },
        .{ .name = "z", .is_mutable = false },
    };

    for (program.statements.items, 0..) |stmt, i| {
        try testing.expect(stmt.VariableDeclaration != null);
        const var_decl = stmt.VariableDeclaration;

        try testing.expectEqualStrings(expected_vars[i].name, var_decl.name.value);
        try testing.expectEqual(expected_vars[i].is_mutable, var_decl.is_mutable);
        if (expected_vars[i].is_mutable) {
            try testing.expectEqual(TokenType.Endreleg, var_decl.token.kind);
        } else {
            try testing.expectEqual(TokenType.Fast, var_decl.token.kind);
        }
        // TODO: Test var_decl.value once expression parsing is implemented
        try testing.expect(var_decl.value == null); // Current behavior
    }
}

test "Parser: Error for missing identifier in var decl" {
    const input = "fast er 5;";
    const allocator = std.testing.allocator;
    var program = try parse(input, allocator);
    defer program.deinit();

    // Should produce an error
    try testing.expect(program.errors.items.len > 0);
    if (program.errors.items.len > 0) {
        // std.debug.print("Error: {s}\n", .{program.errors.items[0]});
        try testing.expect(std.mem.containsAtLeast(u8, program.errors.items[0], 1, "Expected next token to be Ident, got Er instead"));
    }
}

test "Parser: Error for missing 'er' in var decl" {
    const input = "fast x 5;";
    const allocator = std.testing.allocator;
    var program = try parse(input, allocator);
    defer program.deinit();

    try testing.expect(program.errors.items.len > 0);
     if (program.errors.items.len > 0) {
        // std.debug.print("Error: {s}\n", .{program.errors.items[0]});
        try testing.expect(std.mem.containsAtLeast(u8, program.errors.items[0], 1, "Expected 'er' after identifier"));
    }
}

const std = @import("std");
const Brunost_Parser = @This();
const testing = std.testing;
