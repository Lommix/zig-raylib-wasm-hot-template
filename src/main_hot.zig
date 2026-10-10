const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

const LIB_PATH = "./zig-out/lib/";
const LIB_FILENAME = "libgame";
const LIB_DIR = "./hot";

// ---------------------
// your game dll/so
var lib: ?std.DynLib = null;
var state: *anyopaque = undefined;
var current_state_size = usize;
var force_reload = false;

// extern
var init: *const fn (allocator: *std.mem.Allocator) callconv(.c) *anyopaque = undefined;
var update: *const fn (state: *anyopaque) callconv(.c) void = undefined;
var reload: *const fn (state: *anyopaque) callconv(.c) void = undefined;
var stateSize: *const fn () callconv(.c) usize = undefined;
var last_mod: std.Io.Timestamp = .zero;
var hot_lib_path: ?[]u8 = null;
var running_lib_path: ?[]const u8 = null;

const io = std.Io.Threaded.global_single_threaded.io();

pub fn main() !void {
    try update_running_lib_path();
    try update_hot_lib_path();
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    var allocator = arena.allocator();
    rl.initWindow(640, 320, "raylib-template");
    defer if (rl.isWindowReady()) rl.closeWindow();
    rl.setTargetFPS(60);

    load_lib() catch unreachable;

    state = init(&allocator);

    while (!rl.windowShouldClose()) {
        update(state);

        if (rl.isKeyPressed(.f5)) force_reload = true;

        watch(&arena, &allocator) catch |err| {
            std.debug.print("reload failed with: {any}\n", .{err});
        };
    }

    arena.deinit();
}

fn load_lib() !void {
    std.debug.print("from {s} to {s}\n", .{ running_lib_path.?, hot_lib_path.? });

    const cwd = std.Io.Dir.cwd();
    try cwd.copyFile(running_lib_path.?, cwd, hot_lib_path.?, io, .{});

    const stat = cwd.statFile(io, running_lib_path.?, .{}) catch |err| {
        std.debug.print("error checking file exists {s}: {}\n", .{ running_lib_path.?, err });
        return err;
    };

    lib = try std.DynLib.open(hot_lib_path.?);
    last_mod = stat.mtime;
    init = lib.?.lookup(@TypeOf(init), "init").?;
    update = lib.?.lookup(@TypeOf(update), "update").?;
    reload = lib.?.lookup(@TypeOf(reload), "reload").?;
    stateSize = lib.?.lookup(@TypeOf(stateSize), "stateSize").?;
}

fn watch(arena: *std.heap.ArenaAllocator, allocator: *std.mem.Allocator) !void {
    if (try file_changed() or force_reload) {
        std.debug.print("change detected, reloading code...\n", .{});

        const old_mem = stateSize();
        try unload_lib();
        try update_hot_lib_path();
        try load_lib();

        if (old_mem != stateSize() or force_reload) {
            std.debug.print("\nmemory layout for game state has changed, reinitializing the game...\n", .{});
            _ = arena.reset(.retain_capacity);
            allocator.* = arena.allocator();
            state = init(allocator);
        } else {
            reload(state);
        }

        std.debug.print("\n|-[reloaded]-|\n", .{});
        force_reload = false;
    }
}

fn get_lib_ext() ![]const u8 {
    return if (builtin.os.tag == .windows) "dll" else if (builtin.os.tag == .linux) "so" else "dylib";
}

fn update_hot_lib_path() !void {
    const ext = try get_lib_ext();
    const now = std.Io.Clock.real.now(io).nanoseconds;
    hot_lib_path = try std.heap.c_allocator.print("{s}/libgame_{d}.{s}", .{ LIB_DIR, now, ext });
}

fn update_running_lib_path() !void {
    const ext = try get_lib_ext();
    running_lib_path = try std.heap.c_allocator.print("{s}{s}.{s}", .{ LIB_PATH, LIB_FILENAME, ext });
}

fn file_changed() !bool {
    const stats = std.Io.Dir.cwd().statFile(io, running_lib_path.?, .{}) catch |err| {
        std.debug.print("error checking file changed {s}: {}\n", .{ running_lib_path.?, err });
        return err;
    };
    return stats.mtime.nanoseconds > last_mod.nanoseconds;
}

fn unload_lib() !void {
    lib.?.close();
    lib = null;
    std.Io.Dir.cwd().deleteFile(io, hot_lib_path.?) catch |err| {
        std.debug.print("error deleting file {s}: {}\n", .{ hot_lib_path.?, err });
        return err;
    };
    std.heap.c_allocator.free(hot_lib_path.?);
}
