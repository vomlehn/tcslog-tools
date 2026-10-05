# tcslog-tools

Command-line tools for inspecting [tcslog](https://github.com/vomlehn/tcslog)
segment files.

`tcslog-dump` walks a whole log — a directory of segment files sharing a
prefix and suffix — and prints the records it recovers, with the losses it
found. `tcslog-dumphdr` prints one segment file's header, reading the bytes
it is handed and never the file's name, so it also serves a file that has
been renamed or copied out of its log.

Both tools only read. They take `tcslog` with its default `write` feature
turned off, so neither needs the `TIMER_RESOLUTION` the writing side
requires at build time. Nor does the writing side's API reach them:
`WriteCallbacks` became a trait in `tcslog` 0.3.0, where it had been a
structure of function pointers, which breaks every caller that writes and
leaves these two untouched.

The library version required is 0.3. That version, not this crate's, is what
decides which stored segment file formats a build understands: it reads a
file whose major format version matches the library's and whose minor
version is no greater.

## Installing

```sh
cargo install tcslog-tools
```

Or from a checkout, into `$HOME/bin`:

```sh
make install
```

`make install PREFIX=/usr/local` chooses somewhere else and `DESTDIR` stages
the install for packaging. `make uninstall` removes both binaries again,
honouring the same two variables.

## tcslog-dump

```sh
tcslog-dump <dir> <prefix> <suffix> [--verbose] [--text]
```

Without options it prints one line per record and nothing else, which is
what to pipe into something else. A payload prints as hexadecimal: two
lower-case digits a byte, one space between, which assumes nothing about
telemetry that is mostly not text.

- `-v`, `--verbose` — also print a block for every segment file the read
  passed through, a notice wherever telemetry was lost or a record did not
  fit, a marker at each session boundary, and totals at the end.
- `-t`, `--text` — display payloads as ASCII. A printable character prints as
  itself; everything else prints as an escape — `\n`, `\r`, `\t`, `\\`, or
  `\xNN` — so that no byte of telemetry can move the cursor, start an escape
  sequence that swallows what follows, or break one record across two lines.
  The escape also says which byte was there. Without the flag a payload
  prints as hexadecimal.
- `-h`, `--help` — print the options to standard output and exit 0, so the
  help can be piped. `--version` does the same. A usage error puts both the
  complaint and the help on standard error and exits 2, leaving standard
  output carrying nothing but what was asked for.

## tcslog-dumphdr

```sh
tcslog-dumphdr <file>
tcslog-dumphdr < <file>
```

Prints the header on a single line. It reads the file named on the command
line, or standard input when none is named. It reads only the header, so the
standard input form works on a pipe whose writer is still running. A read
failure exits 1 and a usage error exits 2.

## Building from a checkout

The `tcslog` dependency is a path to a sibling checkout, so clone both
repositories side by side:

```sh
git clone https://github.com/vomlehn/tcslog.git
git clone https://github.com/vomlehn/tcslog-tools.git
cd tcslog-tools && cargo build
```

`cargo publish` substitutes the registry version for that path, so a release
does not depend on the layout.

## Documentation

The manual is `docs/tcslog-tools.rst` in [the
repository](https://github.com/vomlehn/tcslog-tools), which covers both tools
at greater length than this page; `make -C docs` renders it to
`docs/tcslog-tools.html`.

The log format these tools read, the record formats, and the recovery rules
they report on belong to the library and are described in `docs/tcslog.rst`
in [the tcslog repository](https://github.com/vomlehn/tcslog).

## License

Dual licensed under MIT OR Apache-2.0.
