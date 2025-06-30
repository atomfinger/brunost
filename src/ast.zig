// src/ast.zig
const std = @import("std");
const token = @import("token.zig");
const Allocator = std.mem.Allocator;

// Forward declarations for recursive types if needed
pub const Node = union(enum) {
    Program: Program,
    Statement: Statement,
    Expression: Expression,

    pub fn format(self: Node, writer: anytype, level: usize) !void {
        switch (self) {
            .Program => |p| try p.format(writer, level),
            .Statement => |s| try s.format(writer, level),
            .Expression => |e| try e.format(writer, level),
        }
    }

    // TODO: Add a general method to get the token literal for error reporting / debugging
    // pub fn tokenLiteral(self: Node) []const u8 { ... }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),

    pub fn init(allocator: Allocator) Program {
        return Program{
            .statements = std.ArrayList(Statement).init(allocator),
        };
    }

    pub fn deinit(self: *Program) void {
        // Deinitialize individual statements if they own memory
        for (self.statements.items) |*stmt| {
            stmt.deinit();
        }
        self.statements.deinit();
    }

    pub fn format(self: Program, writer: anytype, level: usize) !void {
        _ = level;
        for (self.statements.items) |stmt| {
            try stmt.format(writer, 0);
            try writer.print("\n", .{});
        }
    }
};

pub const Statement = union(enum) {
    VariableDeclaration: VariableDeclarationStatement,
    Expression: ExpressionStatement,
    Return: ReturnStatement,
    Block: BlockStatement,
    // TODO: Add other statement types: If, While, For, TryCatch, Throw, Module, Import

    pub fn format(self: Statement, writer: anytype, level: usize) !void {
        switch (self) {
            .VariableDeclaration => |s| try s.format(writer, level),
            .Expression => |s| try s.format(writer, level),
            .Return => |s| try s.format(writer, level),
            .Block => |s| try s.format(writer, level),
        }
    }

    pub fn deinit(self: *Statement) void {
        switch (self.*) {
            .VariableDeclaration => |*s| s.deinit(),
            .Expression => |*s| s.deinit(),
            .Return => |*s| s.deinit(),
            .Block => |*s| s.deinit(),
            // Add deinit for other statement types
        }
    }
};

pub const Expression = union(enum) {
    Identifier: Identifier,
    NumberLiteral: NumberLiteral,
    StringLiteral: StringLiteral,
    Boolean: BooleanLiteral,
    // TODO: Add other expression types: List, Prefix, Infix, Call, Index, MemberAccess

    pub fn format(self: Expression, writer: anytype, level: usize) !void {
        _ = level;
        switch (self) {
            .Identifier => |e| try writer.print("{s}", .{e.value}),
            .NumberLiteral => |e| try writer.print("{d}", .{e.value}),
            .StringLiteral => |e| try writer.print("\"{s}\"", .{e.value}),
            .Boolean => |e| try writer.print("{s}", .{if (e.value) "sant" else "usant"}),
        }
    }

    pub fn deinit(self: *Expression) void {
        switch (self.*) {
            .Identifier => |*e| e.deinit(),
            .StringLiteral => |*e| e.deinit(),
            // NumberLiteral and Boolean don't own memory directly allocated for their values
            .NumberLiteral, .Boolean => {},
            // Add deinit for other expression types
        }
    }
};

// --- Specific Statement Nodes ---

pub const VariableDeclarationStatement = struct {
    token: token.Token, // The 'fast' or 'endreleg' token
    name: Identifier,
    value: ?Expression, // Initializer expression
    is_mutable: bool,

    pub fn format(self: VariableDeclarationStatement, writer: anytype, level: usize) !void {
        _ = level;
        try writer.print("{s} {s} er ", .{ self.token.literal, self.name.value });
        if (self.value) |val| {
            try val.format(writer, 0);
        }
        try writer.print(";", .{});
    }

    pub fn deinit(self: *VariableDeclarationStatement) void {
        self.name.deinit();
        if (self.value) |*val| {
            val.deinit();
        }
    }
};

pub const ExpressionStatement = struct {
    token: token.Token, // The first token of the expression
    expression: Expression,

    pub fn format(self: ExpressionStatement, writer: anytype, level: usize) !void {
        _ = level;
        try self.expression.format(writer, 0);
        try writer.print(";", .{});
    }

    pub fn deinit(self: *ExpressionStatement) void {
        self.expression.deinit();
    }
};

pub const ReturnStatement = struct {
    token: token.Token, // The 'gjevTilbake' token
    return_value: ?Expression,

    pub fn format(self: ReturnStatement, writer: anytype, level: usize) !void {
        _ = level;
        try writer.print("{s}", .{self.token.literal});
        if (self.return_value) |val| {
            try writer.print(" ", .{});
            try val.format(writer, 0);
        }
        try writer.print(";", .{});
    }

    pub fn deinit(self: *ReturnStatement) void {
        if (self.return_value) |*val| {
            val.deinit();
        }
    }
};

