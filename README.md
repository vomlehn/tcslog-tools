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
requires at build time.

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
what to pipe into something else.

- `-v`, `--verbose` — also print a block for every segment file the read
  passed through, a notice wherever telemetry was lost or a record did not
  fit, a marker at each session boundary, and totals at the end.
- `-t`, `--text` — decode payloads as UTF-8 text. Without it each payload
  byte is printed as one character, which is what to use for telemetry that
  is not text.
- `-h`, `--help` — print the options and exit. A usage error exits 2.

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

## License

Dual licensed under MIT OR Apache-2.0.
