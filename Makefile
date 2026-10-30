# Makefile for tcslog-tools

# Run every recipe under bash with pipefail, so a failing stage in the
# middle of a pipeline is not hidden by a succeeding last stage.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Portable command abstractions (override per-OS as needed)
RM      := rm -f
RMDIR   := rm -rf

# The binaries this crate produces, which is also what install and
# uninstall move in and out of $(PREFIX)/bin, and what tcslog-tools-links
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

# Where `make install` puts everything: /opt/tcs, the tree the TCS
# packages share under FHS 3.0's /opt/<package>, so that one PATH entry
# serves them all. DESTDIR stages the install for packaging. A developer
# installing somewhere of their own sets PREFIX, such as PREFIX=$HOME.
PREFIX  ?= /opt/tcs
DESTDIR ?=
# Whether install also writes /etc/profile.d/tcslog-tools.sh, which puts
# /opt/tcs/bin on a login shell's PATH. Off unless asked for, so that an
# install touches nothing in /etc that its installer did not mean it
# to; `make stage` asks, the package being where it belongs. It names
# /opt/tcs, so it is refused with any other PREFIX rather than installed
# pointing at the wrong tree.
HOOKS   ?= 0
# Whether install strips the binaries it installs; see install below.
STRIP   ?= 1
ifeq ($(HOOKS),1)
ifneq ($(PREFIX),/opt/tcs)
$(error HOOKS=1 installs a file that names /opt/tcs; give PREFIX=/opt/tcs \
	or leave HOOKS unset)
endif
endif
BINDIR  := $(DESTDIR)$(PREFIX)/bin
SBINDIR := $(DESTDIR)$(PREFIX)/sbin
DOCDIR  := $(DESTDIR)$(PREFIX)/share/doc/tcslog-tools
PROFILE := $(DESTDIR)/etc/profile.d/tcslog-tools.sh
DOCS    := README.md LICENSE-APACHE LICENSE-MIT CHANGELOG.md \
	docs/tcslog-tools.html

# Install the binaries, built for release, and the documents a reader
# of the installed tree needs. Built with cargo build and copied, rather
# than with cargo install, which would also leave its own records of
# what it installed, .crates.toml and .crates2.json, in $(PREFIX). The
# library is linked in statically, as Rust links its dependencies, so
# nothing of tcslog's needs to be installed for these to run.
#
# Under STRIP=1, the default, the binaries are stripped of every symbol
# nothing links against as they are installed, which takes about a
# quarter off each. STRIP=0 keeps them as cargo built them, for a
# debugger.
.PHONY: install
install: docs			## Build, strip (STRIP=0: don't), install
	@echo "Installing tcslog-tools $(VERSION) to $(DESTDIR)$(PREFIX)..."
	cargo build --release --locked
	install -D -m 755 -t $(BINDIR) $(addprefix target/release/,$(BINS))
	install -d $(SBINDIR)
	sed -e 's|@PACKAGE@|tcslog-tools|g' -e 's|@PREFIX@|$(PREFIX)|g' \
		-e 's|@PROGRAMS@|$(BINS)|g' packaging/hooks/links.sh.in \
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

# Removes what install put there, honouring the same variables, HOOKS
# included.
#
# The links `make links` made in $(LINKDIR) go first, while the script
# that knows which they are is still there, so that nothing is left
# pointing at programs that are gone. A failure there, such as a
# LINKDIR that does not exist, stops nothing.
.PHONY: uninstall
uninstall:			## Remove what install put under PREFIX
	@echo "Removing tcslog-tools from $(DESTDIR)$(PREFIX)..."
	-$(SBINDIR)/tcslog-tools-links --remove --dir $(LINKDIR)
	$(RM) $(addprefix $(BINDIR)/,$(BINS)) $(SBINDIR)/tcslog-tools-links
	$(RMDIR) $(DOCDIR)
	if [ "$(HOOKS)" = 1 ]; then \
		$(RM) $(PROFILE); \
	fi
	@echo "[OK] Uninstalled from $(DESTDIR)$(PREFIX)"

# Link the installed programs into $(LINKDIR), or take those links away
# again, with the tcslog-tools-links install put in sbin: what an
# administrator does to make them available beyond login shells, to sudo
# and cron among others. Needs root for /usr/local/bin, being root's;
# LINKDIR names another directory, such as /opt/bin.
LINKDIR ?= /usr/local/bin
.PHONY: links
links:				## Link the installed programs into LINKDIR
	$(DESTDIR)$(PREFIX)/sbin/tcslog-tools-links --dir $(LINKDIR)

.PHONY: unlinks
unlinks:			## Remove the links `make links` made in LINKDIR
	$(DESTDIR)$(PREFIX)/sbin/tcslog-tools-links --remove --dir $(LINKDIR)

.PHONY: docs
docs:				## Build the HTML manual from docs/*.rst
	$(MAKE) -C docs

