//! Identity resolution: handles, DIDs and DID documents.
//!
//! Stub created by Lane 0. Lane D owns this module (map:
//! `docs/execution-plans/2026-11-24-petrel-rust/maps/network-identity.md`,
//! packages I1 to I3) and adds:
//!
//! - the DID document model and the `did:web` and `did:plc` fetch rules;
//! - handle resolution over DNS TXT (`_atproto.<handle>`): hickory under the
//!   `native` feature, DNS over HTTPS under `wasm` (endpoint configurable,
//!   default Cloudflare; note that a DoH provider sees handle lookups), plus
//!   the HTTPS `/.well-known/atproto-did` fallback on both;
//! - the resolver with its cache and bidirectional handle verification.
//!
//! Requests to third-party hosts (handle hosts, `did:web` hosts, the PLC
//! directory) carry no credentials and no client headers.
