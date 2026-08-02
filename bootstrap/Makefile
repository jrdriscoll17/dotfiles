PREFIX ?= $(HOME)/.local/bin

.PHONY: build install plan clean

build:
	go build -o setup .

# Where the bootstrap one-liner points; ~/.local/bin is already on PATH.
install:
	go build -o $(PREFIX)/setup .
	@echo "installed $(PREFIX)/setup"

# Report what a run would do, without changing anything.
plan: build
	./setup -plan

clean:
	rm -f setup
