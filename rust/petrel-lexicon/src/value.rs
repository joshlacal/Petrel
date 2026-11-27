//! AT Protocol Lexicon Data Model values with strict JSON and DAG-CBOR codecs.

use std::collections::BTreeMap;
use std::fmt;
use std::ops::Deref;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD_NO_PAD;
use petrel_core::{Cid, DecodeError, EncodeError, FromValue, ToValue, Value};
use thiserror::Error;

/// Options controlling strict AT Protocol Data Model decoding.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ParseOptions {
    /// Maximum allowed nesting depth for arrays and objects (default `128`).
    pub maximum_depth: usize,
    /// When `true`, blobs (`{"$type":"blob",...}`) must reference a `raw` codec CID (`0x55`).
    pub require_raw_blob_cids: bool,
    /// When `true`, all CID links must be "blessed" ATProto CIDv1s (`sha2-256`, `raw` or `dag-cbor`).
    pub require_blessed_cids: bool,
}

impl ParseOptions {
    /// Standard AT Protocol Lexicon Data Model options (`maximum_depth: 128`,
    /// `require_raw_blob_cids: false`, `require_blessed_cids: true`).
    pub const fn standard() -> Self {
        Self {
            maximum_depth: 128,
            require_raw_blob_cids: false,
            require_blessed_cids: true,
        }
    }

    /// Strict options also requiring `raw` (`0x55`) codec CIDs on blob references.
    pub const fn strict() -> Self {
        Self {
            maximum_depth: 128,
            require_raw_blob_cids: true,
            require_blessed_cids: true,
        }
    }
}

impl Default for ParseOptions {
    fn default() -> Self {
        Self::standard()
    }
}

/// Errors produced when decoding or encoding [`LexValue`] in JSON or DAG-CBOR.
#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum LexValueError {
    /// Input bytes are not valid UTF-8 or contain disallowed encoding artifacts (such as a BOM).
    #[error("invalid UTF-8 JSON input: {message}")]
    InvalidUtf8 {
        /// Human-readable description of the encoding error.
        message: String,
    },

    /// Malformed JSON syntax at the given JSON-pointer path.
    #[error("invalid JSON at {path}: {message}")]
    InvalidJson {
        /// JSON-pointer path (`""` for root).
        path: String,
        /// Description of the syntax error.
        message: String,
    },

    /// Duplicate object key encountered at the given JSON-pointer path.
    #[error("duplicate key {key:?} at {path}")]
    DuplicateKey {
        /// JSON-pointer path to the containing object.
        path: String,
        /// The duplicated property key.
        key: String,
    },

    /// Nesting exceeded `ParseOptions::maximum_depth`.
    #[error("maximum nesting depth {limit} exceeded at {path}")]
    DepthExceeded {
        /// JSON-pointer path where depth overflowed.
        path: String,
        /// Configured limit.
        limit: usize,
    },

    /// A JSON or CBOR number is non-integer or out of signed 64-bit integer range.
    #[error("invalid integer at {path}: {message}")]
    InvalidNumber {
        /// JSON-pointer path.
        path: String,
        /// Reason the number was rejected.
        message: String,
    },

    /// Malformed `$bytes` special object or invalid unpadded base64 payload.
    #[error("invalid $bytes encoding at {path}: {message}")]
    InvalidBytesEncoding {
        /// JSON-pointer path.
        path: String,
        /// Description of the `$bytes` violation.
        message: String,
    },

    /// Malformed `$link` special object or invalid/unblessed CID string.
    #[error("invalid $link CID at {path}: {message}")]
    InvalidLink {
        /// JSON-pointer path.
        path: String,
        /// Description of the `$link` violation.
        message: String,
    },

    /// Invalid `$type` property or malformed `$type: "blob"` object.
    #[error("invalid data model object at {path}: {message}")]
    InvalidObject {
        /// JSON-pointer path.
        path: String,
        /// Description of the structural violation.
        message: String,
    },

    /// Malformed or non-canonical DAG-CBOR input.
    #[error("invalid DAG-CBOR at {path}: {message}")]
    InvalidCbor {
        /// JSON-pointer path.
        path: String,
        /// Description of the DAG-CBOR rule violated.
        message: String,
    },
}

/// Decoded AT Protocol blob metadata (`{"$type": "blob", "ref": <cid>, "mimeType": ..., "size": ...}`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LexBlobRef {
    /// Content identifier for the blob bytes.
    pub r#ref: Cid,
    /// Non-empty MIME media type string.
    pub mime_type: String,
    /// Non-negative byte size of the blob.
    pub size: i64,
}

impl LexBlobRef {
    /// Construct a new blob reference.
    pub fn new(r#ref: Cid, mime_type: impl Into<String>, size: i64) -> Self {
        Self {
            r#ref,
            mime_type: mime_type.into(),
            size,
        }
    }

