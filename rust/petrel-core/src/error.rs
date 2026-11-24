//! Error types for the data model.
//!
//! Lane A extends these (they are `#[non_exhaustive]` where growth is
//! expected) and ports the excerpt truncation from `ATProtoSyntax.swift` so an
//! error never echoes an oversized input.

use std::fmt;

/// Which identifier grammar rejected a string.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum SyntaxKind {
    /// `did` string format.
    Did,
    /// `handle` string format.
    Handle,
    /// `at-identifier` string format (a DID or a handle).
    AtIdentifier,
    /// `nsid` string format.
    Nsid,
    /// `at-uri` string format.
    AtUri,
    /// `space-ref` string format.
    SpaceRef,
    /// `uri` string format.
    Uri,
    /// `tid` string format.
    Tid,
    /// `record-key` string format.
    RecordKey,
    /// `datetime` string format.
    Datetime,
    /// `language` string format.
    Language,
    /// `cid` string format, or a binary CID.
    Cid,
}

impl fmt::Display for SyntaxKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::Did => "did",
            Self::Handle => "handle",
            Self::AtIdentifier => "at-identifier",
            Self::Nsid => "nsid",
            Self::AtUri => "at-uri",
            Self::SpaceRef => "space-ref",
            Self::Uri => "uri",
            Self::Tid => "tid",
            Self::RecordKey => "record-key",
            Self::Datetime => "datetime",
            Self::Language => "language",
            Self::Cid => "cid",
        })
    }
}

/// A string did not match its lexicon string format.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("invalid {kind}: {reason}")]
pub struct SyntaxError {
    /// The grammar that rejected the input.
    pub kind: SyntaxKind,
    /// Why, in words. Never contains the full input.
    pub reason: String,
}

impl SyntaxError {
    /// Builds a syntax error.
    pub fn new(kind: SyntaxKind, reason: impl Into<String>) -> Self {
        Self {
            kind,
            reason: reason.into(),
        }
    }
}

/// A CID could not be parsed or is not acceptable here.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum CidError {
    /// The bytes or the string are not a well-formed CIDv1.
    #[error("invalid CID: {0}")]
    Invalid(String),
}

/// Strict DAG-CBOR decoding refused the input.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum DagCborError {
    /// Input ended inside an item.
    #[error("unexpected end of input")]
    UnexpectedEof,
    /// Bytes remain after the single top-level item.
    #[error("trailing bytes after the top-level item")]
    TrailingBytes,
    /// A float (half, single or double) was found. The data model has none.
    #[error("floats are not allowed in the AT Protocol data model")]
    FloatNotAllowed,
    /// An integer does not fit in a signed 64-bit value.
    #[error("integer outside the signed 64-bit range")]
    IntegerOutOfRange,
    /// An integer or a length was not in its shortest form.
    #[error("integer or length is not minimally encoded")]
    NonMinimalEncoding,
    /// An indefinite-length item was found.
    #[error("indefinite-length items are not allowed")]
    IndefiniteLength,
    /// A map key is not a text string.
    #[error("map keys must be text strings")]
    NonStringKey,
    /// Map keys are not in canonical (length, then bytewise) order, or repeat.
    #[error("map keys are not in strictly increasing canonical order")]
    KeyOrder,
    /// A text string is not valid UTF-8.
    #[error("text string is not valid UTF-8")]
    InvalidUtf8,
    /// A tag other than 42 was found.
    #[error("unsupported CBOR tag {0}")]
    UnsupportedTag(u64),
    /// Tag 42 did not wrap a valid binary CID with the 0x00 prefix.
    #[error("invalid CID link: {0}")]
    InvalidLink(String),
    /// A simple value other than false, true or null, or a reserved head.
    #[error("unsupported CBOR simple value or reserved head 0x{0:02x}")]
    Unsupported(u8),
    /// Nesting is deeper than the limit.
    #[error("nesting deeper than {0} levels")]
    DepthExceeded(usize),
    /// A declared length is larger than the remaining input.
    #[error("declared length exceeds the remaining input")]
    LengthExceedsInput,
}

/// A wire value could not be turned into a typed value.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum DecodeError {
    /// A required key is absent.
    #[error("missing required field `{0}`")]
    MissingField(String),
    /// A value has the wrong data-model kind.
    #[error("expected {expected}, found {found}")]
    TypeMismatch {
        /// What the type needed.
        expected: &'static str,
        /// What the wire carried.
        found: &'static str,
    },
    /// A string did not match its format.
    #[error(transparent)]
    Syntax(#[from] SyntaxError),
    /// A CID was malformed.
    #[error(transparent)]
    Cid(#[from] CidError),
    /// The DAG-CBOR bytes were refused.
    #[error(transparent)]
    DagCbor(#[from] DagCborError),
    /// The JSON text was refused (syntax error, float, duplicate key, ...).
    #[error("invalid JSON: {0}")]
    Json(String),
    /// A union member has no `$type`, or it is not a string.
    #[error("union value has no `$type`")]
    MissingType,
    /// A closed union met a `$type` it does not list.
    #[error("unknown `$type` `{0}` in a closed union")]
    UnknownType(String),
    /// Decoding a named field failed.
    #[error("field `{field}`: {source}")]
    Field {
        /// The wire name of the field.
        field: String,
        /// What went wrong inside it.
        source: Box<DecodeError>,
    },
    /// Anything else, in words.
    #[error("{0}")]
    Custom(String),
}

impl DecodeError {
    /// Wraps an error with the wire name of the field it happened in.
    #[must_use]
    pub fn in_field(self, field: &str) -> Self {
        Self::Field {
            field: field.to_owned(),
            source: Box::new(self),
        }
    }
}

/// A typed value could not be written to the wire.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum EncodeError {
    /// The value breaks a rule that is only checked on write.
    #[error("{0}")]
    Custom(String),
    /// Encoding a named field failed.
    #[error("field `{field}`: {source}")]
    Field {
        /// The wire name of the field.
        field: String,
        /// What went wrong inside it.
        source: Box<EncodeError>,
    },
}
