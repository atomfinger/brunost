const std = @import("std");
const brunost_parser = @import("Brunost_Parser.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

pub fn runFile(
    allocator: std.mem.Allocator,
    file_name: [:0]const u8,
) !void {
    const source_file = try std.fs.cwd().openFile(file_name, .{ .lock = .exclusive });
    defer source_file.close();
    const source_file_size = (try source_file.stat()).size;
    const source = try source_file.readToEndAllocOptions(
        allocator,
        source_file_size,
        null,
        @alignOf(u8),
        0,
    );
    defer allocator.free(source);
    brunost_parser.parse(source, file_name, allocator);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
