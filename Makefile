# Makefile for tcslog-tools

# Run every recipe under bash with pipefail, so a failing stage in the
# middle of a pipeline is not hidden by a succeeding last stage.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Portable command abstractions (override per-OS as needed)
RM      := rm -f
RMDIR   := rm -rf

# The binaries this crate produces, which is also what install and
# uninstall move in and out of $(PREFIX)/bin.
BINS := tcslog-dump tcslog-dumphdr

# Display help. Every entry is the `##` comment on the target's own
# rule, so the list cannot drift from the set of targets that exist.
# This is also the default target.
.PHONY: help
help:				## Show this help
	@echo "Makefile for tcslog-tools"
	@echo ""
	@echo "Usage:"
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| sed 's/:.*## /|/' \
		| awk -F'|' '{printf "  make %-14s - %s\n", $$1, $$2}'

.PHONY: test
test:				## Run all tests
	@echo "Running tests..."
	cargo test
	@echo "[OK] Tests complete"

.PHONY: clean
clean:				## Remove build artifacts
	@echo "Cleaning build artifacts..."
	-cargo clean
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
install:			## Install the binaries globally
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

# Create release build.
.PHONY: release
release: test			## Build with optimizations into target/release
	@echo "Creating release build..."
	cargo build --release
	@echo "[OK] Release binaries are in target/release/"
