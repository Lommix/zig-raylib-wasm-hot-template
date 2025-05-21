run:
	zig build run -fincremental

web:
	zig build -Dtarget=wasm32-emscripten run --sysroot "NeedsToBeHereButGetsOverwritten"

build:
	zig build hot -fincremental