    /// Parse and validate a blob object from a [`petrel_core::Value`] map.
    pub fn from_object(
        object: &BTreeMap<String, Value>,
        options: &ParseOptions,
        path: &str,
    ) -> Result<Self, LexValueError> {
        let Some(Value::String(kind)) = object.get("$type") else {
            return Err(LexValueError::InvalidObject {
                path: path.to_owned(),
                message: "blob object must have string $type".to_owned(),
            });
        };
        if kind != "blob" {
            return Err(LexValueError::InvalidObject {
                path: path.to_owned(),
                message: format!("expected $type == \"blob\", got {kind:?}"),
            });
        }
        let cid = match object.get("ref") {
            Some(Value::Link(cid)) => cid.clone(),
            Some(_) => {
                return Err(LexValueError::InvalidObject {
                    path: join_pointer(path, "ref"),
                    message: "blob 'ref' must be a CID link".to_owned(),
                });
            }
            None => {
                return Err(LexValueError::InvalidObject {
                    path: path.to_owned(),
                    message: "blob object is missing 'ref'".to_owned(),
                });
            }
        };
        if options.require_blessed_cids && !cid.is_blessed() {
            return Err(LexValueError::InvalidLink {
                path: join_pointer(path, "ref"),
                message: "blob CID is not a blessed ATProto CIDv1".to_owned(),
            });
        }
        if options.require_raw_blob_cids && cid.codec() != Cid::CODEC_RAW {
            return Err(LexValueError::InvalidLink {
                path: join_pointer(path, "ref"),
                message: format!("blob CID codec must be raw (0x55), got 0x{:x}", cid.codec()),
            });
        }
        let mime_type = match object.get("mimeType") {
            Some(Value::String(mime)) if !mime.is_empty() => mime.clone(),
            Some(Value::String(_)) => {
                return Err(LexValueError::InvalidObject {
                    path: join_pointer(path, "mimeType"),
                    message: "blob 'mimeType' must be non-empty".to_owned(),
                });
            }
            Some(_) => {
                return Err(LexValueError::InvalidObject {
                    path: join_pointer(path, "mimeType"),
                    message: "blob 'mimeType' must be a string".to_owned(),
                });
            }
            None => {
                return Err(LexValueError::InvalidObject {
                    path: path.to_owned(),
                    message: "blob object is missing 'mimeType'".to_owned(),
                });
            }
        };
        let size = match object.get("size") {
            Some(Value::Integer(n)) if *n >= 0 => *n,
            Some(Value::Integer(_)) => {
                return Err(LexValueError::InvalidObject {
                    path: join_pointer(path, "size"),
                    message: "blob 'size' must be non-negative".to_owned(),
                });
            }
            Some(_) => {
                return Err(LexValueError::InvalidObject {
                    path: join_pointer(path, "size"),
                    message: "blob 'size' must be an integer".to_owned(),
                });
            }
            None => {
                return Err(LexValueError::InvalidObject {
                    path: path.to_owned(),
                    message: "blob object is missing 'size'".to_owned(),
                });
            }
        };
        Ok(Self {
            r#ref: cid,
            mime_type,
            size,
        })
    }

    /// Encode this blob reference as a [`petrel_core::Value::Object`].
    pub fn to_value(&self) -> Value {
        let mut map = BTreeMap::new();
        map.insert("$type".to_owned(), Value::String("blob".to_owned()));
        map.insert("ref".to_owned(), Value::Link(self.r#ref.clone()));
        map.insert("mimeType".to_owned(), Value::String(self.mime_type.clone()));
        map.insert("size".to_owned(), Value::Integer(self.size));
        Value::Object(map)
    }
}

/// Wrapper around [`petrel_core::Value`] providing strict AT Protocol JSON and DAG-CBOR
/// parsing/encoding with full path diagnostics and configurable [`ParseOptions`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LexValue(pub Value);

impl LexValue {
    /// Construct a `null` value.
    pub const fn null() -> Self {
        Self(Value::Null)
    }

    /// Construct a boolean value.
    pub const fn boolean(value: bool) -> Self {
        Self(Value::Bool(value))
    }

    /// Construct an integer value.
    pub const fn integer(value: i64) -> Self {
        Self(Value::Integer(value))
    }

    /// Construct a string value.
    pub fn string(value: impl Into<String>) -> Self {
        Self(Value::String(value.into()))
    }

    /// Construct a bytes value.
    pub const fn bytes(value: Vec<u8>) -> Self {
        Self(Value::Bytes(value))
    }

    /// Construct a CID link value.
    pub const fn link(cid: Cid) -> Self {
        Self(Value::Link(cid))
    }

    /// Construct an array value.
    pub const fn array(items: Vec<Value>) -> Self {
        Self(Value::Array(items))
    }

    /// Construct an object value.
    pub const fn object(fields: BTreeMap<String, Value>) -> Self {
        Self(Value::Object(fields))
    }

    /// Wrap an existing [`petrel_core::Value`].
    pub const fn from_value(value: Value) -> Self {
        Self(value)
    }

    /// Unwrap the underlying [`petrel_core::Value`].
    pub fn into_value(self) -> Value {
        self.0
    }

    /// Borrow the underlying [`petrel_core::Value`].
    pub const fn inner(&self) -> &Value {
        &self.0
    }

    /// Encode any generated Petrel type implementing [`petrel_core::ToValue`] into a [`LexValue`].
    pub fn from_encoding<T: ToValue>(value: &T) -> Result<Self, EncodeError> {
        value.to_value().map(Self)
    }

    /// Decode a generated Petrel type implementing [`petrel_core::FromValue`] (lenient output rules).
    pub fn decode<T: FromValue>(&self) -> Result<T, DecodeError> {
        T::from_value(self.0.clone())
    }

    /// Decode a generated Petrel type using strict wire rules (`from_value_strict`).
    pub fn decode_strict<T: FromValue>(&self) -> Result<T, DecodeError> {
        T::from_value_strict(self.0.clone())
    }

    /// Compute the DAG-CBOR SHA-256 CIDv1 for this value.
    pub fn cid(&self) -> Cid {
        self.0.cid()
    }

    /// Extract a [`LexBlobRef`] if this value is an object with `"$type": "blob"`.
    pub fn as_blob_ref(&self, options: &ParseOptions) -> Result<Option<LexBlobRef>, LexValueError> {
        let Value::Object(map) = &self.0 else {
            return Ok(None);
        };
        if matches!(map.get("$type"), Some(Value::String(s)) if s == "blob") {
            LexBlobRef::from_object(map, options, "").map(Some)
        } else {
            Ok(None)
        }
    }

    /// Parse AT Protocol Lexicon Data Model JSON bytes.
    pub fn from_json_bytes(bytes: &[u8], options: ParseOptions) -> Result<Self, LexValueError> {
        if bytes.starts_with(&[0xEF, 0xBB, 0xBF]) {
            return Err(LexValueError::InvalidUtf8 {
                message: "UTF-8 BOM is not permitted in JSON".to_owned(),
            });
        }
        let text = std::str::from_utf8(bytes).map_err(|err| LexValueError::InvalidUtf8 {
            message: err.to_string(),
        })?;
        let mut parser = JsonParser::new(text, options);
        let value = parser.parse_root()?;
        Ok(Self(value))
    }

    /// Parse a top-level AT Protocol record JSON object (must be a JSON object at root).
    pub fn from_record_json_bytes(
        bytes: &[u8],
        options: ParseOptions,
    ) -> Result<Self, LexValueError> {
        let parsed = Self::from_json_bytes(bytes, options)?;
        if !matches!(parsed.0, Value::Object(_)) {
            return Err(LexValueError::InvalidObject {
                path: String::new(),
                message: format!("expected top-level object, got {}", parsed.0.kind()),
            });
        }
        Ok(parsed)
    }

    /// Serialize to compact AT Protocol Data Model JSON bytes.
    pub fn to_json_bytes(&self) -> Vec<u8> {
        let mut out = String::new();
        write_json_value(&self.0, &mut out);
        out.into_bytes()
    }

    /// Serialize to compact AT Protocol Data Model JSON string.
    pub fn to_json_string(&self) -> String {
        let mut out = String::new();
        write_json_value(&self.0, &mut out);
        out
    }

    /// Parse strict canonical DAG-CBOR bytes.
    pub fn from_dag_cbor(bytes: &[u8], options: ParseOptions) -> Result<Self, LexValueError> {
        let mut decoder = CborDecoder::new(bytes, options);
        let value = decoder.decode_root()?;
        Ok(Self(value))
    }

    /// Parse a top-level AT Protocol record from strict canonical DAG-CBOR bytes.
    pub fn from_record_dag_cbor(
        bytes: &[u8],
        options: ParseOptions,
    ) -> Result<Self, LexValueError> {
        let parsed = Self::from_dag_cbor(bytes, options)?;
        if !matches!(parsed.0, Value::Object(_)) {
            return Err(LexValueError::InvalidObject {
                path: String::new(),
                message: format!("expected top-level object, got {}", parsed.0.kind()),
            });
        }
        Ok(parsed)
    }

    /// Encode to canonical DAG-CBOR bytes.
    pub fn to_dag_cbor(&self) -> Vec<u8> {
        petrel_core::dagcbor::encode(&self.0)
    }
}

impl From<Value> for LexValue {
    fn from(value: Value) -> Self {
        Self(value)
    }
}

impl From<LexValue> for Value {
    fn from(value: LexValue) -> Self {
        value.0
    }
}

impl AsRef<Value> for LexValue {
    fn as_ref(&self) -> &Value {
        &self.0
    }
}

impl Deref for LexValue {
    type Target = Value;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl ToValue for LexValue {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(self.0.clone())
    }
}

impl FromValue for LexValue {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        Ok(Self(value))
    }
}

impl serde::Serialize for LexValue {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        self.0.serialize(serializer)
    }
}

