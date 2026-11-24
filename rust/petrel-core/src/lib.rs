//! `petrel-core`: the AT Protocol data model for Petrel's Rust target.
//!
//! This crate holds everything the generated API crate (`petrel-api`) and the
//! runtime crate (`petrel`) agree on, and nothing that needs a network or a
//! key: identifier newtypes, the data-model [`Value`], a strict DAG-CBOR codec,
//! the typed-to-[`Value`] bridge that generated types are written against, and
//! the XRPC endpoint traits.
//!
//! # Status
//!
//! Created by Lane 0 of the Petrel Rust program (plan:
//! `docs/execution-plans/2026-11-24-petrel-rust.md` in the Catbird+Petrel
//! workspace repo). Lane 0 froze the public names and proved the serialization
//! design with the `spike` integration test. Lane A owns this crate from here
//! and replaces the minimal bodies (identifier validators, datetime and
//! language parsers, decode limits, the TID generator) with full ports of the
//! Swift runtime, without renaming anything exported below.
//!
//! # One model, two codecs
//!
//! Every generated type implements [`ToValue`] and [`FromValue`]. JSON and
//! DAG-CBOR are both reached through [`Value`]:
//!
//! ```text
//!   typed struct  <-- FromValue / ToValue -->  Value  <-->  JSON text
//!                                                     <-->  DAG-CBOR bytes
//! ```
//!
//! [`to_json`], [`from_json`], [`to_dag_cbor`] and [`from_dag_cbor`] are the
//! four entry points. Because nothing passes through serde's private buffering
//! (`#[serde(flatten)]`, internally tagged enums), a `$link` stays a CID link
//! (CBOR tag 42) and `$bytes` stays a byte string in both directions.

pub mod cid;
pub mod dagcbor;
pub mod datetime;
pub mod error;
pub mod language;
pub mod serde_bridge;
pub mod syntax;
pub mod tid;
pub mod unknown;
pub mod value;
pub mod xrpc;

pub use cid::Cid;
pub use datetime::Datetime;
pub use error::{CidError, DagCborError, DecodeError, EncodeError, SyntaxError, SyntaxKind};
pub use language::Language;
pub use serde_bridge::{
    FromValue, ObjectReader, ObjectWriter, ToValue, from_dag_cbor, from_json, to_dag_cbor, to_json,
};
pub use syntax::{
    AtIdentifier, AtUri, CidString, Did, Handle, Nsid, RecordKey, SpaceRef, Tid, Uri,
};
pub use value::{Blob, Bytes, CidLink, Nullable, Value};
pub use xrpc::{
    Collection, DeclaredXrpcError, RecordKeyType, ToQueryParams, XrpcInput, XrpcMethod, XrpcOutput,
    XrpcRequest,
};
