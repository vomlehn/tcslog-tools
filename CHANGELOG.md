# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog][kac], and the project follows
[Semantic Versioning][semver].

These tools read logs; they never create one. Which stored segment file formats
a build understands is therefore the `tcslog` version it was built against, not
this one — a build reads a file whose major format version matches the
library's and whose minor version is no greater. Each entry below says which
library version it requires.

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html

## [Unreleased]

Requires `tcslog` 0.2.

### Added

- `bin/make-releases` creates a GitHub release for each tag, with the notes
  for each taken from `docs/release-notes/<version>.md`. A tag alone is enough
  for this file's footer links, which resolve whether or not a release exists;
  the releases exist so that page carries the version's notes rather than just
  its commit. The notes are kept as files rather than extracted from here
  because a release that changed neither tool says so in its notes and nowhere
  in this file. The sibling `tcslog` repository carries the same script for
  its own tags.

## [0.1.5] - 2026-10-04

Requires `tcslog` 0.2.

### Added

- A library target carrying the README as the crate's documentation, which is
  what docs.rs renders. These are two command-line programs, so there had been
  no library to document and so no docs.rs page for the crate at all -- only
  one per binary, which is not where anyone looks first. The target exports
  nothing and no dependent has reason to link it. The README is included
  rather than copied, so the page cannot drift from what crates.io shows.
- The README points at the documentation: `docs/tcslog-tools.rst` for these
  tools at greater length, and `docs/tcslog.rst` in the `tcslog` repository
  for the log format they read and the recovery rules they report on, those
  belonging to the library rather than here.

## [0.1.4] - 2026-10-03

Requires `tcslog` 0.2.

### Changed

- `tcslog-dump` now prints a payload as hexadecimal by default: two lower-case
  digits a byte, separated by one space. It had printed each byte as the
  character of that value, which is Latin-1 rather than anything asked for, and
  which handed the terminal control bytes to act on.

  Hexadecimal is the rendering that assumes nothing. Telemetry is bytes and
  most of it is not text at all — a fixed-format record is counters and flags,
  which say nothing shown as characters — so reading a payload as text is now
  what `--text` is for, and the default shows the bytes.

  **Output changes for every caller**, not only those passing a flag. The 20
  expected-output files in the `tcslog` repository's error-recovery suite were
  regenerated; every payload line there was confirmed to decode back to exactly
  what it had shown, with no structural line changed.

## [0.1.3] - 2026-10-03

Requires `tcslog` 0.2.

### Changed

- `tcslog-dump --text` now displays payloads as ASCII rather than decoding
  them as UTF-8. A printable character prints as itself and everything else
  prints as an escape — `\n`, `\r`, `\t`, `\\`, or `\xNN`.

  UTF-8 was the wrong thing to ask for of telemetry that is not required to be
  text, and `from_utf8_lossy` answered badly in both directions: it replaced
  every byte it could not decode with one replacement character, losing which
  byte had been there, while passing control bytes straight through to the
  terminal — where an escape byte can start a sequence that swallows what
  follows and a newline breaks one record across two lines. An escape says
  which byte it was and disturbs nothing.

  Rendering without the flag is unchanged: each payload byte prints as the
  character of that value. The error-recovery suite exercises only that path
  and is unaffected.

### Added

- Unit tests for both renderings, covering the ends of the printable range,
  the escaped control bytes, bytes above the ASCII range, and a backslash in
  the payload — which has to be escaped too, or `\x41` in a payload would read
  as the escape for `A`.

## [0.1.2] - 2026-10-03

Requires `tcslog` 0.2.

### Fixed

- `--help` and `--version` now write to standard output and exit 0 in both
  tools. They had gone through the same arm as a usage error, writing to
  standard error and exiting 2, so `tcslog-dump --help | less` showed nothing
  and a script checking the status saw a failure. A usage error still exits 2,
  and now puts both the complaint and the help on standard error rather than
  splitting them across the two streams, which leaves standard output carrying
  nothing but what was asked for.

### Added

