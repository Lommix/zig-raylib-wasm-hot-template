#!/bin/bash

make build

function watch_code(){
	while true; do
	  inotifywait -r -e modify,create,delete --format "%f" src && make build
	  echo "compiled zig"
	done
}


pid1= watch_code &

wait
trap "kill $pid1"

