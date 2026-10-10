# Zig + Raylib WASM Hot Reload Template

A template for building games with Zig and Raylib that can run both natively and in the browser via WebAssembly, with hot reload support for development (only on desktop).

## Features

- Native desktop builds
- WebAssembly builds for browser deployment
- Hot reload for rapid development
- Raylib integration with raygui support

## Prerequisites

- Zig 0.17.0
- Make (optional, for convenience commands)

## Development Environment

This project requires Zig 0.17.0. The nix flake provides the toolchain:

```bash
nix develop
zig build run
```

Native builds link against the system GL/X11 development libraries (Arch: `mesa` `libx11` `libxrandr` `libxinerama` `libxi` `libxcursor`); the flake provides only the Zig toolchain.

## Quick Start

### Native Development

```bash
make run
# or
zig build run
```

While running, you can edit the source files. Then run the following command to hot reload the game without restarting:

```bash
make hot
# or
zig build hot -fincremental
```

### Web Development

This will create a release build, that will not include the hot reload functionality.

```bash
make web
# or
zig build -Dtarget=wasm32-emscripten web
```

## Project Structure

- `src/game.zig` - Main game logic with hot reload exports
- `src/main_hot.zig` - Hot reload entry point for development
- `src/main_release.zig` - Release entry point for production builds
- `shell.html` - HTML template for web builds
- `res/` - Resource directory, preloaded into web builds

## Hot Reload

The hot reload system allows you to modify game code and see changes instantly without restarting. The game state persists across reloads.

## Web Deployment

Web builds use Emscripten to compile to WebAssembly. The `res/` directory is preloaded into the web build by default, producing `zig-out/web/village-game.data`.
