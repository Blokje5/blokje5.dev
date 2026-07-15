.PHONY: init local

init:
	git submodule update --init --recursive

local:
	hugo server --config hugo.toml
