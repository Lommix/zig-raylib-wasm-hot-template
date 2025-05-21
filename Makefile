run:
	zig build run -fincremental

web:
	zig build -Dtarget=wasm32-emscripten run --sysroot "Dummy"

build:
	zig build hot
