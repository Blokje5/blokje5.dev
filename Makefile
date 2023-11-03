.PHONY: init
init:
	git submodule update

local:
	hugo server --config hugo.toml