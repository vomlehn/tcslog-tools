===============================
Tcslog-tools User Documentation
===============================

.. contents:: Table of Contents
   :depth: 3
   :local:

Introduction
============

``tcslog-tools`` is two command-line programs that read Tcslog logs:
``tcslog-dump``, which walks a whole log and prints the records it
recovers, and ``tcslog-dumphdr``, which prints one segment file's
header.

The library they read with is used from Rust, C/C++, and Python 3, and
the stored format does not depend on which of them wrote a log, so
these tools read any Tcslog log whatever language its writer was in.

They are a crate separate from the ``tcslog`` library, in its own
repository, because they only read a log: they want neither the
library's ``write`` feature nor the build-time timer resolution that
comes with it, and someone who only needs to look at a log should not
have to build the writing side to do it.

The log format they read, the record formats, and the recovery rules
they report on are described in the library's documentation,
``docs/manual.rst`` in the `tcslog repository
<https://github.com/vomlehn/tcslog>`_.

Building and Installation
=========================

Prerequisites
-------------

A Rust toolchain of version 1.75 or later. No ``TIMER_RESOLUTION`` is
needed: that value is required only when creating segment files, and
neither tool creates one.

The ``tcslog`` library, version 0.4. Which stored segment file formats a
build of these tools understands follows from that version rather than
from this crate's: a build reads a file whose major format version
matches the library's and whose minor version is no greater.

That requirement has moved twice, each time for a change to a part of
the library these tools do not use.

``WriteCallbacks``, the callbacks a writer is given, was a structure of
three function pointers through 0.2.x and is a trait of three methods
from 0.3.0, so that an implementation can keep whatever state the
callbacks need. It breaks every caller that writes; neither tool writes,
and taking the library with its default features off leaves its
``write`` module out of this build altogether, so there is nothing here
to break.

``Record``, the value ``LogRead::iter()`` yields, gained a field in
0.4.0 saying whether the record is a whole one or only its front. That
breaks a caller that builds or exhaustively destructures one; neither
tool does either, and neither names ``Record``, both reading through
``LogRead::read()`` into a buffer of their own. ``tcslog-dump`` already
reports the distinction the field carries, because ``read()`` always
made it: a record cut short arrives as ``ReadTruncated`` with the bytes
recovered, and the tool prints them marked. It was the iterator that
handed partial records back unmarked, and the iterator is what 0.4.0
fixes.

The records the tools read are the same records across both releases,
the stored format having stayed at 0.1.0 throughout.

The requirement moves only because a caret requirement on 0.3 does not
match 0.4. A copy of these tools already built against ``tcslog`` 0.3,
or 0.2, is equally correct and goes on working; this says which release
they are built against from here.

Installing
----------

Install both tools from the registry::

    cargo install --locked tcslog-tools

``--locked`` builds with the dependency versions this crate was tested
with, which support Rust 1.75. Without it, Cargo before 1.84 picks the
newest versions of every dependency, some of which need a newer Rust.

Or from a checkout. The ``tcslog`` dependency is a path to a sibling
checkout, so clone both repositories side by side::

    git clone https://github.com/vomlehn/tcslog.git
    git clone https://github.com/vomlehn/tcslog-tools.git
    sudo make -C tcslog-tools install

That installs both tools in ``/opt/tcs/bin``, the tree the TCS packages
share under FHS 3.0's ``/opt/<package>``, and this manual, the README,
the licences and the changelog in ``/opt/tcs/share/doc/tcslog-tools``.
The library is linked in, so neither tool needs ``tcslog`` installed to
run. ``PREFIX`` chooses somewhere else, ``DESTDIR`` stages the install,
and ``make uninstall`` removes it again, honouring the same variables::

    make install PREFIX=$HOME           # into $HOME/bin
    make install DESTDIR=/tmp/stage

``HOOKS=1`` also installs ``/etc/profile.d/tcslog-tools.sh``, which adds
``/opt/tcs/bin`` to a login shell's ``PATH`` unless it is there already.
It is left out unless asked for, so that an install touches nothing in
``/etc`` its installer did not mean it to, and it needs the default
``PREFIX``, since it names ``/opt/tcs``. Cargo installs from a checkout
as well, with ``cargo install --locked --path . --root /opt/tcs``, but
leaves its own record of what it installed, ``.crates.toml`` and
``.crates2.json``, in that root.

Under ``STRIP=1``, the default, install strips both binaries with
``strip --strip-unneeded``, which takes about a quarter off each;
``STRIP=0`` keeps them as cargo built them, for a debugger.

Login shells find ``/opt/tcs/bin`` through
``/etc/profile.d/tcslog-tools.sh``, but sudo, cron and other minimal
environments do not read it, and so do not find the programs. To make
them available everywhere, link them into ``/usr/local/bin``, which is
on every one of those paths, sudo's ``secure_path`` included::

    sudo /opt/tcs/sbin/tcslog-tools-links            # link them
    sudo /opt/tcs/sbin/tcslog-tools-links --remove   # undo it

``--dir`` names another directory, such as ``/opt/bin``. It links only
this package's own programs, written into it when it was installed, so
it never touches another TCS package's; it leaves anything already in
the way alone, says so, and exits 1 once it has linked the rest. It is
never run for you: removing the package removes its links, from
``/usr/local/bin`` and ``/opt/bin``, but installing it makes none, the
choice being the administrator's. After ``make install``, ``sudo make
links`` and ``sudo make unlinks`` do the same, with ``LINKDIR`` naming
the directory.

