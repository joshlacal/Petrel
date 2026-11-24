//! AT Protocol OAuth scope grammar.
//!
//! Stub created by Lane 0. Lane C of the Petrel Rust program owns this crate
//! and ports `Sources/PetrelOAuthScopes` here (map:
//! `docs/execution-plans/2026-11-24-petrel-rust/maps/oauth-auth.md`, packages
//! O1 and O2):
//!
//! 1. First an opaque scope set: tokenize on a single space only, keep unknown
//!    tokens byte-exact, detect the `atproto` scope. This unblocks the OAuth
//!    client in the `petrel` crate.
//! 2. Then full grammar parity for the seven scope families.
//!
//! `space:` scopes pass through as opaque strings, byte-exact; they are not a
//! typed family (plan decision 9).
//!
//! This crate deliberately depends on nothing else in the workspace.
