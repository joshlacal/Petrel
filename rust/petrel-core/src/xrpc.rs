//! XRPC endpoint traits: the seam between generated code and the runtime.
//!
//! The generator emits one zero-sized type per query or procedure and
//! implements [`XrpcRequest`] for it. The runtime (`petrel::xrpc`) exposes a
//! single generic `XrpcClient::send::<R>(params, input, &CallOptions)` and
//! needs nothing else from the generated crate. Overlay crates such as
//! `petrel-catbird` implement the same trait for their own endpoint types,
//! which sidesteps the orphan rule.
//!
//! Nothing here does I/O. Query *string* encoding (percent-encoding, `+` as
//! `%2B`) belongs to the runtime; this module only produces name/value pairs.
//!
//! Lane A (work package C11) adds rate-limit header parsing and any missing
//! [`QueryValue`] impls.

use std::fmt;

use crate::{Cid, Nsid, RecordKey, Tid};

use crate::error::{DecodeError, EncodeError};
use crate::serde_bridge::{FromValue, ObjectReader, ToValue, from_json, to_json};
use crate::value::{Bytes, Value};

/// Whether an endpoint is an HTTP GET or POST.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum XrpcMethod {
    /// Lexicon `query`: HTTP GET.
    Query,
    /// Lexicon `procedure`: HTTP POST.
    Procedure,
}

/// One XRPC endpoint. Implemented by generated code, consumed by the runtime.
pub trait XrpcRequest {
    /// The endpoint's NSID, for example `com.atproto.repo.getRecord`.
    const NSID: &'static str;
    /// Query or procedure.
    const METHOD: XrpcMethod;
    /// The lexicon `input.encoding`, if the endpoint takes a body. For a blob
    /// upload (`*/*`) the caller supplies the real content type per call.
    const INPUT_ENCODING: Option<&'static str>;
    /// The lexicon `output.encoding`, if the endpoint returns a body.
    const OUTPUT_ENCODING: Option<&'static str>;
    /// Query parameters. `()` when the endpoint has none.
    type Params: ToQueryParams;
    /// Request body: `()` for none, a generated struct for JSON, or
    /// [`Bytes`] for a binary body.
    type Input: XrpcInput;
    /// Response body: `()` for none, a generated struct for JSON, or
    /// [`Bytes`] for a binary or schemaless body.
    type Output: XrpcOutput;
    /// The endpoint's declared errors.
    type Error: DeclaredXrpcError;
}

/// A record type and its collection.
pub trait Collection {
    /// The collection NSID, which is also the record's `$type`.
    const NSID: &'static str;
    /// The lexicon record key type.
    const KEY: RecordKeyType;
}

/// The lexicon `key` of a record definition.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RecordKeyType {
    /// `tid`.
    Tid,
    /// `nsid`.
    Nsid,
    /// `any`.
    Any,
    /// `literal:<value>`, for example `literal:self`. Holds the value.
    Literal(&'static str),
    /// A key rule newer than this SDK. Only generic key syntax is checked.
    Other(&'static str),
}

impl RecordKeyType {
    /// Whether the value is a valid key for this collection.
    pub fn accepts(self, value: &str) -> bool {
        RecordKey::parse(value).is_ok()
            && match self {
                Self::Tid => Tid::parse(value).is_ok(),
                Self::Nsid => Nsid::parse(value).is_ok(),
                Self::Literal(literal) => value == literal,
                Self::Any | Self::Other(_) => true,
            }
    }
}

/// A request body.
///
/// Implemented here for `()` (no body) and [`Bytes`] (sent as is). The
/// generator implements it for each JSON input struct with [`json_body`].
pub trait XrpcInput {
    /// The bytes to send, or `None` for no body.
    fn into_body(self) -> Result<Option<Vec<u8>>, EncodeError>;
}

impl XrpcInput for () {
    fn into_body(self) -> Result<Option<Vec<u8>>, EncodeError> {
        Ok(None)
    }
}

impl XrpcInput for Bytes {
    fn into_body(self) -> Result<Option<Vec<u8>>, EncodeError> {
        Ok(Some(self.0))
    }
}

/// Body of a generated `XrpcInput::into_body` for a JSON input.
pub fn json_body<T: ToValue>(input: &T) -> Result<Option<Vec<u8>>, EncodeError> {
    to_json(input).map(Some)
}

/// A response body.
///
/// Implemented here for `()` (body ignored) and [`Bytes`] (taken as is). The
/// generator implements it for each JSON output struct with
/// [`from_json`](crate::from_json).
pub trait XrpcOutput: Sized {
    /// Decodes a successful response body.
    fn from_body(body: &[u8]) -> Result<Self, DecodeError>;
}

impl XrpcOutput for () {
    fn from_body(_: &[u8]) -> Result<Self, DecodeError> {
        Ok(())
    }
}

impl XrpcOutput for Bytes {
    fn from_body(body: &[u8]) -> Result<Self, DecodeError> {
        Ok(Self(body.to_vec()))
    }
}

/// The error names an endpoint declares in its lexicon.
///
/// The generator emits one enum per endpoint with a variant per declared
/// name and a final `Unknown(String)` variant, so mapping a wire name never
/// fails. Endpoints that declare nothing use [`UndeclaredError`].
pub trait DeclaredXrpcError: Sized + fmt::Debug {
    /// Maps the `error` string of an XRPC error body.
    fn from_wire_name(name: &str) -> Self;
    /// The wire name: the declared name, or the unknown string as received.
    fn wire_name(&self) -> &str;
    /// False for the `Unknown` variant.
    fn is_declared(&self) -> bool;
}

/// The error type of an endpoint that declares no errors: just the name the
/// server sent.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct UndeclaredError(pub String);

impl DeclaredXrpcError for UndeclaredError {
    fn from_wire_name(name: &str) -> Self {
        Self(name.to_owned())
    }

    fn wire_name(&self) -> &str {
        &self.0
    }

    fn is_declared(&self) -> bool {
        false
    }
}

/// The JSON body of an XRPC error response: `{"error", "message"}`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct XrpcErrorBody {
    /// The error name.
    pub error: String,
    /// Optional human-readable detail.
    pub message: Option<String>,
}