# Where the packages are made from and where they land, both under
# build/, which .gitignore keeps out of the repository. The stage is one
# directory per package, as tcspecial's is, though this repository has
# only the one package.
STAGE    := $(CURDIR)/build/stage
PKGSTAGE := $(STAGE)/tcslog-tools
PKGOUT   := $(CURDIR)/build/packages

# Install into $(PKGSTAGE) as the package installs onto a machine: under
# /opt/tcs, with the hook, and stripped unless STRIP=0 says otherwise,
# which the sub-make is passed as every variable on the command line is.
# The stage is emptied first, so that nothing a previous install left
# behind gets into a package. Files are then made writable by their
# owner alone, whatever the umask of whoever ran this, which is what
# both package formats expect.
.PHONY: stage
stage:				## Install into build/stage/tcslog-tools
	$(RMDIR) $(STAGE)
	$(MAKE) install DESTDIR=$(PKGSTAGE) PREFIX=/opt/tcs HOOKS=1
	chmod -R u+rwX,go=rX $(PKGSTAGE)
	@echo "[OK] Staged under $(PKGSTAGE)"

# Build the .deb from the stage, with the control files in
# packaging/deb/tcslog-tools. dpkg-shlibdeps works out what the binaries
# need from the libraries they link, but wants a debian/control to read,
# so it is given a minimal one in a directory of its own.
#
# DEB_REVISION is the Debian revision, for a package rebuilt from the
# same source, as in tcspecial.
DEB_DIR := packaging/deb/tcslog-tools
DEB_REVISION ?= 1
DEB_VERSION  := $(VERSION)-$(DEB_REVISION)
.PHONY: deb
deb: stage			## Build the .deb in build/packages
	root=$(CURDIR)/build/deb/tcslog-tools; \
	arch=$$(dpkg --print-architecture); \
	$(RMDIR) $$root; \
	mkdir -p $(CURDIR)/build/deb $(PKGOUT); \
	cp -a $(PKGSTAGE) $$root; \
	install -d -m 755 $$root/DEBIAN; \
	shl=$(CURDIR)/build/deb/shlibdeps; \
	$(RMDIR) $$shl; \
	mkdir -p $$shl/debian; \
	printf 'Source: tcslog-tools\n\nPackage: tcslog-tools\n%s\n' \
		'Architecture: any' > $$shl/debian/control; \
	depends=$$(cd $$shl && dpkg-shlibdeps -O \
		$(addprefix -e$$root/opt/tcs/bin/,$(BINS)) 2>/dev/null \
		| sed -n 's/^shlibs:Depends=//p'); \
	size=$$(du -sk $$root | cut -f1); \
	sed -e 's|@VERSION@|$(DEB_VERSION)|' -e "s|@ARCH@|$$arch|" \
		-e "s|@SIZE@|$$size|" -e "s|@DEPENDS@|$$depends|" \
		$(DEB_DIR)/control > $$root/DEBIAN/control; \
	install -m 644 $(DEB_DIR)/conffiles $$root/DEBIAN/; \
	install -m 755 $(DEB_DIR)/prerm $$root/DEBIAN/; \
	dpkg-deb --root-owner-group --build $$root \
		$(PKGOUT)/tcslog-tools_$(DEB_VERSION)_$$arch.deb

# Build the .rpm from the same stage, with
# packaging/rpm/tcslog-tools.spec, whose %install copies the stage
# rather than building anything. A machine without rpmbuild says so and
# carries on, so that `make packages` still makes the .deb; that is
# checked before staging, so as not to build for nothing. rpmbuild is
# pointed at a database of its own under build/, because a Debian host
# has no RPM database in /var/lib/rpm to read, and rpmbuild complains at
# length when it finds none.
RPM_TOP := $(CURDIR)/build/rpm
.PHONY: rpm
rpm:				## Build the .rpm in build/packages
	@if ! command -v rpmbuild > /dev/null; then \
		echo "rpmbuild is not installed, so no RPM was built;" \
			"install it with 'sudo apt install rpm'"; \
		exit 0; \
	fi; \
	$(MAKE) stage; \
	$(RMDIR) $(RPM_TOP); \
	mkdir -p $(PKGOUT) $(RPM_TOP)/db; \
	rpmbuild -bb --quiet \
		--define "_topdir $(RPM_TOP)" \
		--define "_dbpath $(RPM_TOP)/db" \
		--define "tcs_version $(VERSION)" \
		--define "tcs_stage $(PKGSTAGE)" \
		packaging/rpm/tcslog-tools.spec; \
	cp $(RPM_TOP)/RPMS/*/tcslog-tools-$(VERSION)-*.rpm $(PKGOUT)/; \
	echo "[OK] Built the RPM in $(PKGOUT)"

.PHONY: packages
packages: deb rpm		## Build both; STRIP=0 leaves them unstripped

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
