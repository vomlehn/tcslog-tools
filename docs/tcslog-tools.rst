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

They are a crate separate from the ``tcslog`` library, in its own
repository, because they only read a log: they want neither the
library's ``write`` feature nor the build-time timer resolution that
comes with it, and someone who only needs to look at a log should not
have to build the writing side to do it.

The log format they read, the record formats, and the recovery rules
they report on are described in the library's documentation,
``docs/tcslog.rst`` in the `tcslog repository
<https://github.com/vomlehn/tcslog>`_.

Building and Installation
=========================

Prerequisites
-------------

A Rust toolchain of version 1.75 or later. No ``TIMER_RESOLUTION`` is
needed: that value is required only when creating segment files, and
neither tool creates one.

Installing
----------

Install both tools from the registry::

    cargo install tcslog-tools

Or from a checkout. The ``tcslog`` dependency is a path to a sibling
checkout, so clone both repositories side by side::

    git clone https://github.com/vomlehn/tcslog.git
    git clone https://github.com/vomlehn/tcslog-tools.git
    make -C tcslog-tools install

That installs under your home directory; ``PREFIX`` chooses somewhere
else and ``DESTDIR`` stages the install for packaging, and ``make
uninstall`` removes both binaries again, honouring the same two
variables::

    make install PREFIX=/usr/local
    make install PREFIX=/usr DESTDIR=/tmp/stage

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

    Without the flag each payload byte is printed as the character of
    that value, control bytes included, which is the older behaviour and
    what the error-recovery suite checks.

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
