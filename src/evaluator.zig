// src/evaluator.zig
const std = @import("std");
const ast = @import("ast.zig");
const object = @import("object.zig");
const Environment = @import("environment.zig").Environment;
const Allocator = std.mem.Allocator;

const Object = object.Object;
const TRUE = object.TRUE;
const FALSE = object.FALSE;
const NULL = object.NULL;

// Forward declaration for eval_block_statement if needed, or just ensure order
fn eval_statements(statements: []const ast.Statement, env: *Environment, allocator: Allocator) !*Object;
fn eval_block_statement(block: ast.BlockStatement, env: *Environment, allocator: Allocator) !*Object;

pub fn eval(node: ast.Node, env: *Environment, allocator: Allocator) !*Object {
    return switch (node) {
        .Program => |prog| eval_program(prog, env, allocator),
        .Statement => |stmt| eval_statement(stmt, env, allocator),
        .Expression => |expr| eval_expression(expr, env, allocator),
    };
}

fn eval_program(program_node: ast.Program, env: *Environment, allocator: Allocator) !*Object {
    return eval_statements(program_node.statements.items, env, allocator);
}

fn eval_statements(statements: []const ast.Statement, env: *Environment, allocator: Allocator) !*Object {
    var result: *Object = try allocator.create(Object); // Default to NULL or last expr
    result.* = NULL;

    for (statements) |stmt_union| {
        // Before evaluating next statement, free previous non-NULL, non-Return, non-Error result
        // if it's not one of the singletons (TRUE, FALSE, NULL).
        // This is tricky because 'result' might be a pointer to a shared TRUE/FALSE/NULL.
        // A safer approach is to ensure that any allocated object from eval_statement is deallocated
        // if not propagated (e.g. as a ReturnValue or Error).
        // For now, let's be careful: eval_statement should return allocated objects that the caller (this loop)
        // then owns, unless it's a ReturnValue or Error.

        const current_eval_result = try eval_statement(stmt_union, env, allocator);
        defer if (current_eval_result != &TRUE and current_eval_result != &FALSE and current_eval_result != &NULL and
                   current_eval_result.type != .ReturnValue and current_eval_result.type != .Error)
        {
            // std.debug.print("eval_statements: deallocating intermediate result\n", .{});
            current_eval_result.deinit(allocator); // Deinit the object's contents
            allocator.destroy(current_eval_result); // Destroy the object pointer itself
        } else if (current_eval_result.type == .ReturnValue or current_eval_result.type == .Error) {
             // If we got a ReturnValue or Error, destroy the 'result' we allocated at the start of this function,
             // as we are about to return the propagated ReturnValue/Error instead.
             if (result != &TRUE and result != &FALSE and result != &NULL) {
                allocator.destroy(result);
             }
             return current_eval_result; // Propagate immediately
        }


        // If it was a normal statement, we might not update 'result' unless it's an ExprStmt
        // For now, the last statement's result (if it's an expression statement) could be considered.
        // But Brunost might not have implicit returns from blocks like Rust.
        // Let's assume 'result' remains NULL unless explicitly set by a return.
        // The defer above handles freeing intermediate results.
    }
    return result; // Returns NULL if no explicit return
}


fn eval_statement(statement_union: ast.Statement, env: *Environment, allocator: Allocator) !*Object {
    return switch (statement_union) {
        .Expression => |expr_stmt| eval_expression_statement(expr_stmt, env, allocator),
        .VariableDeclaration => |var_decl_stmt| eval_variable_declaration_statement(var_decl_stmt, env, allocator),
        .Return => |ret_stmt| eval_return_statement(ret_stmt, env, allocator),
        .Block => |block_stmt| eval_block_statement(block_stmt, env, allocator),
        // TODO: Add other statement types
        // .If => |if_stmt| eval_if_statement(if_stmt, env, allocator),
        // .While => |while_stmt| eval_while_statement(while_stmt, env, allocator),
        // .For => |for_stmt| eval_for_statement(for_stmt, env, allocator),
        // .TryCatch => |tc_stmt| eval_try_catch_statement(tc_stmt, env, allocator),
        // .Throw => |throw_stmt| eval_throw_statement(throw_stmt, env, allocator),
    };
}

fn eval_expression_statement(expr_stmt: ast.ExpressionStatement, env: *Environment, allocator: Allocator) !*Object {
    // The result of an expression statement is usually discarded, but we evaluate it.
    // The returned object here will be deallocated by eval_statements loop.
    return eval_expression(expr_stmt.expression, env, allocator);
}

