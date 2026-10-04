//! Checks that the options a tool defines and the options the
//! documentation lists are the same set.
//!
//! Each option is described in three places: the `clap` help string in
//! the tool's source, `README.md`, and `docs/tcslog-tools.rst`. Three
//! copies drift, and one already had -- `tcslog-dump --help` spent a
//! release describing `--text` as a choice between hex and text, which
//! the tool has never offered, while both documents had it right.
//!
//! What a test can hold is the *set* of options, not their wording. The
//! help string is deliberately terse and the manual deliberately is not,
//! so requiring them to match word for word would make one of them
//! worse. An option added without being documented, or documented after
//! being removed, is caught here; a description that is merely wrong is
//! not, and only reading the code catches that.

use std::collections::BTreeSet;
use std::path::Path;
use std::process::Command;

/// `--version` is `clap`'s, is understood without being told, and is
/// documented by neither file on purpose. Every other long option a tool
/// offers has to appear in both.
const UNDOCUMENTED_BY_DESIGN: &[&str] = &["--version"];

/// The long options a tool reports in its own `--help`.
///
/// * `exe` -- path to the built binary, from `CARGO_BIN_EXE_*`.
///
/// Returns the options, `--version` excluded.
fn options_offered(exe: &str) -> BTreeSet<String> {
    let out = Command::new(exe)
        .arg("--help")
        .output()
        .unwrap_or_else(|e| panic!("cannot run {exe}: {e}"));
    // Both tools hand `--help` to the same arm as a usage error, which
    // writes to standard error and exits 2 rather than writing to
    // standard output and exiting 0. Both streams are read and the
    // status is not checked, so this test holds whichever way that is
    // settled; it is not the test's business to assert it.
    let mut help = String::from_utf8_lossy(&out.stdout).to_string();
    help.push_str(&String::from_utf8_lossy(&out.stderr));
    // The help lists each option as `-x, --long`, and the usage line
    // above it names none of them, so scanning the whole output for
    // long options yields exactly the set offered.
    long_options(&help)
        .into_iter()
        .filter(|o| !UNDOCUMENTED_BY_DESIGN.contains(&o.as_str()))
        .collect()
}

/// The long options named anywhere in a document.
///
/// * `text` -- the document.
///
/// Returns every `--option` it mentions. Both documents name an option
/// in a usage line as well as in its own entry, which this does not
/// distinguish and does not need to: the question is whether the option
/// is spoken of at all.
fn long_options(text: &str) -> BTreeSet<String> {
    let mut found = BTreeSet::new();
    let bytes: Vec<char> = text.chars().collect();
    let mut i = 0;
    while i + 2 < bytes.len() {
        if bytes[i] == '-' && bytes[i + 1] == '-' && bytes[i + 2].is_ascii_alphabetic() {
            let mut j = i + 2;
            while j < bytes.len() && (bytes[j].is_ascii_alphanumeric() || bytes[j] == '-') {
                j += 1;
            }
            found.insert(bytes[i..j].iter().collect::<String>());
            i = j;
        } else {
            i += 1;
        }
    }
    found
}

/// Reads one of the repository's documents.
///
/// * `name` -- path relative to the crate root.
///
/// Returns its contents.
fn document(name: &str) -> String {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join(name);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("cannot read {}: {e}", path.display()))
}

/// Compares what a tool offers with what a document lists.
///
/// * `exe` -- path to the built binary.
/// * `tool` -- the tool's name, for the failure message.
/// * `doc_name` -- which document is being checked.
/// * `listed` -- the options named anywhere in it.
fn check(exe: &str, tool: &str, doc_name: &str, listed: &BTreeSet<String>) {
    let offered = options_offered(exe);

    let undocumented: Vec<&String> = offered.difference(listed).collect();
    assert!(
        undocumented.is_empty(),
        "{tool} offers {undocumented:?}, which {doc_name} does not mention"
    );
}

#[test]
fn the_readme_lists_every_option_tcslog_dump_offers() {
    let doc = document("README.md");
    check(
        env!("CARGO_BIN_EXE_tcslog-dump"),
        "tcslog-dump",
        "README.md",
        &long_options(&doc),
    );
}

#[test]
fn the_manual_lists_every_option_tcslog_dump_offers() {
    let doc = document("docs/tcslog-tools.rst");
    check(
        env!("CARGO_BIN_EXE_tcslog-dump"),
        "tcslog-dump",
        "docs/tcslog-tools.rst",
        &long_options(&doc),
    );
}

#[test]
fn the_readme_lists_every_option_tcslog_dumphdr_offers() {
    let doc = document("README.md");
    check(
        env!("CARGO_BIN_EXE_tcslog-dumphdr"),
        "tcslog-dumphdr",
        "README.md",
        &long_options(&doc),
    );
}

#[test]
fn the_manual_lists_every_option_tcslog_dumphdr_offers() {
    let doc = document("docs/tcslog-tools.rst");
    check(
        env!("CARGO_BIN_EXE_tcslog-dumphdr"),
        "tcslog-dumphdr",
        "docs/tcslog-tools.rst",
        &long_options(&doc),
    );
}

#[test]
fn neither_document_lists_an_option_no_tool_offers() {
    // The other direction: an option described after it was removed, or
    // one that never existed. Taken across both tools, since either
    // document may speak of either.
    let mut offered = options_offered(env!("CARGO_BIN_EXE_tcslog-dump"));
    offered.extend(options_offered(env!("CARGO_BIN_EXE_tcslog-dumphdr")));
    // The manual shows how to run the library's sample, which is a
    // cargo command line and so names a cargo option. Listed one by one
    // rather than guessed at: a cargo option appearing in a new command
    // line should fail this test and be added deliberately.
    let cargos: BTreeSet<String> = ["--example"].iter().map(|s| (*s).to_string()).collect();

    for name in ["README.md", "docs/tcslog-tools.rst"] {
        let doc = document(name);
        let stale: Vec<String> = long_options(&doc)
            .difference(&offered)
            .filter(|o| !cargos.contains(*o))
            .cloned()
            .collect();
        assert!(
            stale.is_empty(),
            "{name} describes {stale:?}, which no tool offers"
        );
    }
}