impl<'de> serde::Deserialize<'de> for LexValue {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        Value::deserialize(deserializer).map(Self)
    }
}

impl fmt::Display for LexValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.to_json_string())
    }
}

pub(crate) fn join_pointer(base: &str, segment: &str) -> String {
    let mut out = String::with_capacity(base.len() + 1 + segment.len());
    out.push_str(base);
    out.push('/');
    for ch in segment.chars() {
        match ch {
            '~' => out.push_str("~0"),
            '/' => out.push_str("~1"),
            _ => out.push(ch),
        }
    }
    out
}

fn validate_object_special_markers(
    map: &BTreeMap<String, Value>,
    options: &ParseOptions,
    path: &str,
) -> Result<Option<Value>, LexValueError> {
    if let Some(raw_bytes) = map.get("$bytes") {
        if map.len() != 1 {
            return Err(LexValueError::InvalidBytesEncoding {
                path: path.to_owned(),
                message: "$bytes object must not contain additional keys".to_owned(),
            });
        }
        let Value::String(encoded) = raw_bytes else {
            return Err(LexValueError::InvalidBytesEncoding {
                path: join_pointer(path, "$bytes"),
                message: "$bytes value must be a base64 string".to_owned(),
            });
        };
        let decoded = decode_strict_unpadded_base64(encoded).map_err(|msg| {
            LexValueError::InvalidBytesEncoding {
                path: join_pointer(path, "$bytes"),
                message: msg,
            }
        })?;
        return Ok(Some(Value::Bytes(decoded)));
    }

    if let Some(raw_link) = map.get("$link") {
        if map.len() != 1 {
            return Err(LexValueError::InvalidLink {
                path: path.to_owned(),
                message: "$link object must not contain additional keys".to_owned(),
            });
        }
        let Value::String(cid_str) = raw_link else {
            return Err(LexValueError::InvalidLink {
                path: join_pointer(path, "$link"),
                message: "$link value must be a CID string".to_owned(),
            });
        };
        let cid = if options.require_blessed_cids {
            Cid::parse_blessed(cid_str)
        } else {
            Cid::parse(cid_str)
        }
        .map_err(|err| LexValueError::InvalidLink {
            path: join_pointer(path, "$link"),
            message: err.to_string(),
        })?;
        return Ok(Some(Value::Link(cid)));
    }

    validate_typed_object(map, options, path)?;
    Ok(None)
}

fn validate_typed_object(
    map: &BTreeMap<String, Value>,
    options: &ParseOptions,
    path: &str,
) -> Result<(), LexValueError> {
    if let Some(type_val) = map.get("$type") {
        let Value::String(kind) = type_val else {
            return Err(LexValueError::InvalidObject {
                path: join_pointer(path, "$type"),
                message: "$type must be a non-empty string".to_owned(),
            });
        };
        if kind.is_empty() {
            return Err(LexValueError::InvalidObject {
                path: join_pointer(path, "$type"),
                message: "$type must not be empty".to_owned(),
            });
        }
        if kind == "blob" {
            LexBlobRef::from_object(map, options, path)?;
        }
    }
    Ok(())
}

