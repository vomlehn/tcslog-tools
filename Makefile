# Makefile for tcslog-tools

# Run every recipe under bash with pipefail, so a failing stage in the
# middle of a pipeline is not hidden by a succeeding last stage.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Portable command abstractions (override per-OS as needed)
RM      := rm -f
RMDIR   := rm -rf

# The binaries this crate produces, which is also what install-files and
# uninstall-files move in and out of $(PREFIX)/bin, and what tcslog-tools-links
# links into /usr/local/bin, written into it as it is installed, so that
# it never touches another TCS package's programs in the same bin.
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
		| awk -F'|' '{printf "  make %-15s - %s\n", $$1, $$2}'

.PHONY: test
test:				## Run all tests
	@echo "Running tests..."
	cargo test
	@echo "[OK] Tests complete"

.PHONY: clean
clean:				## Remove build artifacts
	@echo "Cleaning build artifacts..."
	-cargo clean
	$(RMDIR) build
	@echo "[OK] Clean complete"

.PHONY: distclean
distclean: clean		## Remove build artifacts and generated files
	@echo "Removing all generated files..."
	$(RMDIR) target
	@echo "[OK] Project reset"

# The version, from Cargo.toml's [package] table, which the packages
# take; the tcslog dependency's table has a version line of its own.
VERSION := $(shell sed -n '/^\[package\]/,/^\[/s/^version = "\(.*\)"/\1/p' \
	Cargo.toml)

# Where `make install-files` puts everything: /opt/tcs, the tree the TCS
# packages share under FHS 3.0's /opt/<package>, so that one PATH entry
# serves them all. DESTDIR stages the install for packaging. A developer
# installing somewhere of their own sets PREFIX, such as PREFIX=$HOME.
PREFIX  ?= /opt/tcs
DESTDIR ?=
# Whether install-files also writes /etc/profile.d/tcslog-tools.sh, which puts
# /opt/tcs/bin on a login shell's PATH. Off unless asked for, so that an
# install touches nothing in /etc that its installer did not mean it
# to; `make stage` asks, the package being where it belongs. It names
# /opt/tcs, so it is refused with any other PREFIX rather than installed
# pointing at the wrong tree.
HOOKS   ?= 0
# Whether install-files strips the binaries it installs; see it below.
STRIP   ?= 1
ifeq ($(HOOKS),1)
ifneq ($(PREFIX),/opt/tcs)
$(error HOOKS=1 installs a file that names /opt/tcs; give PREFIX=/opt/tcs \
	or leave HOOKS unset)
endif
endif
# tcs-helpers, the packaging scripts the TCS projects share: a checkout
# of https://github.com/vomlehn/tcs-helpers, beside this one unless
# TCS_HELPERS names another, used where it is rather than installed.
# Installing and packaging check it first: see the tcs-helpers target.
TCS_HELPERS ?= $(abspath $(CURDIR)/../tcs-helpers)
TCS_HELPERS_REQUIRED := 0.4.0

BINDIR  := $(DESTDIR)$(PREFIX)/bin
SBINDIR := $(DESTDIR)$(PREFIX)/sbin
DOCDIR  := $(DESTDIR)$(PREFIX)/share/doc/tcslog-tools
PROFILE := $(DESTDIR)/etc/profile.d/tcslog-tools.sh
DOCS    := README.md LICENSE-APACHE LICENSE-MIT CHANGELOG.md \
	docs/tcslog-tools.html

# Stop, saying what to do, unless the tcs-helpers checkout is there and
# at least TCS_HELPERS_REQUIRED.
.PHONY: tcs-helpers
tcs-helpers:			## Check the tcs-helpers checkout
	@if [ ! -x "$(TCS_HELPERS)/bin/tcs-helpers" ]; then \
		echo "No tcs-helpers checkout at $(TCS_HELPERS): clone" \
			"https://github.com/vomlehn/tcs-helpers beside this" \
			"repository, or set TCS_HELPERS to where it is." >&2; \
		exit 1; \
	fi
	@"$(TCS_HELPERS)/bin/tcs-helpers" --require $(TCS_HELPERS_REQUIRED)

