//! `petrel-core`: the AT Protocol data model for Petrel's Rust target.
//!
//! This crate holds everything the generated API crate (`petrel-api`) and the
//! runtime crate (`petrel`) agree on, and nothing that needs a network or a
//! key: identifier newtypes, the data-model [`Value`], a strict DAG-CBOR codec,
//! the typed-to-[`Value`] bridge that generated types are written against, and
//! the XRPC endpoint traits.
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
pub mod service_ref;
pub mod subscription;
pub mod syntax;
pub mod tid;
pub mod unknown;
pub mod value;
pub mod xrpc;

pub use cid::Cid;
pub use datetime::Datetime;
pub use error::{CidError, DagCborError, DecodeError, EncodeError, SyntaxError, SyntaxKind};
pub use language::{Language, LanguageTag};
pub use serde_bridge::{
    FromValue, ObjectReader, ObjectWriter, ToValue, decode_value, from_dag_cbor,
    from_dag_cbor_strict, from_json, from_json_strict, to_dag_cbor, to_json,
};
pub use service_ref::{ServiceRef, ServiceRefError};
pub use subscription::{
    DecodedSubscriptionFrame, FrameError, FrameHeader, MAXIMUM_FRAME_BYTES, SubscriptionFrame,
    decode_frame, decode_frame_with, decode_subscription_frame, encode_frame,
    encode_subscription_error, encode_subscription_message,
};
pub use syntax::{
    AtIdentifier, AtUri, AtprotoMethod, CidString, Did, Handle, Nsid, RecordKey, SPACE_URI_PREFIX,
    SpaceRef, Tid, Uri,
};
pub use tid::TidGenerator;
pub use value::{Blob, Bytes, CidLink, Float, Nullable, Value};
pub use xrpc::{
    Collection, DeclaredXrpcError, FromQueryParams, RateLimit, RecordKeyType, ToQueryParams,
    XRPC_V1_JSON_SUBPROTOCOL, XrpcErrorBody, XrpcInput, XrpcMethod, XrpcOutput, XrpcRequest,
    XrpcSubscription,
};
