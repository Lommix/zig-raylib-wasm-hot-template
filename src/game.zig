const std = @import("std");
const rl = @import("raylib");

pub const GameState = struct {
    version: i32 = 0,
};

pub export fn init(allocator: *std.mem.Allocator) callconv(.C) *anyopaque {
    const state = allocator.create(GameState) catch unreachable;
    state.* = GameState{};
    return state;
}

pub export fn deinit(allocator: *std.mem.Allocator, state: *GameState) callconv(.C) void {
    allocator.destroy(state);
}

pub export fn update(state: *GameState) callconv(.C) void {
    _ = state;

    rl.beginDrawing();
    rl.clearBackground(rl.Color.sky_blue);
    rl.drawText("Hello WORD!", 20, 20, 32, .black);
    rl.endDrawing();
}

pub export fn reload(state: *GameState) callconv(.C) void {
    _ = state;
}

pub export fn stateSize() callconv(.C) usize {
    return @sizeOf(GameState);
}