pub const BlockStatement = struct {
    token: token.Token, // The '{' token
    statements: std.ArrayList(Statement),
    allocator: Allocator,

    pub fn format(self: BlockStatement, writer: anytype, level: usize) !void {
        try writer.print("{{\n", .{});
        for (self.statements.items) |stmt| {
            try writer.print("{s}", .{@tagName(stmt)}); // Basic indentation
            try stmt.format(writer, level + 1);
            try writer.print("\n", .{});
        }
        try writer.print("{s}}}", .{@tagName(self)}); // Basic indentation
    }

    pub fn deinit(self: *BlockStatement) void {
        for (self.statements.items) |*stmt| {
            stmt.deinit();
        }
        self.statements.deinit();
    }
};

// --- Specific Expression Nodes ---

pub const Identifier = struct {
    token: token.Token, // The TokenType.Ident token
    value: []const u8, // Owned by the original source string, or needs allocation if modified

    pub fn format(self: Identifier, writer: anytype, level: usize) !void {
        _ = level;
        try writer.print("{s}", .{self.value});
    }

    pub fn deinit(self: *Identifier) void {
        // If 'value' was allocated, free it here. Assuming it's a slice of input for now.
    }
};

pub const NumberLiteral = struct {
    token: token.Token, // The TokenType.Num token
    value: i64, // Assuming numbers are i64 for now. Could be f64 or a union.

    pub fn format(self: NumberLiteral, writer: anytype, level: usize) !void {
        _ = level;
        try writer.print("{d}", .{self.value});
    }
};

pub const StringLiteral = struct {
    token: token.Token, // The TokenType.String token
    value: []const u8, // This will be owned by an allocator if we need to unescape
    allocator: ?Allocator = null, // Used if string needs unescaping/copying

    pub fn format(self: StringLiteral, writer: anytype, level: usize) !void {
        _ = level;
        try writer.print("\"{s}\"", .{self.value});
    }

    pub fn deinit(self: *StringLiteral) void {
        if (self.allocator) |alloc| {
            // If 'value' was allocated by this node, free it.
            // For now, assuming it's a slice of the input or parser-allocated.
            // alloc.free(self.value); // This would be if StringLiteral specifically allocated it
        }
    }
};

pub const BooleanLiteral = struct {
    token: token.Token, // The TokenType.Sant or TokenType.Usant token
    value: bool,

    pub fn format(self: BooleanLiteral, writer: anytype, level: usize) !void {
        _ = level;
        try writer.print("{s}", .{if (self.value) "sant" else "usant"});
    }
};

// TODO:
// pub const PrefixExpression = struct { ... };
// pub const InfixExpression = struct { ... };
// pub const IfExpression = struct { ... }; // Or IfStatement if 'viss' is not an expression
// pub const FunctionLiteral = struct { ... }; // Corresponds to 'gjer' statement
// pub const CallExpression = struct { ... };
// pub const ListLiteral = struct { ... };
// pub const IndexExpression = struct { ... };
// pub const MemberAccessExpression = struct { ... };

// pub const FunctionDefinitionStatement = struct { ... };
// pub const IfStatement = struct { ... };
// pub const WhileStatement = struct { ... };
// pub const ForStatement = struct { ... };
// pub const TryCatchStatement = struct { ... };
// pub const ThrowStatement = struct { ... };
// pub const ModuleStatement = struct { ... };
// pub const ImportStatement = struct { ... };

test "AST Node Formatting" {
    const allocator = std.testing.allocator;
    var program = Program.init(allocator);
    defer program.deinit();

    // fast numEr1 er 10;
    const ident1 = Identifier{ .token = token.Token.init(token.TokenType.Ident, "numEr1"), .value = "numEr1" };
    const num_lit1 = Expression.NumberLiteral = .{ .token = token.Token.init(token.TokenType.Num, "10"), .value = 10 };
    var var_decl1 = Statement.VariableDeclaration = .{
        .token = token.Token.init(token.TokenType.Fast, "fast"),
        .name = ident1,
        .value = num_lit1,
        .is_mutable = false,
    };
    try program.statements.append(var_decl1);

    // "test string"; (as an expression statement)
    var str_lit_expr = Expression.StringLiteral = .{
        .token = token.Token.init(token.TokenType.String, "test string"),
        .value = "test string",
    };
    var expr_stmt = Statement.Expression = .{
        .token = str_lit_expr.token,
        .expression = str_lit_expr,
    };
    try program.statements.append(expr_stmt);


    // TODO: Expand with more complex structures once they are defined
    // For now, just test basic formatting
    // var writer = std.io.getStdErr().writer(); // For debugging
    // try program.format(writer, 0);

    // Dummy test, real testing will involve parsing actual code
    try std.testing.expect(program.statements.items.len == 2);
}
