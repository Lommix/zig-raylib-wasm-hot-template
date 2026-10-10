run:
	zig build run

web:
	zig build -Dtarget=wasm32-emscripten web

hot:
	zig build hot

watch:
	zig build hot --watch
