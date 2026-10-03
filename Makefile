# Makefile for tcslog-tools

# Run every recipe under bash with pipefail. Without it, the exit
# status of a pipeline is the status of its last stage, so a failing
# `cargo build ... | tee build.out` would report success and `make
# install` would happily install a stale binary.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Portable command abstractions (override per-OS as needed)
RM      := rm -f
RMDIR   := rm -rf

# Extra flags for `cargo build`; `make release` sets it to --release.
RELEASE =

# The binaries this crate produces, which is also what install and
# uninstall move in and out of $(PREFIX)/bin.
BINS := tcslog-dump tcslog-dumphdr

# Default target
.PHONY: all
all: build			## Build the tools (default target)

# Display help. Every entry is the `##` comment on the target's own
# rule, so the list cannot drift from the set of targets that exist.
.PHONY: help
help:				## Show this help
	@echo "Makefile for tcslog-tools"
	@echo ""
	@echo "Usage:"
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| sed 's/:.*## /|/' \
		| awk -F'|' '{printf "  make %-14s - %s\n", $$1, $$2}'

.PHONY: build
build:				## Build the tools
	( \
		echo "Building the tools..."; \
		cargo build $(RELEASE); \
		echo "[OK] Build complete"; \
	) 2>&1 | tee build.out

.PHONY: test
test:				## Run all tests
	@echo "Running tests..."
	cargo test
	@echo "[OK] Tests complete"

.PHONY: clean
clean:				## Remove build artifacts
	@echo "Cleaning build artifacts..."
	-cargo clean
	$(RM) build.out
	@echo "[OK] Clean complete"

.PHONY: distclean
distclean: clean		## Remove build artifacts and all generated files
	@echo "Removing all generated files..."
	$(RMDIR) target
	@echo "[OK] Project reset"

# Install binaries. Defaults to $HOME; override PREFIX for other locations,
# and DESTDIR for staged installs (packaging).
PREFIX  ?= $(HOME)
DESTDIR ?=

.PHONY: install
install: build			## Install the binaries globally
	@echo "Installing $(BINS) to $(DESTDIR)$(PREFIX)/bin..."
	cargo install --path . --root $(DESTDIR)$(PREFIX)
	@echo "[OK] Installed to $(DESTDIR)$(PREFIX)/bin/"

# Uninstall binaries from the same location `install` uses.
.PHONY: uninstall
uninstall:			## Remove installed binaries
	@echo "Removing $(BINS) from $(DESTDIR)$(PREFIX)/bin..."
	$(RM) $(addprefix $(DESTDIR)$(PREFIX)/bin/,$(BINS))
	@echo "[OK] Uninstalled from $(DESTDIR)$(PREFIX)/bin/"

.PHONY: check
check:				## Run cargo check, clippy, and fmt --check
	@echo "Running cargo check..."
	cargo check --all-targets
	cargo clippy --all-targets -- -D warnings
	cargo fmt -- --check

.PHONY: format
format:				## Format the code with cargo fmt
	cargo fmt

# Create release build. Reuses `build` so there is one build path.
.PHONY: release
release: test			## Build with optimizations into target/release
	@echo "Creating release build..."
	$(MAKE) build RELEASE=--release
	@echo "[OK] Release binaries are in target/release/"
