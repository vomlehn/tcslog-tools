//! Reads a chain of segment files back and prints each segment file's
//! header (with `--verbose`) and every log message.
//!
//! Run with:
//!
//! ```text
//! cargo run --bin tcslog-dump -- <dir> <prefix> <suffix>
//! ```

use std::error::Error;
use std::fmt::Write as _;

use clap::error::ErrorKind;
use clap::{CommandFactory, Parser};

use tcslog::{record_trailer, LogError, LogRead, Meta, SegmentHeader};

const MAX_MESSAGE_SIZE: usize = 256;

/// Print a tcslog file
#[derive(Parser)]
#[command(version, about)]
struct Args {
    /// Directory in which the log file lives
    dirname: String,

    /// Segment file name prefix.
    prefix: String,

    /// Segment file name suffix.
    suffix: String,

    /// Display payloads as ASCII: a printable character as itself, and
    /// anything else as an escape, so that no byte of telemetry can move
    /// the cursor or break a record across two lines. Without it each
    /// payload byte is printed as two lower-case hexadecimal digits,
    /// separated by one space.
    #[arg(short, long)]
    text: bool,

    /// Print segment headers, session boundaries, and summary information
    /// in addition to log messages.
    #[arg(short, long)]
    verbose: bool,
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::try_parse().unwrap_or_else(|e| {
        // `--help` and `--version` are requests, not mistakes. Clap's
        // own exit writes them to standard output and exits 0, which is
        // what a caller piping the output into a pager expects.
        if matches!(e.kind(), ErrorKind::DisplayHelp | ErrorKind::DisplayVersion) {
            e.exit();
        }
        // Everything else is a usage error. Both the complaint and the
        // help that answers it go to standard error, leaving standard
        // output to carry nothing but what was asked for.
        eprintln!("{e}");
        eprintln!("{}", Args::command().render_help());
        std::process::exit(2);
    });

    let mut log = LogRead::new(&args.dirname, &args.prefix, &args.suffix)?;
    // Only collect segment headers when they will be printed: the
    // reader buffers them until drained, and a non-verbose run never
    // drains.
    log.collect_opened_headers(args.verbose);
    let mut printed_header = false;
    let mut files_lost = 0u64;
    let mut total = 0u64;
    let mut buf = vec![0u8; MAX_MESSAGE_SIZE];

    loop {
        let read_result = log.read(&mut buf);
        // Report every segment this read traversed, not just the one a
        // record ended in: a record spanning several segments starts in
        // one that `current_header` never names. Drained before the
        // result is examined so the headers precede the record they
        // carried, and so a read that ends the loop still reports the
        // segments it opened.
        for h in log.take_opened_headers() {
            if printed_header {
                println!();
            }
            printed_header = true;
            print_header(&args.prefix, &args.suffix, &h);
        }
        match read_result {
            Ok(res) => {
                total += 1;
                print_record(args.text, res.meta, &buf[..res.n as usize]);
                println!();
            }
            Err(LogError::Eof) => break,
            Err(LogError::ReadTruncated { lost, n }) => {
                files_lost += lost;
                // Whatever of the record reached the buffer before the
                // gap is real payload, so print it rather than dropping
                // it on the floor, marked so a record cut short cannot
                // be mistaken for a whole one. `n` is zero when the gap
                // fell on a record boundary or ahead of a session's
                // first surviving segment, where no record was cut
                // short and there is nothing to print.
                if n > 0 {
                    total += 1;
                    print_truncated_record(args.text, &buf[..n as usize]);
                    println!();
                }
                // A gap that falls on a record boundary loses whole
                // records rather than truncating one, and a gap before a
                // session's first surviving segment truncates nothing at
                // all, so the wording reports the loss without claiming
                // which.
                if args.verbose {
                    if lost > 0 {
                        println!(
                            "    -- {lost} missing segment file(s); \
                             resynchronizing --"
                        );
                    } else {
                        println!(
                            "    -- corrupted or truncated segment file; \
                             resynchronizing --"
                        );
                    }
                }
            }
            Err(LogError::ReadOverflow(n)) => {
                total += 1;
                // The captured bytes are real payload. Print them
                // instead of dropping them on the floor, marked so they
                // cannot be mistaken for a whole record.
                print_partial_record(args.text, &buf[..n as usize]);
                println!();
                if args.verbose {
                    println!(
                        "    (payload larger than {MAX_MESSAGE_SIZE}-byte buffer; \
                        {n} bytes captured, remainder discarded)"
                    );
                }
            }
            Err(LogError::SessionEnd) => {
                if args.verbose {
                    println!();
                    println!("--- End of Session---");
                }
            }
            Err(e) => {
                return Err(e.into());
            }
        }
    }

    if args.verbose {
        // Ask the reader how many segment files it traversed rather
        // than counting the headers printed above: a record spanning
        // several segments only ever reports the one it ended in, so
        // counting those undercounts the log's extent.
        println!(
            "\nread {total} message(s) across {} file(s)",
            log.segments_opened()
        );
        if files_lost > 0 {
            println!("{files_lost} segment file(s) lost");
        }
    }
    Ok(())
}

fn print_record(text: bool, meta: Meta, buf: &[u8]) {
    let msg = format_msg(text, buf);
    print!("    {msg} {}", record_trailer(buf.len(), meta));
}

