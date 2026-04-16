const std = @import("std");
const main = @import("main.zig");
const matte = @import("stdlib/matte.zig");

// Source scratch buffer — JS writes brunost code here before calling evaluate().
var source_buf: [512 * 1024]u8 = undefined;

// Output buffer — Zig writes interpreter output here; JS reads it after evaluate().
var output_buf: [1024 * 1024]u8 = undefined;
var output_len: usize = 0;
var output_is_error: bool = false;

/// Returns a pointer to the scratch buffer where JS should write the source code.
export fn get_source_buf_ptr() [*]u8 {
    return &source_buf;
}

/// Returns the capacity of the source scratch buffer in bytes.
export fn get_source_buf_len() usize {
    return source_buf.len;
}

/// Returns a pointer to the output buffer. Read after calling evaluate().
export fn get_output_ptr() [*]const u8 {
    return &output_buf;
}

/// Returns the number of bytes written to the output buffer by the last evaluate() call.
export fn get_output_len() usize {
    return output_len;
}

/// Returns 1 if the last evaluate() call produced an error, 0 if it succeeded.
export fn get_output_is_error() i32 {
    return if (output_is_error) 1 else 0;
}

/// Seed the PRNG used by matte.tilfeldig(). Call this with entropy from JS
/// (e.g. crypto.getRandomValues) before running scripts that use tilfeldig().
export fn seed_prng(seed: u64) void {
    matte.seed_prng(seed);
}

/// Evaluate brunost source code. Write the source into get_source_buf_ptr() first,
/// then call evaluate(ptr, len). Read results via get_output_ptr() / get_output_len().
export fn evaluate(source_ptr: [*]const u8, source_len: usize) void {
    output_len = 0;
    output_is_error = false;

    var aw: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer aw.deinit();

    const source = source_ptr[0..source_len];

    main.run(std.heap.page_allocator, source, &aw.writer, "") catch |err| {
        output_is_error = true;
        aw.deinit();
        aw = .init(std.heap.page_allocator);
        aw.writer.writeAll(main.describe_error(err)) catch {};
    };

    const written = aw.writer.buffered();
    const copy_len = @min(written.len, output_buf.len);
    @memcpy(output_buf[0..copy_len], written[0..copy_len]);
    output_len = copy_len;
}