const UNPAD_DECODER: base64::engine::GeneralPurpose = base64::engine::GeneralPurpose::new(
    &base64::alphabet::STANDARD,
    base64::engine::GeneralPurposeConfig::new()
        .with_decode_padding_mode(base64::engine::DecodePaddingMode::RequireNone)
        .with_decode_allow_trailing_bits(true),
);

fn decode_strict_unpadded_base64(input: &str) -> Result<Vec<u8>, String> {
    if input.contains('=') {
        return Err("unpadded base64 must not include '=' padding".to_owned());
    }
    if input.bytes().any(|b| b.is_ascii_whitespace()) {
        return Err("base64 must not contain whitespace".to_owned());
    }
    UNPAD_DECODER
        .decode(input.as_bytes())
        .map_err(|err| err.to_string())
}

// ============================================================================
// Strict JSON parser (RFC 8259 + ATProto Data Model)
// ============================================================================

struct JsonParser<'a> {
    src: &'a str,
    bytes: &'a [u8],
    pos: usize,
    options: ParseOptions,
}

impl<'a> JsonParser<'a> {
    const fn new(src: &'a str, options: ParseOptions) -> Self {
        Self {
            src,
            bytes: src.as_bytes(),
            pos: 0,
            options,
        }
    }

    fn parse_root(&mut self) -> Result<Value, LexValueError> {
        self.skip_ws();
        let value = self.parse_value(0, "")?;
        self.skip_ws();
        if self.pos != self.bytes.len() {
            return Err(LexValueError::InvalidJson {
                path: String::new(),
                message: format!("unexpected trailing data at byte offset {}", self.pos),
            });
        }
        Ok(value)
    }

    fn skip_ws(&mut self) {
        while self.pos < self.bytes.len() {
            match self.bytes[self.pos] {
                b' ' | b'\t' | b'\r' | b'\n' => self.pos += 1,
                _ => break,
            }
        }
    }

    fn peek(&self) -> Option<u8> {
        self.bytes.get(self.pos).copied()
    }

