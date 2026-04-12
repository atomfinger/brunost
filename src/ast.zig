const std = @import("std");

pub const Node = union(enum) {
    // Statements
    program: Program,
    var_decl: VarDecl,
    assign_stmt: AssignStmt,
    return_stmt: ReturnStmt,
    expr_stmt: ExprStmt,
    block: Block,
    if_stmt: IfStmt,
    while_stmt: WhileStmt,
    foreach_stmt: ForeachStmt,
    try_stmt: TryStmt,
    throw_stmt: ThrowStmt,
    fn_decl: FnDecl,
    import_stmt: ImportStmt,
    module_decl: ModuleDecl,
    // Expressions
    integer_lit: IntegerLit,
    float_lit: FloatLit,
    string_lit: StringLit,
    bool_lit: BoolLit,
    list_lit: ListLit,
    identifier: Identifier,
    infix_expr: InfixExpr,
    prefix_expr: PrefixExpr,
    call_expr: CallExpr,
    member_call: MemberCall,
};

pub const Program = struct {
    statements: []*Node,
};

pub const VarDecl = struct {
    mutable: bool,
    name: []const u8,
    value: *Node,
};

pub const AssignStmt = struct {
    name: []const u8,
    value: *Node,
};

pub const ReturnStmt = struct {
    value: *Node,
};

pub const ExprStmt = struct {
    expr: *Node,
};

pub const Block = struct {
    statements: []*Node,
};

pub const IfStmt = struct {
    condition: *Node,
    consequence: *Node, // Block
    /// Either another IfStmt (else-if chain) or a Block (plain else), or null
    alternative: ?*Node,
};

pub const WhileStmt = struct {
    condition: *Node,
    body: *Node, // Block
};

pub const ForeachStmt = struct {
    iterator_name: []const u8,
    iterable: *Node,
    body: *Node, // Block
};

pub const TryStmt = struct {
    body: *Node, // Block
    error_name: []const u8,
    catch_body: *Node, // Block
};

pub const ThrowStmt = struct {
    value: *Node,
};

pub const FnDecl = struct {
    name: []const u8,
    params: [][]const u8,
    body: *Node, // Block
};

pub const IntegerLit = struct {
    value: i64,
};

pub const FloatLit = struct {
    value: f64,
};

pub const StringLit = struct {
    value: []const u8,
};

pub const BoolLit = struct {
    value: bool,
};

pub const ListLit = struct {
    elements: []*Node,
};

pub const Identifier = struct {
    name: []const u8,
};

pub const InfixExpr = struct {
    op: []const u8,
    left: *Node,
    right: *Node,
};

pub const PrefixExpr = struct {
    op: []const u8,
    right: *Node,
};

pub const CallExpr = struct {
    callee: *Node, // Identifier
    args: []*Node,
};

/// terminal.skriv(...) and similar member calls
pub const MemberCall = struct {
    object: []const u8,
    member: []const u8,
    args: []*Node,
};

/// bruk ekstra.noe (som noko)
pub const ImportStmt = struct {
    segments: [][]const u8,
    alias: ?[]const u8,
};

/// modul name { gjer ... }
pub const ModuleDecl = struct {
    name: []const u8,
    functions: []*Node,
};