impl XrpcErrorBody {
    /// Parses an error body. Returns `None` when the body is not a JSON
    /// object with a string `error`.
    pub fn parse(body: &[u8]) -> Option<Self> {
        from_json(body).ok()
    }
}

impl FromValue for XrpcErrorBody {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        let mut reader = ObjectReader::new(value)?;
        Ok(Self {
            error: reader.required("error")?,
            message: reader.optional("message"),
        })
    }
}

impl ToValue for XrpcErrorBody {
    fn to_value(&self) -> Result<Value, EncodeError> {
        let mut writer = crate::serde_bridge::ObjectWriter::new();
        writer.field("error", &self.error)?;
        writer.optional("message", &self.message)?;
        Ok(writer.finish())
    }
}

crate::value::serde_via_value!(XrpcErrorBody);

/// Rate-limit state reported in an XRPC response.
#[derive(Clone, Debug, PartialEq)]
pub struct RateLimit {
    /// The request quota for the current window.
    pub limit: i64,
    /// Requests left in the current window.
    pub remaining: i64,
    /// The window's end, in seconds since the Unix epoch.
    pub reset_unix_seconds: f64,
    /// The optional server-supplied description of the rate-limit window.
    pub policy: Option<String>,
}

impl RateLimit {
    /// Reads the response headers through an accessor keyed by lowercase name.
    /// Returns None if limit, remaining or reset is absent or malformed.
    pub fn parse<'a>(get: impl Fn(&str) -> Option<&'a str>) -> Option<Self> {
        let limit = get("ratelimit-limit")?.trim().parse().ok()?;
        let remaining = get("ratelimit-remaining")?.trim().parse().ok()?;
        let reset_unix_seconds: f64 = get("ratelimit-reset")?.trim().parse().ok()?;
        if !reset_unix_seconds.is_finite() {
            return None;
        }
        let policy = get("ratelimit-policy").map(str::to_owned);
        Some(Self {
            limit,
            remaining,
            reset_unix_seconds,
            policy,
        })
    }
}

/// Query parameters of one endpoint, as ordered name/value pairs.
///
/// The generator writes each impl out explicitly with the helpers below;
/// there is no reflection. Rules (from the Swift generator): an absent
/// optional emits nothing, an array emits one pair per element, booleans are
/// `true`/`false`, integers are decimal, and string formats keep their wire spelling except for handles in query
/// parameters, which are lowercased. A lexicon `default` is the field's value in the generated
/// `Default` impl and is therefore *sent*.
pub trait ToQueryParams {
    /// Appends this endpoint's pairs, in lexicon property order.
    fn to_query_params(&self, out: &mut Vec<(&'static str, String)>);
}

impl ToQueryParams for () {
    fn to_query_params(&self, _: &mut Vec<(&'static str, String)>) {}
}

/// A type that can be one query parameter value.
pub trait QueryValue {
    /// The unencoded value text.
    fn to_query_value(&self) -> String;
}

impl QueryValue for String {
    fn to_query_value(&self) -> String {
        self.clone()
    }
}

impl QueryValue for bool {
    fn to_query_value(&self) -> String {
        self.to_string()
    }
}

impl QueryValue for i64 {
    fn to_query_value(&self) -> String {
        self.to_string()
    }
}

impl QueryValue for Cid {
    fn to_query_value(&self) -> String {
        self.to_string()
    }
}

/// Appends a required parameter.
pub fn push_param(
    out: &mut Vec<(&'static str, String)>,
    name: &'static str,
    value: &impl QueryValue,
) {
    out.push((name, value.to_query_value()));
}

/// Appends an optional parameter, or nothing.
pub fn push_optional_param(
    out: &mut Vec<(&'static str, String)>,
    name: &'static str,
    value: Option<&impl QueryValue>,
) {
    if let Some(value) = value {
        push_param(out, name, value);
    }
}

/// Appends an array parameter as one pair per element.
pub fn push_array_param(
    out: &mut Vec<(&'static str, String)>,
    name: &'static str,
    values: &[impl QueryValue],
) {
    for value in values {
        push_param(out, name, value);
    }
}