- A test that the options each tool offers and the options the documentation
  lists are the same set, in both directions, run by `make test`. Every option
  is described in three places — the `clap` help string, `README.md`, and
  `docs/tcslog-tools.rst` — and the `--text` drift fixed in 0.1.1 is what three
  copies produce. The *set* is what a test can hold: the help string is
  deliberately terse and the manual deliberately is not, so requiring them to
  match word for word would make one of them worse. An option added without
  being documented, or documented after being removed, now fails the build; a
  description that is merely wrong still does not, and only reading the code
  catches that.

## [0.1.1] - 2026-10-03

Requires `tcslog` 0.2.

### Fixed

- `tcslog-dump --help` described `--text` as choosing between hex bytes and
  text, with the default on the wrong half. There is no hex output in the tool:
  both paths print text, differing only in whether the payload is decoded as
  UTF-8 or each byte printed as the character of that value. The help string
  now says that, matching what `README.md` and `docs/tcslog-tools.rst` already
  said correctly. Behaviour is unchanged.

## [0.1.0] - 2026-10-03

First release of `tcslog-tools`, two command-line tools for looking at a
[tcslog](https://crates.io/crates/tcslog) log — written on board a vehicle that
cannot send its telemetry home as it is produced, and usually read somewhere
else entirely, after the segment files have been downlinked a piece at a time.

Requires `tcslog` 0.2.

```sh
cargo install tcslog-tools
```

### Added

- `tcslog-dump` reads a whole log and prints it, naming the directory, the
  segment file name prefix, and the suffix. `--text` decodes payloads as UTF-8,
  with invalid sequences replaced; without it each byte is printed as the
  character of that value. `--verbose` adds segment headers, session boundaries
  and a closing summary to the records themselves.
- Losses are printed rather than passed over. Where segment files are missing or
  damaged, the dump says how many went missing and where, and a record cut
  short is shown as a partial, marked so it cannot be read as a whole one.
  Running out of files is the only thing that ends the dump.
- `tcslog-dumphdr` prints one segment file's header — its identifiers, size,
  format and position in its session — and never consults the file's name, so
  it works on a file renamed or copied out of its log's directory. It reads the
  file named on the command line, or standard input when none is given, and
  reads only the header rather than the data section behind it.
- Installation from a registry, with `cargo install tcslog-tools`, or from a
  checkout with `make install`. `PREFIX` chooses somewhere other than your home
  directory and `DESTDIR` stages the install for packaging; `make uninstall`
  removes both binaries, honouring the same two variables.

### Notes

- Neither tool needs `TIMER_RESOLUTION`. That value is required only to create
  segment files, and neither of these creates one, so both take the library
  with its `write` feature off — which is why they are a crate of their own
  rather than part of the library's workspace, and why someone who only wants
  to read a log need not build the writing side to do it.
- The `tcslog` repository's error-recovery suite drives both tools; its
  `bin/tcslog-tool` locates them, expecting `../tcslog-tools` beside that
  checkout unless `TCSLOG_TOOLS` says otherwise.
- The log format, the record formats, and the recovery rules these tools report
  on are described in the library's documentation. These tools' own
  documentation is `docs/tcslog-tools.rst`.
- Requires Rust 1.75 or later. Dual licensed under MIT OR Apache-2.0.

[unreleased]: https://github.com/vomlehn/tcslog-tools/compare/v0.1.5...HEAD
[0.1.5]: https://github.com/vomlehn/tcslog-tools/releases/tag/v0.1.5
[0.1.4]: https://github.com/vomlehn/tcslog-tools/releases/tag/v0.1.4
[0.1.3]: https://github.com/vomlehn/tcslog-tools/releases/tag/v0.1.3
[0.1.2]: https://github.com/vomlehn/tcslog-tools/releases/tag/v0.1.2
[0.1.1]: https://github.com/vomlehn/tcslog-tools/releases/tag/v0.1.1
[0.1.0]: https://github.com/vomlehn/tcslog-tools/releases/tag/v0.1.0