Or as a package. ``make deb`` and ``make rpm`` build one in
``build/packages``, ``tcslog-tools_<version>-1_<arch>.deb`` and
``tcslog-tools-<version>-1.<arch>.rpm``, and ``make packages`` builds
both, from one install into ``build/stage/tcslog-tools`` (``make
stage``) with the hook and stripped as above, so the two hold the same
files; the RPM is kept from stripping on its own. The ``1`` is the
package's release, for a package rebuilt from the same source, which
``DEB_REVISION`` sets for the .deb. Building them needs ``rst2html``
from docutils and ``dpkg-shlibdeps`` from dpkg-dev; ``make rpm`` needs
``rpmbuild``, which Debian has as ``sudo apt install rpm``, and where it
is missing says so and builds nothing, without failing::

    make -C tcslog-tools deb
    sudo apt install ./tcslog-tools/build/packages/tcslog-tools_*.deb

The .deb also carries what Debian expects of every package, outside
``/opt/tcs`` as the hook is: ``/usr/share/doc/tcslog-tools/copyright``,
in Debian's machine-readable format, and ``changelog.Debian.gz``, both
made as the package is built, from ``LICENSE-MIT`` and the version, and
lintian's overrides, in ``/usr/share/lintian/overrides/tcslog-tools``.
The RPM says the same in its own ``License`` and ``%changelog``.

``make lint-packages`` checks the packages ``make packages`` built with
lintian and rpmlint, and the shell scripts they run or install with
shellcheck: the hook and ``tcslog-tools-links`` as the stage has them,
the .deb's ``prerm``, the packaging scripts and ``bin/make-releases``.
It skips, in a line, any of the three that is not installed, and fails
on any finding that is not overridden. What is overridden is intended,
and says why: for lintian in
``packaging/deb/tcslog-tools/lintian-overrides``, which the .deb
carries, and for rpmlint in ``packaging/rpm/rpmlint.toml``, which is not
shipped.

``cargo publish`` substitutes the registry version for the path
dependency, so a release does not depend on the side-by-side layout.

The ``tcslog`` repository's error-recovery suite drives both tools, and
its ``bin/tcslog-tool`` is what finds them: it expects
``../tcslog-tools`` beside that repository, and ``TCSLOG_TOOLS`` points
it somewhere else.

Reading a whole log: tcslog-dump
================================

Run it on a log by naming the directory, prefix, and suffix, in that
order::

    tcslog-dump /var/telemetry tlm- .seg

Without options it prints one line per record and nothing else, which is
what to pipe into something else. The options are:

``-v``, ``--verbose``
    Also print a block for every segment file the read passed through,
    a notice wherever telemetry was lost or a record did not fit, a
    marker at each session boundary, and totals at the end.

``-t``, ``--text``
    Display payloads as ASCII. A printable character prints as itself,
    and everything else prints as an escape -- ``\n``, ``\r``, ``\t``,
    ``\\``, or ``\xNN``. Telemetry is not required to be text, and a
    payload that is not can carry a byte that moves the cursor, starts
    an escape sequence that swallows whatever is printed after it, or
    ends the line in the middle of a record. Escaping also says which
    byte was there, which a replacement character would not.

    Without the flag a payload prints as hexadecimal: two lower-case
    digits for each byte, separated by one space. That is the rendering
    that assumes nothing. Telemetry is bytes, and most of it is not text
    at all -- a fixed-format record is counters and flags, which say
    nothing when shown as characters -- so the default shows the bytes
    and leaves reading them as text to the flag.

``--rec-size <bytes>``
    The largest payload, in bytes, read without truncation: an unsigned
    integer of at least 1, and 65536 (64 KiB) unless given, the size
    tcslog's own record iterator reads into. A record with a longer
    payload prints cut short and marked as such, and ``--verbose`` says
    how many of its bytes were captured. The data header is read
    separately and does not count toward the size.

``-h``, ``--help``
    Print the options on standard output and exit with status 0, so that
    the help can be piped. ``--version`` does the same. A usage error
    puts both the complaint and the help on standard error and exits
    with status 2, which leaves standard output carrying nothing but
    what was asked for.

From a checkout of the ``tcslog`` repository, without installing::

    ./bin/tcslog-tool tcslog-dump /var/telemetry tlm- .seg --verbose

The three positional arguments are the same three the library's
``sample`` example takes, so a log written by the example is read back
by ``tcslog-dump``::

    cargo run --example sample -- /tmp/demo demo- .seg --verbose
    ./bin/tcslog-tool tcslog-dump /tmp/demo demo- .seg --verbose

Examining one segment file: tcslog-dumphdr
==========================================

``tcslog-dumphdr`` prints one segment file's header on a single line::

    tcslog-dumphdr /var/telemetry/tlm-18d9-eafc-543b-c443.seg
    tcslog-dumphdr < /var/telemetry/tlm-18d9-eafc-543b-c443.seg

It reads the file named on its command line, or standard input when none
is named, and never consults the file's name. That is what makes it
useful for a file that has been renamed or copied out of its log, which
is exactly the case in which the name cannot be trusted. It reads only
the header, so the standard input form works on a pipe whose writer is
still running. A read failure exits 1 and a usage error exits 2.

See Also
========

`Tcslog manual <https://vomlehn.github.io/tcslog/docs/manual.html>`__
    Tcslog is flight software that stores telemetry on board a vehicle that
    is often out of contact. The manual says how to write a log, read it
    back, and what each outcome of reading means.

`Tcslog design <https://vomlehn.github.io/tcslog/docs/design.html>`__
    The Tcslog specification: the on-disk format, the public interfaces,
    the status codes and their ABI numbers, and the behaviour the library
    is required to have.
