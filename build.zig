const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "brunost",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // WASM build — run with: zig build wasm
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const wasm_mod = b.createModule(.{
        .root_source_file = b.path("src/wasm.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    const wasm_exe = b.addExecutable(.{
        .name = "brunost",
        .root_module = wasm_mod,
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;
    const wasm_install = b.addInstallArtifact(wasm_exe, .{
        .dest_dir = .{ .override = .{ .custom = "wasm" } },
    });
    const wasm_step = b.step("wasm", "Build WebAssembly target (zig-out/wasm/brunost.wasm)");
    wasm_step.dependOn(&wasm_install.step);

    const test_step = b.step("test", "Run unit tests");

    const interp_test_mod = b.createModule(.{
        .root_source_file = b.path("src/interpreter_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const interp_tests = b.addTest(.{
        .root_module = interp_test_mod,
    });
    test_step.dependOn(&b.addRunArtifact(interp_tests).step);
}