# Copy the binaries, built for release, and the documents a reader of
# the installed tree needs, into place under $(DESTDIR)$(PREFIX): what
# `make install` once did, kept for development and for `make stage`,
# which cuts the packages from it; `make install` installs the packages.
# Built with cargo build and copied, rather than with cargo install,
# which would also leave its own records of what it installed,
# .crates.toml and .crates2.json, in $(PREFIX). The library is linked in
# statically, as Rust links its dependencies, so nothing of tcslog's
# needs to be installed for these to run.
#
# Under STRIP=1, the default, the binaries are stripped of every symbol
# nothing links against as they are installed, which takes about a
# quarter off each. STRIP=0 keeps them as cargo built them, for a
# debugger.
.PHONY: install-files
install-files: docs tcs-helpers	## Build, strip (STRIP=0: don't), copy to PREFIX
	@echo "Installing tcslog-tools $(VERSION) to $(DESTDIR)$(PREFIX)..."
	cargo build --release --locked
	install -D -m 755 -t $(BINDIR) $(addprefix target/release/,$(BINS))
	install -d $(SBINDIR)
	sed -e 's|@PACKAGE@|tcslog-tools|g' -e 's|@PREFIX@|$(PREFIX)|g' \
		-e 's|@PROGRAMS@|$(BINS)|g' \
		$(TCS_HELPERS)/packaging/links.sh.in \
		> $(SBINDIR)/tcslog-tools-links
	chmod 755 $(SBINDIR)/tcslog-tools-links
	if [ "$(STRIP)" = 1 ]; then \
		strip --strip-unneeded $(addprefix $(BINDIR)/,$(BINS)); \
	fi
	install -D -m 644 -t $(DOCDIR) $(DOCS)
	if [ "$(HOOKS)" = 1 ]; then \
		install -D -m 644 packaging/hooks/tcslog-tools.sh $(PROFILE); \
	fi
	@echo "[OK] Installed under $(DESTDIR)$(PREFIX)"

# Removes what install-files put there, honouring the same variables,
# HOOKS included.
#
# The links `make links` made in $(LINKDIR) go first, while the script
# that knows which they are is still there, so that nothing is left
# pointing at programs that are gone. A failure there, such as a
# LINKDIR that does not exist, stops nothing.
.PHONY: uninstall-files
uninstall-files:		## Remove what install-files put under PREFIX
	@echo "Removing tcslog-tools from $(DESTDIR)$(PREFIX)..."
	-$(SBINDIR)/tcslog-tools-links --remove --dir $(LINKDIR)
	$(RM) $(addprefix $(BINDIR)/,$(BINS)) $(SBINDIR)/tcslog-tools-links
	$(RMDIR) $(DOCDIR)
	if [ "$(HOOKS)" = 1 ]; then \
		$(RM) $(PROFILE); \
	fi
	@echo "[OK] Uninstalled from $(DESTDIR)$(PREFIX)"

# Where `make links` links the installed programs, and from where
# uninstall-files removes them: see tcs-helpers' packaging.mk.
LINKDIR ?= /usr/local/bin

.PHONY: docs
docs:				## Build the HTML manual from docs/*.rst
	$(MAKE) -C docs

# The packaging targets -- install, uninstall, stage, deb, rpm, packages,
# lint-packages, links and unlinks -- are tcs-helpers' packaging.mk's,
# shared by the TCS projects; see it for what each does. This repository
# has the one package, built from packaging/deb/tcslog-tools and
# packaging/rpm/tcslog-tools.spec. Without a tcs-helpers checkout new
# enough to have install-packages.sh, which came with the install target
# in 0.4.0, there is nothing to include that has every target here, and
# the targets stop as the tcs-helpers target says.
PACKAGES     := tcslog-tools
LINT_SCRIPTS := bin/make-releases
ifneq ($(wildcard $(TCS_HELPERS)/packaging/install-packages.sh),)
include $(TCS_HELPERS)/packaging/packaging.mk
else
.PHONY: install
install: tcs-helpers
.PHONY: uninstall
uninstall: tcs-helpers
.PHONY: stage
stage: tcs-helpers
.PHONY: deb
deb: tcs-helpers
.PHONY: rpm
rpm: tcs-helpers
.PHONY: packages
packages: tcs-helpers
.PHONY: lint-packages
lint-packages: tcs-helpers
.PHONY: links
links: tcs-helpers
.PHONY: unlinks
unlinks: tcs-helpers
endif

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
