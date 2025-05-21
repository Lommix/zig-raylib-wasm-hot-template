const rl = @import("raylib");
const std = @import("std");

const LIB_PATH = "./zig-out/lib/libgame.so";
const LIB_DIR = "./hot";

// ---------------------
// your game dll/so
var lib: ?std.DynLib = null;
var state: *anyopaque = undefined;
var current_state_size = usize;
var force_reload = false;

// extern
var init: *const fn (allocator: *std.mem.Allocator) callconv(.C) *anyopaque = undefined;
var update: *const fn (state: *anyopaque) callconv(.C) void = undefined;
var reload: *const fn (state: *anyopaque) callconv(.C) void = undefined;
var stateSize: *const fn () callconv(.C) usize = undefined;
var last_mod: i128 = 0;
var file_name: ?[]u8 = null;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    var allocator = arena.allocator();

    rl.initWindow(640, 320, "raylib-template");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    load_lib() catch unreachable;

    state = init(&allocator);

    while (!rl.windowShouldClose()) {
        update(state);

        if (rl.isKeyPressed(.f5)) force_reload = true;

        watch(&arena, &allocator) catch |err| {
            std.debug.print("reload failed with: {any}", .{err});
        };
    }

    rl.closeWindow();
    arena.deinit();
}

fn load_lib() !void {
    file_name = try std.fmt.allocPrint(std.heap.c_allocator, "{s}/libgame_{d}.so", .{ LIB_DIR, std.time.milliTimestamp() });
    std.debug.print("from {s} to {s}", .{ LIB_PATH, file_name.? });

    try std.fs.cwd().copyFile(LIB_PATH, std.fs.cwd(), file_name.?, .{});

    const stat = try std.fs.cwd().statFile(LIB_PATH);
    std.debug.print("{s}", .{file_name.?});

    lib = try std.DynLib.open(file_name.?);
    last_mod = stat.mtime;
    init = lib.?.lookup(@TypeOf(init), "init").?;
    update = lib.?.lookup(@TypeOf(update), "update").?;
    reload = lib.?.lookup(@TypeOf(reload), "reload").?;
    stateSize = lib.?.lookup(@TypeOf(stateSize), "stateSize").?;
}

fn watch(arena: *std.heap.ArenaAllocator, allocator: *std.mem.Allocator) !void {
    if (try fileChanged() or force_reload) {
        std.debug.print("change detected, reloading code...\n", .{});

        const old_mem = stateSize();

        try unload_lib();
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

fn fileChanged() !bool {
    const stats = try std.fs.cwd().statFile(LIB_PATH);
    return stats.mtime > last_mod;
}

fn unload_lib() !void {
    lib.?.close();
    lib = null;
    try std.fs.cwd().deleteFile(file_name.?);
    std.heap.c_allocator.free(file_name.?);
}