fn eval_variable_declaration_statement(
    var_decl_stmt: ast.VariableDeclarationStatement,
    env: *Environment,
    allocator: Allocator,
) !*Object {
    var value_obj: *Object = undefined;
    if (var_decl_stmt.value) |expr_val| {
        value_obj = try eval_expression(expr_val, env, allocator);
        if (value_obj.type == .Error) {
            return value_obj; // Propagate error
        }
    } else {
        // This case should ideally not happen if parser enforces initialization.
        // Or, if uninitialized variables are allowed and default to 'null'.
        // For now, assume parser ensures 'value' is present or this is an error.
        // Let's create a NULL for now if no value.
        value_obj = try allocator.create(Object);
        value_obj.* = NULL;
    }

    // Environment.declare expects an owned name if it stores it.
    // The AST node's name.value is a slice of the source.
    // Environment.declare will dupe it.
    _ = try env.declare(var_decl_stmt.name.value, value_obj, var_decl_stmt.is_mutable);

    // Variable declaration itself doesn't yield a value in most languages. Return NULL.
    // The 'value_obj' is now owned by the environment.
    var res_null = try allocator.create(Object);
    res_null.* = NULL;
    return res_null;
}

fn eval_return_statement(ret_stmt: ast.ReturnStatement, env: *Environment, allocator: Allocator) !*Object {
    var val: *Object = undefined;
    if (ret_stmt.return_value) |ret_expr| {
        val = try eval_expression(ret_expr, env, allocator);
        if (val.type == .Error) {
            return val; // Propagate error
        }
    } else {
        // Return without a value, effectively 'gjevTilbake null'
        val = try allocator.create(Object);
        val.* = NULL;
    }

    // Wrap the value in a ReturnValue object
    var return_wrapper = try allocator.create(Object);
    return_wrapper.* = Object{ .ReturnValue = .{ .value = val } };
    return return_wrapper;
}


fn eval_block_statement(block: ast.BlockStatement, env: *Environment, allocator: Allocator) !*Object {
    // Create a new enclosed environment for the block if needed (e.g. for functions, loops with new vars)
    // For a simple block, it might inherit the current environment directly or create one depending on scoping rules.
    // Let's assume for now simple blocks don't create a new scope unless they are function bodies.
    // For function bodies, a newEnclosed environment would be created before calling this.
    return eval_statements(block.statements.items, env, allocator);
}


fn eval_expression(expression_union: ast.Expression, env: *Environment, allocator: Allocator) !*Object {
    // Create a new object on the heap for the expression's result
    var result_obj = try allocator.create(Object);

    switch (expression_union) {
        .NumberLiteral => |lit| result_obj.* = Object{ .Integer = .{ .value = lit.value } },
        .StringLiteral => |lit| {
            // The evaluator needs to own the string if it's to be stored in the env or returned
            const owned_string = try allocator.dupe(u8, lit.value);
            errdefer allocator.free(owned_string); // if creating StringObj fails
            result_obj.* = Object{ .StringObj = .{ .value = owned_string } };
        },
        .Boolean => |lit| result_obj.* = if (lit.value) TRUE else FALSE, // Use singletons
        .Identifier => |ident_expr| {
            allocator.destroy(result_obj); // We won't use this allocated obj, will return from env or new error
            return eval_identifier(ident_expr, env, allocator);
        },
        // TODO: Add other expression types
        // .Prefix => |pref_expr| eval_prefix_expression(pref_expr, env, allocator),
        // .Infix => |inf_expr| eval_infix_expression(inf_expr, env, allocator),
        // .If => |if_expr| eval_if_expression(if_expr, env, allocator),
        // .FunctionLiteral => |fn_lit| ...,
        // .Call => |call_expr| ...,
        // .ListLiteral => |list_lit| ...,
        else => {
            // Fallback for unhandled expressions: create an error object
            allocator.destroy(result_obj); // Don't need the one we allocated
            const err_msg = try std.fmt.allocPrint(allocator, "Ukjend uttrykkstype: {s}", .{@tagName(expression_union)});
            var err_obj = try allocator.create(Object);
            err_obj.* = Object{ .Error = .{ .message = err_msg } };
            return err_obj;
        }
    }
    return result_obj;
}

fn eval_identifier(ident_node: ast.Identifier, env: *Environment, allocator: Allocator) !*Object {
    if (env.get(ident_node.value)) |val_ptr| {
        // Identifiers resolve to values. These values are owned by the environment.
        // If this value is to be used in a new object (e.g. part of an infix op), it needs to be "copied"
        // or the new object needs to take co-ownership or be very careful about lifetimes.
        // For now, returning the pointer from env. This is fine if it's immediately used or wrapped.
        // If it's a string, number, bool from env, it's okay. If it's a function, also okay.
        // The problem comes if we return it and the env is destroyed.
        // However, for an identifier, we are just "looking up" its value. The caller of eval_identifier
        // will decide what to do with it (e.g., wrap in ReturnValue, use in operation).
        // Let's assume the result of eval_identifier does not need to be separately allocated *again* here.
        // It's a reference to an object already managed by the environment or a singleton.
        return val_ptr;
    } else {
        // Create an error object if identifier not found
        const err_msg = try std.fmt.allocPrint(allocator, "Identifikator ikkje funnen: {s}", .{ident_node.value});
        var err_obj = try allocator.create(Object);
        err_obj.* = Object{ .Error = .{ .message = err_msg } };
        return err_obj;
    }
}