/// Prints the leading bytes of a record too large for the read buffer.
/// The record's own length and metadata are not available on this path,
/// so the trailer states only what was captured.
fn print_partial_record(text: bool, buf: &[u8]) {
    let msg = format_msg(text, buf);
    print!("    {msg} ({} bytes captured, record truncated)", buf.len());
}

/// Prints the leading bytes of a record whose tail was in a segment
/// file that was lost or corrupt. Unlike an overflow, the missing
/// bytes are gone from the log rather than merely from this buffer, so
/// the trailer says the record was cut short rather than that this
/// reader could not hold it.
fn print_truncated_record(text: bool, buf: &[u8]) {
    let msg = format_msg(text, buf);
    print!(
        "    {msg} ({} bytes recovered, rest of record lost)",
        buf.len()
    );
}

fn format_msg(as_ascii: bool, buf: &[u8]) -> String {
    if !as_ascii {
        // Hexadecimal is the rendering that assumes nothing. Telemetry
        // is bytes, and most of it is not text at all: a fixed-format
        // record is counters and flags, and showing those as characters
        // says nothing about them while handing the terminal control
        // bytes to act on. Two digits a byte, lower case, one space
        // between, so a byte can be read off by eye and counted
        // against the length in the trailer.
        let mut out = String::with_capacity(buf.len() * 3);
        for (i, b) in buf.iter().enumerate() {
            if i > 0 {
                out.push(' ');
            }
            let _ = write!(out, "{b:02x}");
        }
        return out;
    }
    // ASCII means ASCII: a byte outside the printable range is shown as
    // an escape rather than sent to the terminal, which a record dump
    // needs in both directions. A control byte passed through can move
    // the cursor, clear the screen, or start an escape sequence that
    // swallows what follows, and a newline inside a payload would break
    // one record across two lines. Going the other way, the escape says
    // which byte was there, where a replacement character would not.
    let mut out = String::with_capacity(buf.len());
    for &b in buf {
        match b {
            // Before the printable range it falls in, so that a
            // backslash in the payload cannot be read as one of ours.
            b'\\' => out.push_str("\\\\"),
            b'\n' => out.push_str("\\n"),
            b'\r' => out.push_str("\\r"),
            b'\t' => out.push_str("\\t"),
            0x20..=0x7e => out.push(b as char),
            _ => {
                let _ = write!(out, "\\x{b:02x}");
            }
        }
    }
    out
}

fn print_header(prefix: &str, suffix: &str, h: &SegmentHeader) {
    println!("=== segment file: {}{}{} ===", prefix, h.segment_id, suffix);
    println!("    segment_id: {}", h.segment_id);
    println!("    session_id: {}", h.session_id);
    println!("    max_size:   {}", h.max_size);
    println!("    remaining:  {}", h.remaining);
    println!("    format:     {:?}", h.format);
    println!("    sequence:   {}", h.sequence);
}

#[cfg(test)]
mod tests {
    use super::format_msg;

    /// What `--text` asks for, byte by byte.
    #[test]
    fn ascii_shows_printable_characters_as_themselves() {
        assert_eq!(format_msg(true, b"attitude nominal"), "attitude nominal");
        // The ends of the printable range, which must not be escaped.
        assert_eq!(format_msg(true, &[0x20, 0x7e]), " ~");
    }

    #[test]
    fn ascii_escapes_what_would_disturb_the_line() {
        // A newline would break one record across two lines, and an
        // escape byte could swallow whatever followed it.
        assert_eq!(format_msg(true, b"a\nb"), "a\\nb");
        assert_eq!(format_msg(true, b"a\rb"), "a\\rb");
        assert_eq!(format_msg(true, b"a\tb"), "a\\tb");
        assert_eq!(format_msg(true, &[b'a', 0x1b, b'b']), "a\\x1bb");
        assert_eq!(format_msg(true, &[0x00, 0x7f]), "\\x00\\x7f");
    }

    #[test]
    fn ascii_escapes_everything_above_the_ascii_range() {
        // Not ASCII, so not shown as a character: 0xe9 is `é` in
        // Latin-1 and the first byte of a sequence in UTF-8, and the
        // escape commits to neither reading.
        assert_eq!(format_msg(true, &[0xe9, b'A', 0x80]), "\\xe9A\\x80");
        assert_eq!(format_msg(true, &[0xff]), "\\xff");
    }

    #[test]
    fn a_backslash_in_the_payload_is_escaped_too() {
        // Otherwise `\x41` in a payload would read as the escape for
        // `A`, and the rendering could not be undone.
        assert_eq!(format_msg(true, br"a\b"), "a\\\\b");
        assert_eq!(format_msg(true, br"\x41"), "\\\\x41");
    }

    #[test]
    fn without_the_flag_each_byte_is_two_hexadecimal_digits() {
        assert_eq!(format_msg(false, &[0xe9, b'A', 0x80]), "e9 41 80");
        // Lower case, and the leading zero kept, so every byte is two
        // columns wide and they line up down the page.
        assert_eq!(format_msg(false, &[0x00, 0x0f, 0xff]), "00 0f ff");
        assert_eq!(format_msg(false, b"ab"), "61 62");
    }

    #[test]
    fn hexadecimal_separates_bytes_without_trailing_space() {
        // One space between, none at either end: a trailing space would
        // run into the trailer the caller prints after the payload.
        assert_eq!(format_msg(false, &[0x01]), "01");
        assert_eq!(format_msg(false, &[]), "");
        assert_eq!(format_msg(false, &[1, 2, 3]).matches(' ').count(), 2);
    }
}
