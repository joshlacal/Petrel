//! `petrel`: the AT Protocol runtime for Petrel's Rust target.
//!
//! This crate mirrors the Swift Petrel runtime: an HTTP transport seam, the
//! XRPC request pipeline, identity resolution, the ES256 and DPoP primitives,
//! an OAuth client that can ask a client assertion backend (CAB) for a fresh
//! client assertion on every token request, secret storage and service auth.
//!
//! # Status
//!
//! Created by Lane 0 of the Petrel Rust program (plan:
//! `docs/execution-plans/2026-11-24-petrel-rust.md` in the Catbird+Petrel
//! workspace repo). Every module below is declared and documented, and the
//! interface contracts between lanes exist as compiling traits and types.
//! The implementations arrive in two lanes that work here at the same time:
//!
//! | Module | Owner | Contract it holds |
//! |---|---|---|
//! | [`rt`] | Lane D | [`rt::MaybeSend`], [`rt::MaybeSync`], [`rt::BoxFuture`] |
//! | [`net`] | Lane D | [`net::HttpTransport`], [`net::SendOptions`], [`net::TransportError`] |
//! | [`xrpc`] | Lane D | [`xrpc::AuthProvider`], [`xrpc::AuthCtx`] |
//! | [`identity`] | Lane D | none yet |
//! | [`crypto`] | Lane E | [`crypto::DpopSigner`] |
//! | [`oauth`] | Lane E | [`oauth::ClientAuth`] |
//! | [`storage`] | Lane E | [`storage::SecretStore`], [`storage::StoreError`] |
//! | [`service_auth`] | Lane E | none yet |
//!
//! **This file and `Cargo.toml` are shared: lanes do not edit them.** Each
//! lane adds submodules inside its own module directories.
//!
//! # Features
//!
//! - `native` (default): reqwest over rustls, tokio timers, hickory DNS.
//! - `wasm`: browser fetch, gloo timers, `getrandom`'s JS backend, DNS over
//!   HTTPS. No tokio anywhere on this path.
//! - `file-store`: the encrypted on-disk [`storage::SecretStore`].
//!
//! # Async without a runtime
//!
//! No `async-trait`. Traits called generically return
//! `impl Future + MaybeSend`; traits stored as `dyn` return
//! [`rt::BoxFuture`]. Both are `Send` on native targets and not on `wasm32`,
//! where browser futures cannot be.

pub mod account;
pub mod auth;
pub mod client;
pub mod crypto;
pub mod identity;
pub mod media;
pub mod net;
pub mod oauth;
pub mod rt;
pub mod service_auth;
pub mod storage;
pub mod xrpc;

pub use petrel_core as core;
