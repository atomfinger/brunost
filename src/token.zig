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
            .{ "sant", .true_op },
            .{ "usant", .false_op },
            .{ "viss", .if_op },
            .{ "ellers", .else_op },
            .{ "gjevTilbake", .return_op },
        });
        return map.get(identifier);
    }
};

//insp: https://github.com/heldrida/interpreter-in-zig/blob/main/src/token.zig
// https://github.com/aryanrsuri/zigterpreter/blob/master/src/lexer.zig

pub const token_types = enum {
    nul,
    eof,

    function,
    let_mutable,
    let_immutable,
    return_op,
    if_op,
    true,
    false,
    else_op,
};
