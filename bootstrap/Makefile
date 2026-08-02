PREFIX ?= $(HOME)/.local/bin

.PHONY: build install plan clean

build:
	go build -o setup .

# Where the bootstrap one-liner points; ~/.local/bin is already on PATH.
#
# `theme` is the same binary under another name — main() dispatches on argv[0],
# so the switcher and the installer ship as one artefact. Quickshell's
# ThemeState.qml execs `theme data`, so the symlink has to be on PATH.
install:
	go build -o $(PREFIX)/setup .
	ln -sfn setup $(PREFIX)/theme
	@echo "installed $(PREFIX)/setup and the $(PREFIX)/theme symlink"

# Report what a run would do, without changing anything.
plan: build
	./setup -plan

clean:
	rm -f setup