    fn parse_value(&mut self, depth: usize, path: &str) -> Result<Value, LexValueError> {
        self.skip_ws();
        let Some(byte) = self.peek() else {
            return Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "unexpected end of JSON input".to_owned(),
            });
        };
        match byte {
            b'n' => {
                self.expect_literal(b"null", path)?;
                Ok(Value::Null)
            }
            b't' => {
                self.expect_literal(b"true", path)?;
                Ok(Value::Bool(true))
            }
            b'f' => {
                self.expect_literal(b"false", path)?;
                Ok(Value::Bool(false))
            }
            b'"' => self.parse_string(path).map(Value::String),
            b'[' => self.parse_array(depth, path),
            b'{' => self.parse_object(depth, path),
            b'-' | b'0'..=b'9' => self.parse_number(path).map(Value::Integer),
            _ => Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: format!("unexpected byte 0x{byte:02x}"),
            }),
        }
    }

    fn expect_literal(&mut self, lit: &[u8], path: &str) -> Result<(), LexValueError> {
        if self.bytes[self.pos..].starts_with(lit) {
            self.pos += lit.len();
            Ok(())
        } else {
            Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: format!(
                    "expected literal {}",
                    std::str::from_utf8(lit).unwrap_or("?")
                ),
            })
        }
    }

    fn parse_array(&mut self, depth: usize, path: &str) -> Result<Value, LexValueError> {
        if depth + 1 > self.options.maximum_depth {
            return Err(LexValueError::DepthExceeded {
                path: path.to_owned(),
                limit: self.options.maximum_depth,
            });
        }
        self.pos += 1; // '['
        self.skip_ws();
        let mut items = Vec::new();
        if self.peek() == Some(b']') {
            self.pos += 1;
            return Ok(Value::Array(items));
        }
        let mut index = 0usize;
        loop {
            let elem_path = join_pointer(path, &index.to_string());
            items.push(self.parse_value(depth + 1, &elem_path)?);
            index += 1;
            self.skip_ws();
            match self.peek() {
                Some(b',') => {
                    self.pos += 1;
                    self.skip_ws();
                }
                Some(b']') => {
                    self.pos += 1;
                    return Ok(Value::Array(items));
                }
                _ => {
                    return Err(LexValueError::InvalidJson {
                        path: path.to_owned(),
                        message: "expected ',' or ']' in array".to_owned(),
                    });
                }
            }
        }
    }

    fn parse_object(&mut self, depth: usize, path: &str) -> Result<Value, LexValueError> {
        if depth + 1 > self.options.maximum_depth {
            return Err(LexValueError::DepthExceeded {
                path: path.to_owned(),
                limit: self.options.maximum_depth,
            });
        }
        self.pos += 1; // '{'
        self.skip_ws();
        let mut map = BTreeMap::new();
        if self.peek() == Some(b'}') {
            self.pos += 1;
            return Ok(Value::Object(map));
        }
        loop {
            self.skip_ws();
            if self.peek() != Some(b'"') {
                return Err(LexValueError::InvalidJson {
                    path: path.to_owned(),
                    message: "expected object key string".to_owned(),
                });
            }
            let key = self.parse_string(path)?;
            self.skip_ws();
            if self.peek() != Some(b':') {
                return Err(LexValueError::InvalidJson {
                    path: join_pointer(path, &key),
                    message: "expected ':' after object key".to_owned(),
                });
            }
            self.pos += 1;
            let field_path = join_pointer(path, &key);
            let val = self.parse_value(depth + 1, &field_path)?;
            if map.contains_key(&key) {
                return Err(LexValueError::DuplicateKey {
                    path: path.to_owned(),
                    key,
                });
            }
            map.insert(key, val);
            self.skip_ws();
            match self.peek() {
                Some(b',') => {
                    self.pos += 1;
                }
                Some(b'}') => {
                    self.pos += 1;
                    break;
                }
                _ => {
                    return Err(LexValueError::InvalidJson {
                        path: path.to_owned(),
                        message: "expected ',' or '}' in object".to_owned(),
                    });
                }
            }
        }

        if let Some(special) = validate_object_special_markers(&map, &self.options, path)? {
            return Ok(special);
        }
        Ok(Value::Object(map))
    }

    fn parse_string(&mut self, path: &str) -> Result<String, LexValueError> {
        self.pos += 1; // opening '"'
        let mut out = String::new();
        let mut run_start = self.pos;
        while self.pos < self.bytes.len() {
            let b = self.bytes[self.pos];
            match b {
                b'"' => {
                    out.push_str(&self.src[run_start..self.pos]);
                    self.pos += 1;
                    return Ok(out);
                }
                b'\\' => {
                    out.push_str(&self.src[run_start..self.pos]);
                    out.push(self.parse_escape(path)?);
                    run_start = self.pos;
                }
                0x00..=0x1F => {
                    return Err(LexValueError::InvalidJson {
                        path: path.to_owned(),
                        message: format!("unescaped control byte 0x{b:02x} in string"),
                    });
                }
                _ => {
                    // Valid UTF-8 byte (`self.src` is already validated UTF-8 and multi-byte
                    // UTF-8 bytes >= 0x80 never collide with ASCII delimiters `"`/`\`/<0x20).
                    self.pos += 1;
                }
            }
        }
        Err(LexValueError::InvalidJson {
            path: path.to_owned(),
            message: "unterminated JSON string".to_owned(),
        })
    }

    fn parse_escape(&mut self, path: &str) -> Result<char, LexValueError> {
        self.pos += 1; // '\\'
        let esc = *self
            .bytes
            .get(self.pos)
            .ok_or_else(|| LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "unterminated escape sequence".to_owned(),
            })?;
        self.pos += 1;
        match esc {
            b'"' => Ok('"'),
            b'\\' => Ok('\\'),
            b'/' => Ok('/'),
            b'b' => Ok('\u{0008}'),
            b'f' => Ok('\u{000C}'),
            b'n' => Ok('\n'),
            b'r' => Ok('\r'),
            b't' => Ok('\t'),
            b'u' => self.parse_unicode_escape(path),
            _ => Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: format!("invalid JSON escape '\\{}'", char::from(esc)),
            }),
        }
    }

    fn parse_unicode_escape(&mut self, path: &str) -> Result<char, LexValueError> {
        let code = self.parse_hex4(path)?;
        if (0xD800..=0xDBFF).contains(&code) {
            if !self.bytes[self.pos..].starts_with(b"\\u") {
                return Err(LexValueError::InvalidJson {
                    path: path.to_owned(),
                    message: "unpaired high UTF-16 surrogate".to_owned(),
                });
            }
            self.pos += 2;
            let low = self.parse_hex4(path)?;
            if !(0xDC00..=0xDFFF).contains(&low) {
                return Err(LexValueError::InvalidJson {
                    path: path.to_owned(),
                    message: "invalid low UTF-16 surrogate".to_owned(),
                });
            }
            let scalar = 0x10000 + ((u32::from(code) - 0xD800) << 10) + (u32::from(low) - 0xDC00);
            char::from_u32(scalar).ok_or_else(|| LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "invalid Unicode scalar value".to_owned(),
            })
        } else if (0xDC00..=0xDFFF).contains(&code) {
            Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "unpaired low UTF-16 surrogate".to_owned(),
            })
        } else {
            char::from_u32(u32::from(code)).ok_or_else(|| LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "invalid Unicode scalar value".to_owned(),
            })
        }
    }

    fn parse_hex4(&mut self, path: &str) -> Result<u16, LexValueError> {
        if self.pos + 4 > self.bytes.len() {
            return Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "incomplete \\uXXXX escape".to_owned(),
            });
        }
        let slice = &self.bytes[self.pos..self.pos + 4];
        if !slice.iter().all(u8::is_ascii_hexdigit) {
            let preview = std::str::from_utf8(slice).unwrap_or("<non-utf8>");
            return Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: format!("invalid hex digits {preview:?} in \\uXXXX escape"),
            });
        }
        let hex = std::str::from_utf8(slice).map_err(|_| LexValueError::InvalidJson {
            path: path.to_owned(),
            message: "invalid UTF-8 in \\uXXXX escape".to_owned(),
        })?;
        let val = u16::from_str_radix(hex, 16).map_err(|_| LexValueError::InvalidJson {
            path: path.to_owned(),
            message: format!("invalid hex digits {hex:?} in \\uXXXX escape"),
        })?;
        self.pos += 4;
        Ok(val)
    }

    fn parse_number(&mut self, path: &str) -> Result<i64, LexValueError> {
        let start = self.pos;
        let negative = if self.peek() == Some(b'-') {
            self.pos += 1;
            true
        } else {
            false
        };
        let int_start = self.pos;
        match self.peek() {
            Some(b'0') => {
                self.pos += 1;
                if matches!(self.peek(), Some(b'0'..=b'9')) {
                    return Err(LexValueError::InvalidJson {
                        path: path.to_owned(),
                        message: "leading zero in JSON number".to_owned(),
                    });
                }
            }
            Some(b'1'..=b'9') => {
                while matches!(self.peek(), Some(b'0'..=b'9')) {
                    self.pos += 1;
                }
            }
            _ => {
                return Err(LexValueError::InvalidJson {
                    path: path.to_owned(),
                    message: "expected digit in JSON number".to_owned(),
                });
            }
        }
        let int_digits = &self.bytes[int_start..self.pos];
        let frac_digits = self.read_fraction_digits(path)?;
        let exp = self.read_exponent(path)?;
        let raw_num = std::str::from_utf8(&self.bytes[start..self.pos]).unwrap_or("?");
        eval_decimal_integer(negative, int_digits, frac_digits, exp, raw_num, path)
    }

    fn read_fraction_digits(&mut self, path: &str) -> Result<&'a [u8], LexValueError> {
        if self.peek() != Some(b'.') {
            return Ok(&[]);
        }
        self.pos += 1;
        let frac_start = self.pos;
        while matches!(self.peek(), Some(b'0'..=b'9')) {
            self.pos += 1;
        }
        let frac = &self.bytes[frac_start..self.pos];
        if frac.is_empty() {
            return Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "expected digit after decimal point".to_owned(),
            });
        }
        Ok(frac)
    }

    fn read_exponent(&mut self, path: &str) -> Result<i64, LexValueError> {
        if !matches!(self.peek(), Some(b'e' | b'E')) {
            return Ok(0);
        }
        self.pos += 1;
        let exp_neg = match self.peek() {
            Some(b'+') => {
                self.pos += 1;
                false
            }
            Some(b'-') => {
                self.pos += 1;
                true
            }
            _ => false,
        };
        let exp_start = self.pos;
        let mut mag: i64 = 0;
        let cap: i64 = 1_000_000_000_000;
        while let Some(b'0'..=b'9') = self.peek() {
            let d = i64::from(self.bytes[self.pos] - b'0');
            mag = mag.saturating_mul(10).saturating_add(d).min(cap);
            self.pos += 1;
        }
        if self.pos == exp_start {
            return Err(LexValueError::InvalidJson {
                path: path.to_owned(),
                message: "expected exponent digits".to_owned(),
            });
        }
        Ok(if exp_neg { -mag } else { mag })
    }
}

