const rl = @import("raylib");
const std = @import("std");
const game = @import("game.zig");

pub fn main() !void {
    rl.initWindow(640, 320, "test");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var allocator = std.heap.c_allocator;
    const state: *game.GameState = @ptrCast(@alignCast(game.init(&allocator)));

    while (!rl.windowShouldClose()) {
        game.update(state);
    }

    game.deinit(&allocator, state);
}
