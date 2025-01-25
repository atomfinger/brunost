pub fn parse(
    source: [:0]const u8,
    filename: [:0]const u8,
    allocator: std.mem.Allocator,
) ![]const u8 {
    //TODO: Search for modules where the file is located
    //
}

const std = @import("std");
const Brunost_Parser = @This();