fn eval_decimal_integer(
    negative: bool,
    int_digits: &[u8],
    frac_digits: &[u8],
    exp: i64,
    raw_num: &str,
    path: &str,
) -> Result<i64, LexValueError> {
    let mut digits = Vec::with_capacity(int_digits.len() + frac_digits.len());
    digits.extend_from_slice(int_digits);
    digits.extend_from_slice(frac_digits);

    let first_nz = digits.iter().position(|&b| b != b'0');
    let Some(start_nz) = first_nz else {
        if negative {
            return Err(LexValueError::InvalidNumber {
                path: path.to_owned(),
                message: "-0 is not valid in ATProto data model".to_owned(),
            });
        }
        return Ok(0);
    };
    let last_nz = digits
        .iter()
        .rposition(|&b| b != b'0')
        .expect("non-zero digit exists");
    let sig = &digits[start_nz..=last_nz];
    let trailing_zeros = digits.len() - 1 - last_nz;

    let frac_len = i128::try_from(frac_digits.len()).unwrap_or(i128::MAX);
    let tz = i128::try_from(trailing_zeros).unwrap_or(i128::MAX);
    let shift = i128::from(exp) - frac_len + tz;
    if shift < 0 {
        return Err(LexValueError::InvalidNumber {
            path: path.to_owned(),
            message: format!("number {raw_num:?} is not an exact ATProto integer"),
        });
    }

    let total_digits = i128::try_from(sig.len())
        .unwrap_or(i128::MAX)
        .saturating_add(shift);
    if total_digits > 19 {
        return Err(LexValueError::InvalidNumber {
            path: path.to_owned(),
            message: format!("integer {raw_num:?} out of i64 range"),
        });
    }

    let mut mag: u64 = 0;
    for &b in sig {
        mag = mag * 10 + u64::from(b - b'0');
    }
    #[allow(clippy::cast_sign_loss, clippy::cast_possible_truncation)]
    let scale = 10_u128.pow(shift as u32);
    let value_u128 = u128::from(mag) * scale;

    if negative {
        let min_abs = i64::MIN.unsigned_abs();
        if value_u128 > u128::from(min_abs) {
            return Err(LexValueError::InvalidNumber {
                path: path.to_owned(),
                message: format!("integer {raw_num:?} out of i64 range"),
            });
        }
        if value_u128 == u128::from(min_abs) {
            Ok(i64::MIN)
        } else {
            #[allow(clippy::cast_possible_truncation, clippy::cast_possible_wrap)]
            Ok(-(value_u128 as i64))
        }
    } else {
        i64::try_from(value_u128).map_err(|_| LexValueError::InvalidNumber {
            path: path.to_owned(),
            message: format!("integer {raw_num:?} out of i64 range"),
        })
    }
}

fn write_json_value(value: &Value, out: &mut String) {
    match value {
        Value::Null => out.push_str("null"),
        Value::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
        Value::Integer(n) => {
            use std::fmt::Write as _;
            let _ = write!(out, "{n}");
        }
        Value::String(s) => write_json_string(s, out),
        // Only lenient JSON decoding makes one; JSON can still spell it.
        Value::Float(number) => {
            use std::fmt::Write as _;
            let _ = write!(
                out,
                "{}",
                serde_json::Number::from_f64(number.get())
                    .map_or_else(|| "null".to_owned(), |n| n.to_string())
            );
        }
        Value::Bytes(bytes) => {
            out.push_str("{\"$bytes\":\"");
            out.push_str(&STANDARD_NO_PAD.encode(bytes));
            out.push_str("\"}");
        }
        Value::Link(cid) => {
            out.push_str("{\"$link\":\"");
            out.push_str(&cid.to_string());
            out.push_str("\"}");
        }
        Value::Array(items) => {
            out.push('[');
            for (idx, item) in items.iter().enumerate() {
                if idx > 0 {
                    out.push(',');
                }
                write_json_value(item, out);
            }
            out.push(']');
        }
        Value::Object(map) => {
            out.push('{');
            for (idx, (key, val)) in map.iter().enumerate() {
                if idx > 0 {
                    out.push(',');
                }
                write_json_string(key, out);
                out.push(':');
                write_json_value(val, out);
            }
            out.push('}');
        }
    }
}