// --- Helper to create error objects ---
pub fn newError(allocator: Allocator, comptime format: []const u8, args: anytype) !*Object {
    const msg = std.fmt.allocPrint(allocator, format, args) catch |err| {
        // Fallback if formatting/allocating the error message fails
        const fallback_msg = try allocator.dupe(u8, "Internal error: Failed to create error message.");
        var fb_err_obj = try allocator.create(Object);
        fb_err_obj.* = Object{ .Error = .{ .message = fallback_msg } };
        return fb_err_obj;
    };
    var err_obj = try allocator.create(Object);
    err_obj.* = Object{ .Error = .{ .message = msg } };
    return err_obj;
}


// --- Tests ---
// We need the parser to be more complete to write meaningful evaluator tests.
// For now, a simple test for literals.

fn testEval(input: []const u8, allocator: Allocator) !*Object {
    var lexer = ast.token.Lexer.init(input);
    var parser = ast.Parser.init(lexer, allocator);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit(); // Deinit AST

    if (parser.getErrors().items.len != 0) {
        std.debug.print("Parser errors during testEval for input: {s}\n", .{input});
        for (parser.getErrors().items) |err_str| {
            std.debug.print("- {s}\n", .{err_str});
        }
        return newError(allocator, "Parser error during testEval", .{});
    }

    var env = Environment.init(allocator);
    defer env.deinit();

    return eval(ast.Node{ .Program = program }, &env, allocator);
}

test "Evaluator: Number Literal" {
    const input = "5;"; // Parser needs ExpressionStatement parsing
    // This test will fail until ExpressionStatement is parsed and evaluated correctly.
    // For now, we can't easily test direct expression evaluation without a Program/Statement wrapper.
    // Let's assume the parser will be updated to handle this.
    // If we modify the parser to produce an ExpressionStatement for "5;", then this can work.

    // To make this testable now, let's assume a direct ast.Expression input
    const num_lit_token = ast.token.Token.init(ast.token.TokenType.Num, "5");
    const num_lit_ast = ast.Expression.NumberLiteral = .{ .token = num_lit_token, .value = 5 };

    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    const result = try eval_expression(num_lit_ast, &env, std.testing.allocator);
    defer result.deinit(std.testing.allocator); // deinit contents
    defer std.testing.allocator.destroy(result); // destroy pointer

    try std.testing.expectEqual(object.ObjectType.Integer, result.type);
    try std.testing.expectEqual(@as(i64, 5), result.Integer.value);
}

test "Evaluator: Boolean Literals" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator); // Dummy env
    defer env.deinit();

    const true_lit_token = ast.token.Token.init(ast.token.TokenType.Sant, "sant");
    const true_lit_ast = ast.Expression.Boolean = .{ .token = true_lit_token, .value = true };
    var result = try eval_expression(true_lit_ast, &env, allocator);
    // Booleans are singletons, no deinit/destroy needed for the result pointer itself if it's TRUE/FALSE
    try std.testing.expectEqual(object.ObjectType.Boolean, result.type);
    try std.testing.expect(result.Boolean.value);
    try std.testing.expect(result == &TRUE);


    const false_lit_token = ast.token.Token.init(ast.token.TokenType.Usant, "usant");
    const false_lit_ast = ast.Expression.Boolean = .{ .token = false_lit_token, .value = false };
    result = try eval_expression(false_lit_ast, &env, allocator);
    try std.testing.expectEqual(object.ObjectType.Boolean, result.type);
    try std.testing.expect(!result.Boolean.value);
    try std.testing.expect(result == &FALSE);
}

// More tests will be added as parser and evaluator capabilities grow (e.g., for variable declarations, expressions)
// test "Evaluator: Variable Declaration" { ... }
// test "Evaluator: Identifier Lookup" { ... }
// test "Evaluator: Return Statement" { ... }
// test "Evaluator: Error Handling" { ... }

// Placeholder for actual program evaluation tests once parser is more complete
/*
test "Evaluator: Simple Program with Var Decl and Ident" {
    const input =
        \\fast x er 10;
        \\x; // This would be an expression statement
    ;
    const allocator = std.testing.allocator;
    const result_obj = try testEval(input, allocator);
    // For 'x;' the result should be Integer{10}
    // Need to handle deallocation of result_obj carefully
    defer if (result_obj != &object.TRUE and result_obj != &object.FALSE and result_obj != &object.NULL) {
        result_obj.deinit(allocator);
        allocator.destroy(result_obj);
    };

    try std.testing.expectEqual(object.ObjectType.Integer, result_obj.type);
    try std.testing.expectEqual(@as(i64, 10), result_obj.Integer.value);
}
*/
