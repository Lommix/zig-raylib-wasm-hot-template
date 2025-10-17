const std = @import("std");
const rlz = @import("raylib_zig");

const Context = struct {
    raylib: *std.Build.Module,
    raygui: *std.Build.Module,
    raylib_artifact: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .linkage = .dynamic,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const context = Context{
        .raylib = raylib,
        .raygui = raygui,
        .raylib_artifact = raylib_artifact,
        .optimize = optimize,
        .target = target,
    };

    try build_hot(b, context);

    if (target.query.os_tag == .emscripten) {
        try build_web(b, context);
    } else {
        try build_native(b, context);
    }
}

fn build_native(
    b: *std.Build,
    ctx: Context,
) !void {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main_hot.zig"), // swap to main_release for release
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libc = true,
    });

    exe_mod.addImport("raylib", ctx.raylib);
    exe_mod.addImport("raygui", ctx.raygui);

    const exe = b.addExecutable(.{
        .name = "lommix_demo",
        .root_module = exe_mod,
    });

    exe.linkLibrary(ctx.raylib_artifact);
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn build_web(
    b: *std.Build,
    ctx: Context,
) !void {
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .linkage = .static,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main_release.zig"),
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libc = false,
    });

    mod.linkLibrary(raylib_artifact);
    mod.addImport("raylib", raylib);
    mod.addImport("raygui", raygui);

    const emsdk = rlz.emsdk;
    const wasm = b.addLibrary(.{
        .name = "village-game",
        .root_module = mod,
        .linkage = .static,
    });

    const install_dir: std.Build.InstallDir = .{ .custom = "web" };
    const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = ctx.optimize });
    const emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = ctx.optimize });

    const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
        .optimize = ctx.optimize,
        .flags = emcc_flags,
        .settings = emcc_settings,
        .install_dir = install_dir,
    });

    b.getInstallStep().dependOn(emcc_step);

    const html_filename = try std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name});
    const emrun_step = emsdk.emrunStep(b, b.getInstallPath(install_dir, html_filename), &.{});
    emrun_step.dependOn(emcc_step);

    const web_step = b.step("web", "web");
    web_step.dependOn(emrun_step);
}

fn build_hot(
    b: *std.Build,
    ctx: Context,
) !void {
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "game",
        .root_module = b.createModule(.{
            .target = ctx.target,
            .optimize = ctx.optimize,
            .root_source_file = b.path("src/game.zig"),
            .imports = &.{
                .{ .name = "raylib", .module = ctx.raylib },
                .{ .name = "raygui", .module = ctx.raygui },
            },
        }),
    });

    lib.linkLibrary(ctx.raylib_artifact);
    const lib_install = b.addInstallArtifact(lib, .{});
    const step = b.step("hot", "build lib");
    step.dependOn(&lib_install.step);
}
