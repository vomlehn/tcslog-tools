//! The crate's documentation is its README, included below.
//!
//! These are two command-line programs, so this library target exists
//! only to carry that documentation: it exports nothing and no
//! dependent has reason to link it. Without it the crate has no
//! library to document, and docs.rs has no page for the crate at all
//! -- only one per binary, which is not where anyone looks first.
//!
//! The README is included rather than copied so that the two cannot
//! drift. It is what crates.io renders as well, so one text serves
//! both.
#![doc = include_str!("../README.md")]