fn write_json_string(s: &str, out: &mut String) {
    out.push('"');
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\u{0008}' => out.push_str("\\b"),
            '\u{000C}' => out.push_str("\\f"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                use std::fmt::Write as _;
                let _ = write!(out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out.push('"');
}

// ============================================================================
// Strict canonical DAG-CBOR decoder (RFC 8949 + ATProto Data Model)
// ============================================================================

struct CborDecoder<'a> {
    bytes: &'a [u8],
    pos: usize,
    options: ParseOptions,
}

impl<'a> CborDecoder<'a> {
    const fn new(bytes: &'a [u8], options: ParseOptions) -> Self {
        Self {
            bytes,
            pos: 0,
            options,
        }
    }

    fn decode_root(&mut self) -> Result<Value, LexValueError> {
        let value = self.decode_item(0, "")?;
        if self.pos != self.bytes.len() {
            return Err(LexValueError::InvalidCbor {
                path: String::new(),
                message: format!(
                    "trailing {} byte(s) after DAG-CBOR root",
                    self.bytes.len() - self.pos
                ),
            });
        }
        Ok(value)
    }

    fn read_byte(&mut self, path: &str) -> Result<u8, LexValueError> {
        let b = *self
            .bytes
            .get(self.pos)
            .ok_or_else(|| LexValueError::InvalidCbor {
                path: path.to_owned(),
                message: "unexpected end of DAG-CBOR input".to_owned(),
            })?;
        self.pos += 1;
        Ok(b)
    }

    fn read_exact(&mut self, len: usize, path: &str) -> Result<&'a [u8], LexValueError> {
        if self.bytes.len().saturating_sub(self.pos) < len {
            return Err(LexValueError::InvalidCbor {
                path: path.to_owned(),
                message: "unexpected end of DAG-CBOR input".to_owned(),
            });
        }
        let slice = &self.bytes[self.pos..self.pos + len];
        self.pos += len;
        Ok(slice)
    }

    /// Reads an unsigned integer argument and enforces canonical minimal encoding.
    fn read_argument(&mut self, additional: u8, path: &str) -> Result<u64, LexValueError> {
        match additional {
            0..=23 => Ok(u64::from(additional)),
            24 => {
                let v = self.read_byte(path)?;
                if v < 24 {
                    return Err(LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: "non-minimal 1-byte CBOR integer".to_owned(),
                    });
                }
                Ok(u64::from(v))
            }
            25 => {
                let b = self.read_exact(2, path)?;
                let v = u16::from_be_bytes([b[0], b[1]]);
                if u8::try_from(v).is_ok() {
                    return Err(LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: "non-minimal 2-byte CBOR integer".to_owned(),
                    });
                }
                Ok(u64::from(v))
            }
            26 => {
                let b = self.read_exact(4, path)?;
                let v = u32::from_be_bytes([b[0], b[1], b[2], b[3]]);
                if u16::try_from(v).is_ok() {
                    return Err(LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: "non-minimal 4-byte CBOR integer".to_owned(),
                    });
                }
                Ok(u64::from(v))
            }
            27 => {
                let b = self.read_exact(8, path)?;
                let v = u64::from_be_bytes([b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]]);
                if u32::try_from(v).is_ok() {
                    return Err(LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: "non-minimal 8-byte CBOR integer".to_owned(),
                    });
                }
                Ok(v)
            }
            31 => Err(LexValueError::InvalidCbor {
                path: path.to_owned(),
                message: "indefinite-length CBOR items are disallowed in DAG-CBOR".to_owned(),
            }),
            _ => Err(LexValueError::InvalidCbor {
                path: path.to_owned(),
                message: format!("reserved CBOR additional info {additional}"),
            }),
        }
    }

    fn decode_item(&mut self, depth: usize, path: &str) -> Result<Value, LexValueError> {
        let initial = self.read_byte(path)?;
        let major = initial >> 5;
        let additional = initial & 0x1F;

        match major {
            0 => {
                let val = self.read_argument(additional, path)?;
                i64::try_from(val)
                    .map(Value::Integer)
                    .map_err(|_| LexValueError::InvalidNumber {
                        path: path.to_owned(),
                        message: format!("unsigned CBOR integer {val} exceeds i64::MAX"),
                    })
            }
            1 => {
                let val = self.read_argument(additional, path)?;
                let max_neg_arg = i64::MAX as u64;
                if val > max_neg_arg {
                    return Err(LexValueError::InvalidNumber {
                        path: path.to_owned(),
                        message: format!("negative CBOR integer -1 - {val} below i64::MIN"),
                    });
                }
                let signed = -1_i64 - val.cast_signed();
                Ok(Value::Integer(signed))
            }
            2 => {
                let len = usize::try_from(self.read_argument(additional, path)?).map_err(|_| {
                    LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: "CBOR byte string length overflow".to_owned(),
                    }
                })?;
                let slice = self.read_exact(len, path)?;
                Ok(Value::Bytes(slice.to_vec()))
            }
            3 => {
                let len = usize::try_from(self.read_argument(additional, path)?).map_err(|_| {
                    LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: "CBOR text string length overflow".to_owned(),
                    }
                })?;
                let slice = self.read_exact(len, path)?;
                let text =
                    std::str::from_utf8(slice).map_err(|err| LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: format!("invalid UTF-8 in CBOR text string: {err}"),
                    })?;
                Ok(Value::String(text.to_owned()))
            }
            4 => {
                if depth + 1 > self.options.maximum_depth {
                    return Err(LexValueError::DepthExceeded {
                        path: path.to_owned(),
                        limit: self.options.maximum_depth,
                    });
                }
                let count =
                    usize::try_from(self.read_argument(additional, path)?).map_err(|_| {
                        LexValueError::InvalidCbor {
                            path: path.to_owned(),
                            message: "CBOR array length overflow".to_owned(),
                        }
                    })?;
                let mut items = Vec::with_capacity(count.min(1024));
                for idx in 0..count {
                    let elem_path = join_pointer(path, &idx.to_string());
                    items.push(self.decode_item(depth + 1, &elem_path)?);
                }
                Ok(Value::Array(items))
            }
            5 => self.decode_cbor_map(additional, depth, path),
            6 => self.decode_cbor_tag(additional, path),
            7 => match additional {
                20 => Ok(Value::Bool(false)),
                21 => Ok(Value::Bool(true)),
                22 => Ok(Value::Null),
                25..=27 => Err(LexValueError::InvalidCbor {
                    path: path.to_owned(),
                    message: "floating-point CBOR values are disallowed in ATProto DAG-CBOR"
                        .to_owned(),
                }),
                _ => Err(LexValueError::InvalidCbor {
                    path: path.to_owned(),
                    message: format!("unsupported CBOR simple value {additional}"),
                }),
            },
            _ => unreachable!("major type fits in 3 bits"),
        }
    }

    fn decode_cbor_map(
        &mut self,
        additional: u8,
        depth: usize,
        path: &str,
    ) -> Result<Value, LexValueError> {
        if depth + 1 > self.options.maximum_depth {
            return Err(LexValueError::DepthExceeded {
                path: path.to_owned(),
                limit: self.options.maximum_depth,
            });
        }
        let count = usize::try_from(self.read_argument(additional, path)?).map_err(|_| {
            LexValueError::InvalidCbor {
                path: path.to_owned(),
                message: "CBOR map length overflow".to_owned(),
            }
        })?;
        let mut map = BTreeMap::new();
        let mut prev_key: Option<String> = None;
        for _ in 0..count {
            let key_initial = self.read_byte(path)?;
            if (key_initial >> 5) != 3 {
                return Err(LexValueError::InvalidCbor {
                    path: path.to_owned(),
                    message: "DAG-CBOR map keys must be text strings".to_owned(),
                });
            }
            let key_len =
                usize::try_from(self.read_argument(key_initial & 0x1F, path)?).map_err(|_| {
                    LexValueError::InvalidCbor {
                        path: path.to_owned(),
                        message: "DAG-CBOR map key length overflow".to_owned(),
                    }
                })?;
            let key_bytes = self.read_exact(key_len, path)?;
            let key = std::str::from_utf8(key_bytes)
                .map_err(|err| LexValueError::InvalidCbor {
                    path: path.to_owned(),
                    message: format!("invalid UTF-8 in map key: {err}"),
                })?
                .to_owned();

            if let Some(prev) = &prev_key {
                match (prev.len(), prev.as_bytes()).cmp(&(key.len(), key.as_bytes())) {
                    std::cmp::Ordering::Equal => {
                        return Err(LexValueError::DuplicateKey {
                            path: path.to_owned(),
                            key,
                        });
                    }
                    std::cmp::Ordering::Greater => {
                        return Err(LexValueError::InvalidCbor {
                            path: join_pointer(path, &key),
                            message: format!(
                                "map keys not in canonical DAG-CBOR order: {prev:?} before {key:?}"
                            ),
                        });
                    }
                    std::cmp::Ordering::Less => {}
                }
            }
            prev_key = Some(key.clone());

            let val_path = join_pointer(path, &key);
            let val = self.decode_item(depth + 1, &val_path)?;
            map.insert(key, val);
        }
        if map.contains_key("$link") {
            return Err(LexValueError::InvalidLink {
                path: path.to_owned(),
                message: "a DAG-CBOR map must not use the JSON-only \"$link\" key".to_owned(),
            });
        }
        if map.contains_key("$bytes") {
            return Err(LexValueError::InvalidBytesEncoding {
                path: path.to_owned(),
                message: "a DAG-CBOR map must not use the JSON-only \"$bytes\" key".to_owned(),
            });
        }
        validate_typed_object(&map, &self.options, path)?;
        Ok(Value::Object(map))
    }

    fn decode_cbor_tag(&mut self, additional: u8, path: &str) -> Result<Value, LexValueError> {
        let tag = self.read_argument(additional, path)?;
        if tag != 42 {
            return Err(LexValueError::InvalidCbor {
                path: path.to_owned(),
                message: format!("unsupported CBOR tag {tag} (only tag 42 CID is allowed)"),
            });
        }
        let inner_initial = self.read_byte(path)?;
        if (inner_initial >> 5) != 2 {
            return Err(LexValueError::InvalidCbor {
                path: path.to_owned(),
                message: "CBOR tag 42 must wrap a byte string".to_owned(),
            });
        }
        let len =
            usize::try_from(self.read_argument(inner_initial & 0x1F, path)?).map_err(|_| {
                LexValueError::InvalidCbor {
                    path: path.to_owned(),
                    message: "tag 42 CID length overflow".to_owned(),
                }
            })?;
        let cid_payload = self.read_exact(len, path)?;
        if cid_payload.first().copied() != Some(0x00) {
            return Err(LexValueError::InvalidLink {
                path: path.to_owned(),
                message: "DAG-CBOR CID byte string must start with 0x00 multibase prefix"
                    .to_owned(),
            });
        }
        let cid = Cid::from_bytes(&cid_payload[1..]).map_err(|err| LexValueError::InvalidLink {
            path: path.to_owned(),
            message: err.to_string(),
        })?;
        if self.options.require_blessed_cids && !cid.is_blessed() {
            return Err(LexValueError::InvalidLink {
                path: path.to_owned(),
                message: "CID is not a blessed ATProto CIDv1".to_owned(),
            });
        }
        Ok(Value::Link(cid))
    }
}
