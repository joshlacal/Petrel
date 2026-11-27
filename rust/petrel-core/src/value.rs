//! The AT Protocol data model: [`Value`] and the wire wrapper types.
//!
//! [`Value`] is the type for lexicon `unknown`, for the `Unknown(Value)` arm
//! of open unions, and for `extra_data` on objects and records.
//!
//! The data model has no floats. A JSON number with a fractional part is
//! refused by strict and data-model decoding, and by DAG-CBOR in both
//! directions. Lenient (output) JSON decoding keeps one found in an untyped
//! position as [`Value::Float`] instead of failing the whole body, so JSON
//! re-encoding stays faithful; [`to_dag_cbor`](crate::to_dag_cbor) refuses
//! it. A JSON number that is an exact integer (`1.0`, `2e2`) reads as
//! [`Value::Integer`] on every path.
//!
//! JSON spelling of the two non-JSON kinds follows the data model: a link is
//! `{"$link": "<cid>"}` and bytes are `{"$bytes": "<base64>"}`. An object with
//! exactly that one key is read as a link or bytes; with any extra key it
//! stays a plain object. Lenient decoding keeps a one-key lookalike whose
//! payload is malformed as a plain object; strict decoding refuses it.
//!
//! Record validation uses [`Value::from_json_data_model`], which enforces
//! reserved-key shapes and recognizes exact signed integers in decimal syntax.

use std::collections::BTreeMap;
use std::fmt;

use base64::Engine as _;
use base64::alphabet;
use base64::engine::DecodePaddingMode;
use base64::engine::general_purpose::{GeneralPurpose, GeneralPurposeConfig, STANDARD_NO_PAD};
use serde::de::{self, Deserialize, DeserializeSeed, Deserializer, MapAccess, SeqAccess, Visitor};
use serde::ser::{Serialize, SerializeMap, SerializeSeq, Serializer};

use crate::cid::{BlessedKind, Cid};
use crate::dagcbor;
use crate::error::{CidError, DecodeError, EncodeError};
use crate::serde_bridge::{FromValue, ObjectReader, ObjectWriter, ToValue};

/// Decodes canonically padded or unpadded base64 and ignores non-zero
/// trailing bits, as the Swift `Bytes` decoder and the reference
/// implementations do. Either alphabet is accepted (standard, or URL-safe as
/// some peers emit), but not a mix of the two. Encoding is always unpadded
/// standard base64, the reference PDS form.
const fn base64_engine(
    alphabet: &alphabet::Alphabet,
    padding: DecodePaddingMode,
) -> GeneralPurpose {
    GeneralPurpose::new(
        alphabet,
        GeneralPurposeConfig::new()
            .with_decode_padding_mode(padding)
            .with_decode_allow_trailing_bits(true),
    )
}
const BASE64_STANDARD_PADDED: GeneralPurpose =
    base64_engine(&alphabet::STANDARD, DecodePaddingMode::RequireCanonical);
const BASE64_STANDARD_UNPADDED: GeneralPurpose =
    base64_engine(&alphabet::STANDARD, DecodePaddingMode::RequireNone);
const BASE64_URL_SAFE_PADDED: GeneralPurpose =
    base64_engine(&alphabet::URL_SAFE, DecodePaddingMode::RequireCanonical);
const BASE64_URL_SAFE_UNPADDED: GeneralPurpose =
    base64_engine(&alphabet::URL_SAFE, DecodePaddingMode::RequireNone);
/// Nested containers allowed in a JSON document. Typed decoding recurses once
/// per level and large generated structs cost tens of kilobytes of stack each,
/// so a deeper cap would let a remote peer overflow a 2 MiB worker stack.
const MAX_JSON_DEPTH: usize = 64;
/// Every integer of at most this magnitude is exact as an `f64`.
const MAX_EXACT_F64_INTEGER: f64 = 9_007_199_254_740_992.0;

fn decode_base64(text: &str) -> Result<Vec<u8>, DecodeError> {
    let url_safe = text.bytes().any(|byte| matches!(byte, b'-' | b'_'));
    let engine = match (url_safe, text.ends_with('=')) {
        (false, true) => &BASE64_STANDARD_PADDED,
        (false, false) => &BASE64_STANDARD_UNPADDED,
        (true, true) => &BASE64_URL_SAFE_PADDED,
        (true, false) => &BASE64_URL_SAFE_UNPADDED,
    };
    engine.decode(text).map_err(|_| DecodeError::MalformedBytes)
}

/// A JSON number with a fractional part, kept from a lenient decode of an
/// untyped position. It is not part of the AT Protocol data model: it has a
/// JSON form but no DAG-CBOR one. See the [module docs](self).
#[derive(Debug, Clone, Copy)]
pub struct Float(f64);

impl Float {
    /// Wraps a finite number. `None` for NaN and the infinities, which JSON
    /// cannot spell.
    pub fn new(number: f64) -> Option<Self> {
        number.is_finite().then_some(Self(number))
    }

    /// The number.
    pub fn get(self) -> f64 {
        self.0
    }
}

/// Bitwise: `0.0` and `-0.0` differ, as their JSON spellings do.
impl PartialEq for Float {
    fn eq(&self, other: &Self) -> bool {
        self.0.to_bits() == other.0.to_bits()
    }
}

impl Eq for Float {}

impl std::hash::Hash for Float {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.0.to_bits().hash(state);
    }
}

impl fmt::Display for Float {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(&self.0, f)
    }
}

/// How JSON is read: strictly against the data model
/// ([`Value::from_json_data_model`]), strictly through serde (XRPC inputs),
/// or leniently through serde (outputs and everything reached from them).
#[derive(Clone, Copy, PartialEq, Eq)]
enum JsonMode {
    DataModel,
    Strict,
    Lenient,
}

/// A value in the AT Protocol data model.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Value {
    /// `null`.
    Null,
    /// A boolean.
    Bool(bool),
    /// A signed 64-bit integer. The data model has no other number.
    Integer(i64),
    /// A UTF-8 string.
    String(String),
    /// A byte string (`$bytes` in JSON, major type 2 in CBOR).
    Bytes(Vec<u8>),
    /// A CID link (`$link` in JSON, tag 42 in CBOR).
    Link(Cid),
    /// An array.
    Array(Vec<Value>),
    /// A map with string keys.
    Object(BTreeMap<String, Value>),
    /// A JSON number with a fractional part, only ever produced by lenient
    /// JSON decoding. Not data-model: it has no DAG-CBOR form. See [`Float`].
    Float(Float),
}

impl Value {
    /// The data-model kind, for error messages.
    pub fn kind(&self) -> &'static str {
        match self {
            Self::Null => "null",
            Self::Bool(_) => "boolean",
            Self::Integer(_) => "integer",
            Self::String(_) => "string",
            Self::Bytes(_) => "bytes",
            Self::Link(_) => "link",
            Self::Array(_) => "array",
            Self::Object(_) => "object",
            Self::Float(_) => "float",
        }
    }

    /// The string, if this is one.
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Self::String(text) => Some(text),
            _ => None,
        }
    }

    /// The map, if this is an object.
    pub fn as_object(&self) -> Option<&BTreeMap<String, Value>> {
        match self {
            Self::Object(map) => Some(map),
            _ => None,
        }
    }

    /// Whether a [`Value::Float`] appears anywhere in the value.
    pub fn contains_float(&self) -> bool {
        match self {
            Self::Float(_) => true,
            Self::Array(items) => items.iter().any(Self::contains_float),
            Self::Object(fields) => fields.values().any(Self::contains_float),
            _ => false,
        }
    }

    /// The CID obtained by hashing the canonical DAG-CBOR representation.
    ///
    /// For a value holding a [`Value::Float`], which is not data-model, see
    /// [`dagcbor::encode`] for the bytes hashed; [`crate::serde_bridge::cid_of`]
    /// refuses such a value instead.
    pub fn cid(&self) -> Cid {
        Cid::for_dag_cbor(&dagcbor::encode(self))
    }

    /// Parses strict data-model JSON. Reserved wrappers must have their exact
    /// shape. Decimal and exponential numbers are accepted only when they
    /// denote an exact signed 64-bit integer.
    pub fn from_json_data_model(json: &[u8]) -> Result<Self, DecodeError> {
        JsonReader::parse(json)
    }

    /// Parses a data-model JSON record with a nonempty `$type` string.
    pub fn from_json_record(json: &[u8]) -> Result<Self, DecodeError> {
        Self::from_json_data_model(json)?.require_record()
    }

    /// Parses a canonical DAG-CBOR record using repository block limits.
    pub fn from_dag_cbor_record(bytes: &[u8]) -> Result<Self, DecodeError> {
        let value = dagcbor::decode_with(bytes, dagcbor::Limits::REPOSITORY_BLOCK)?;
        let value = value.require_record()?;
        value.validate_cbor_fields()?;
        Ok(value)
    }

    fn require_record(self) -> Result<Self, DecodeError> {
        if self
            .as_object()
            .and_then(|fields| fields.get("$type"))
            .and_then(Self::as_str)
            .is_some_and(|name| !name.is_empty())
        {
            Ok(self)
        } else {
            Err(DecodeError::NotARecord)
        }
    }

    fn validate_cbor_fields(&self) -> Result<(), DecodeError> {
        match self {
            Self::Array(items) => items.iter().try_for_each(Self::validate_cbor_fields),
            Self::Object(fields) => {
                if fields.contains_key("$link") {
                    return Err(DecodeError::MalformedLink);
                }
                if fields.contains_key("$bytes") {
                    return Err(DecodeError::MalformedBytes);
                }
                Self::validate_type(fields)?;
                fields.values().try_for_each(Self::validate_cbor_fields)
            }
            _ => Ok(()),
        }
    }

    fn validate_type(fields: &BTreeMap<String, Self>) -> Result<(), DecodeError> {
        let Some(type_id) = fields.get("$type") else {
            return Ok(());
        };
        let type_id = type_id
            .as_str()
            .filter(|type_id| !type_id.is_empty())
            .ok_or(DecodeError::InvalidType)?;
        if type_id == "blob" {
            let validate = || {
                let blob = BlobFields::read(fields)?;
                if blob.reference.blessed_kind() != Some(BlessedKind::Raw) {
                    return Err(DecodeError::Custom(
                        "blob ref must use the raw codec".into(),
                    ));
                }
                Ok(())
            };
            validate().map_err(|error| DecodeError::MalformedBlob(Box::new(error)))?;
        }
        Ok(())
    }

    /// Reads the JSON spelling of a link or bytes out of a freshly parsed
    /// object. The permissive codec preserves lookalikes for unknown fields.
    ///
    /// A lenient read keeps a one-key lookalike whose payload is malformed as
    /// a plain object: it sits in an untyped position (a typed `cid-link` or
    /// `bytes` field still refuses an object), and it reads back the same way.
    fn from_json_object(map: BTreeMap<String, Value>, mode: JsonMode) -> Result<Self, DecodeError> {
        let strict = mode == JsonMode::DataModel;
        if strict || map.len() == 1 {
            if let Some(link) = map.get("$link") {
                if map.len() != 1 {
                    return Err(DecodeError::MalformedLink);
                }
                let parsed = link
                    .as_str()
                    .ok_or(DecodeError::MalformedLink)
                    .and_then(|text| Cid::parse(text).map_err(DecodeError::from));
                return match parsed {
                    Ok(cid) => Ok(Self::Link(cid)),
                    Err(_) if mode == JsonMode::Lenient => Ok(Self::Object(map)),
                    Err(error) => Err(error),
                };
            }
            if let Some(bytes) = map.get("$bytes") {
                if map.len() != 1 {
                    return Err(DecodeError::MalformedBytes);
                }
                let decoded = bytes
                    .as_str()
                    .ok_or(DecodeError::MalformedBytes)
                    .and_then(decode_base64);
                return match decoded {
                    Ok(bytes) => Ok(Self::Bytes(bytes)),
                    Err(_) if mode == JsonMode::Lenient => Ok(Self::Object(map)),
                    Err(error) => Err(error),
                };
            }
        }
        if strict {
            Self::validate_type(&map)?;
        }
        Ok(Self::Object(map))
    }

    /// The key of a one-key map that would read back from JSON as a link or
    /// bytes, which would make its JSON form a different value.
    fn wrapper_lookalike_key(map: &BTreeMap<String, Self>) -> Option<&str> {
        if map.len() != 1 {
            return None;
        }
        let (key, value) = map.iter().next()?;
        let text = value.as_str()?;
        let reads_back = match key.as_str() {
            "$link" => Cid::parse(text).is_ok(),
            "$bytes" => decode_base64(text).is_ok(),
            _ => false,
        };
        reads_back.then_some(key.as_str())
    }
}

impl Serialize for Value {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        match self {
            Self::Null => serializer.serialize_unit(),
            Self::Bool(flag) => serializer.serialize_bool(*flag),
            Self::Integer(number) => serializer.serialize_i64(*number),
            Self::String(text) => serializer.serialize_str(text),
            Self::Bytes(bytes) => {
                let mut map = serializer.serialize_map(Some(1))?;
                map.serialize_entry("$bytes", &STANDARD_NO_PAD.encode(bytes))?;
                map.end()
            }
            Self::Link(cid) => {
                let mut map = serializer.serialize_map(Some(1))?;
                map.serialize_entry("$link", &cid.to_string())?;
                map.end()
            }
            Self::Array(items) => {
                let mut seq = serializer.serialize_seq(Some(items.len()))?;
                for item in items {
                    seq.serialize_element(item)?;
                }
                seq.end()
            }
            Self::Object(map) => {
                // DAG-CBOR can hold a map whose only key is `$link` or
                // `$bytes`. Written as JSON it would read back as a link or
                // as bytes, so it has no JSON form. One whose payload is not
                // a valid link or base64 reads back as the same map.
                if let Some(key) = Self::wrapper_lookalike_key(map) {
                    return Err(serde::ser::Error::custom(format!(
                        "an object whose only field is `{key}` cannot be written as JSON"
                    )));
                }
                let mut out = serializer.serialize_map(Some(map.len()))?;
                for (key, item) in map {
                    out.serialize_entry(key, item)?;
                }
                out.end()
            }
            Self::Float(number) => serializer.serialize_f64(number.get()),
        }
    }
}

/// Reads a [`Value`] through serde, counting depth, in one mode.
#[derive(Clone, Copy)]
pub(crate) struct ValueVisitor {
    depth: usize,
    mode: JsonMode,
}

impl<'de> DeserializeSeed<'de> for ValueVisitor {
    type Value = Value;

    fn deserialize<D: Deserializer<'de>>(self, deserializer: D) -> Result<Value, D::Error> {
        deserializer.deserialize_any(self)
    }
}

impl ValueVisitor {
    /// The reader for outputs: see the [module docs](self).
    pub(crate) const LENIENT: Self = Self {
        depth: 0,
        mode: JsonMode::Lenient,
    };
    /// The reader for XRPC inputs.
    pub(crate) const STRICT: Self = Self {
        depth: 0,
        mode: JsonMode::Strict,
    };

    fn descend<E: de::Error>(self) -> Result<Self, E> {
        if self.depth < MAX_JSON_DEPTH {
            Ok(Self {
                depth: self.depth + 1,
                ..self
            })
        } else {
            Err(E::custom(DecodeError::JsonDepthExceeded(MAX_JSON_DEPTH)))
        }
    }
}

impl<'de> Visitor<'de> for ValueVisitor {
    type Value = Value;

    fn expecting(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("an AT Protocol data-model value")
    }

    fn visit_bool<E: de::Error>(self, flag: bool) -> Result<Value, E> {
        Ok(Value::Bool(flag))
    }

    fn visit_i64<E: de::Error>(self, number: i64) -> Result<Value, E> {
        Ok(Value::Integer(number))
    }

    fn visit_u64<E: de::Error>(self, number: u64) -> Result<Value, E> {
        i64::try_from(number)
            .map(Value::Integer)
            .map_err(|_| E::custom("integer outside the signed 64-bit range"))
    }

    fn visit_f64<E: de::Error>(self, number: f64) -> Result<Value, E> {
        // serde_json hands every number spelled with `.` or `e` here. One
        // that is an exact integer is one, as on the data-model path; above
        // 2^53 an `f64` no longer says which integer was written.
        if number.fract() == 0.0 && number.abs() <= MAX_EXACT_F64_INTEGER {
            #[allow(clippy::cast_possible_truncation)]
            return Ok(Value::Integer(number as i64));
        }
        match (self.mode, Float::new(number)) {
            (JsonMode::Lenient, Some(number)) => Ok(Value::Float(number)),
            _ => Err(E::custom(
                "floats are not allowed in the AT Protocol data model",
            )),
        }
    }

    fn visit_str<E: de::Error>(self, text: &str) -> Result<Value, E> {
        Ok(Value::String(text.to_owned()))
    }

    fn visit_string<E: de::Error>(self, text: String) -> Result<Value, E> {
        Ok(Value::String(text))
    }

    fn visit_bytes<E: de::Error>(self, bytes: &[u8]) -> Result<Value, E> {
        Ok(Value::Bytes(bytes.to_vec()))
    }

    fn visit_byte_buf<E: de::Error>(self, bytes: Vec<u8>) -> Result<Value, E> {
        Ok(Value::Bytes(bytes))
    }

    fn visit_unit<E: de::Error>(self) -> Result<Value, E> {
        Ok(Value::Null)
    }

    fn visit_none<E: de::Error>(self) -> Result<Value, E> {
        Ok(Value::Null)
    }

    fn visit_some<D: Deserializer<'de>>(self, deserializer: D) -> Result<Value, D::Error> {
        self.deserialize(deserializer)
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<Value, A::Error> {
        let child = self.descend()?;
        let mut items = Vec::new();
        while let Some(item) = seq.next_element_seed(child)? {
            items.push(item);
        }
        Ok(Value::Array(items))
    }

    fn visit_map<A: MapAccess<'de>>(self, mut access: A) -> Result<Value, A::Error> {
        let child = self.descend()?;
        let mut map = BTreeMap::new();
        while let Some(key) = access.next_key::<String>()? {
            let std::collections::btree_map::Entry::Vacant(entry) = map.entry(key) else {
                return Err(de::Error::custom("duplicate JSON object key"));
            };
            entry.insert(access.next_value_seed(child)?);
        }
        Value::from_json_object(map, self.mode).map_err(de::Error::custom)
    }
}

impl<'de> Deserialize<'de> for Value {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        ValueVisitor::LENIENT.deserialize(deserializer)
    }
}

struct JsonReader<'a> {
    input: &'a [u8],
    pos: usize,
}

impl<'a> JsonReader<'a> {
    fn parse(input: &'a [u8]) -> Result<Value, DecodeError> {
        let mut reader = Self { input, pos: 0 };
        let value = reader.value(0)?;
        reader.skip_whitespace();
        if reader.pos != input.len() {
            return Err(reader.malformed());
        }
        Ok(value)
    }

    fn peek(&self) -> Option<u8> {
        self.input.get(self.pos).copied()
    }

    fn skip_whitespace(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\t' | b'\n' | b'\r')) {
            self.pos += 1;
        }
    }

    fn take(&mut self, token: &[u8]) -> bool {
        if self.input[self.pos..].starts_with(token) {
            self.pos += token.len();
            true
        } else {
            false
        }
    }

    fn require(&mut self, token: &[u8]) -> Result<(), DecodeError> {
        if self.take(token) {
            Ok(())
        } else {
            Err(self.malformed())
        }
    }

    fn malformed(&self) -> DecodeError {
        DecodeError::Json(format!("malformed JSON at byte {}", self.pos))
    }

    fn value(&mut self, depth: usize) -> Result<Value, DecodeError> {
        self.skip_whitespace();
        match self.peek() {
            Some(b'{' | b'[') if depth == MAX_JSON_DEPTH => {
                Err(DecodeError::JsonDepthExceeded(MAX_JSON_DEPTH))
            }
            Some(b'{') => self.object(depth + 1),
            Some(b'[') => self.array(depth + 1),
            Some(b'"') => self.string().map(Value::String),
            Some(b'-' | b'0'..=b'9') => self.number().map(Value::Integer),
            Some(b't') if self.take(b"true") => Ok(Value::Bool(true)),
            Some(b'f') if self.take(b"false") => Ok(Value::Bool(false)),
            Some(b'n') if self.take(b"null") => Ok(Value::Null),
            _ => Err(self.malformed()),
        }
    }

    fn object(&mut self, depth: usize) -> Result<Value, DecodeError> {
        self.pos += 1;
        self.skip_whitespace();
        let mut fields = BTreeMap::new();
        if !self.take(b"}") {
            loop {
                let key = self.string()?;
                self.skip_whitespace();
                self.require(b":")?;
                match fields.entry(key) {
                    std::collections::btree_map::Entry::Vacant(entry) => {
                        entry.insert(self.value(depth)?);
                    }
                    std::collections::btree_map::Entry::Occupied(entry) => {
                        return Err(DecodeError::DuplicateKey(entry.key().clone()));
                    }
                }
                self.skip_whitespace();
                if self.take(b"}") {
                    break;
                }
                self.require(b",")?;
                self.skip_whitespace();
            }
        }
        Value::from_json_object(fields, JsonMode::DataModel)
    }

    fn array(&mut self, depth: usize) -> Result<Value, DecodeError> {
        self.pos += 1;
        self.skip_whitespace();
        let mut items = Vec::new();
        if !self.take(b"]") {
            loop {
                items.push(self.value(depth)?);
                self.skip_whitespace();
                if self.take(b"]") {
                    break;
                }
                self.require(b",")?;
            }
        }
        Ok(Value::Array(items))
    }

    fn string(&mut self) -> Result<String, DecodeError> {
        let start = self.pos;
        self.require(b"\"")?;
        while let Some(byte) = self.peek() {
            self.pos += 1;
            match byte {
                b'"' => {
                    // Delegate UTF-8, escapes and surrogate pairs to serde_json.
                    return serde_json::from_slice(&self.input[start..self.pos])
                        .map_err(|_| self.malformed());
                }
                b'\\' if self.pos < self.input.len() => self.pos += 1,
                _ => {}
            }
        }
        Err(self.malformed())
    }

    fn digits(&mut self) -> Result<&'a [u8], DecodeError> {
        let start = self.pos;
        while matches!(self.peek(), Some(b'0'..=b'9')) {
            self.pos += 1;
        }
        if start == self.pos {
            return Err(self.malformed());
        }
        Ok(&self.input[start..self.pos])
    }

    fn number(&mut self) -> Result<i64, DecodeError> {
        let negative = self.take(b"-");
        let integer = self.digits()?;
        if integer.len() > 1 && integer[0] == b'0' {
            return Err(self.malformed());
        }
        let fraction = if self.take(b".") { self.digits()? } else { &[] };
        let mut exponent = 0_i64;
        if self.take(b"e") || self.take(b"E") {
            let minus = self.take(b"-");
            if !minus {
                self.take(b"+");
            }
            for &digit in self.digits()? {
                exponent = exponent
                    .saturating_mul(10)
                    .saturating_add(i64::from(digit - b'0'));
            }
            if minus {
                exponent = -exponent;
            }
        }
        exact_integer(negative, integer, fraction, exponent)
    }
}

fn exact_integer(
    negative: bool,
    integer: &[u8],
    fraction: &[u8],
    exponent: i64,
) -> Result<i64, DecodeError> {
    let digits = integer.iter().chain(fraction).copied();
    let Some(leading_zeros) = digits.clone().position(|digit| digit != b'0') else {
        return Ok(0);
    };
    let trailing_zeros = digits
        .clone()
        .rev()
        .position(|digit| digit != b'0')
        .unwrap_or_default();
    let significant_digits = integer.len() + fraction.len() - leading_zeros - trailing_zeros;
    let removed = i64::try_from(trailing_zeros).map_err(|_| DecodeError::NonInteger)?;
    let fractional = i64::try_from(fraction.len()).map_err(|_| DecodeError::NonInteger)?;
    let scale = exponent.saturating_add(removed - fractional);
    let scale = usize::try_from(scale).map_err(|_| DecodeError::NonInteger)?;
    if scale > 19 || significant_digits > 19 - scale {
        return Err(DecodeError::NonInteger);
    }
    let mut magnitude = 0_i128;
    for digit in digits.skip(leading_zeros).take(significant_digits) {
        magnitude = magnitude * 10 + i128::from(digit - b'0');
    }
    for _ in 0..scale {
        magnitude *= 10;
    }
    i64::try_from(if negative { -magnitude } else { magnitude })
        .map_err(|_| DecodeError::NonInteger)
}

/// Implements serde's traits for a type by going through [`Value`].
macro_rules! serde_via_value {
    ($($ty:ty),+ $(,)?) => {$(
        impl serde::Serialize for $ty {
            fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
                $crate::serde_bridge::serialize(self, serializer)
            }
        }

        impl<'de> serde::Deserialize<'de> for $ty {
            fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
                $crate::serde_bridge::deserialize(deserializer)
            }
        }
    )+};
}
pub(crate) use serde_via_value;

/// Lexicon `cid-link`: a CID that is a link in the data model.
///
/// JSON `{"$link": "<cid>"}`, CBOR tag 42. Not to be confused with
/// [`CidString`](crate::CidString), the `cid` *string format*, which stays a
/// plain string in both codecs.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CidLink(pub Cid);

impl CidLink {
    /// Creates a schema-typed link using the blessed SHA-256 CID profile.
    pub fn new(cid: Cid) -> Result<Self, CidError> {
        if cid.is_blessed() {
            Ok(Self(cid))
        } else {
            Err(CidError::NotBlessed)
        }
    }
}

impl ToValue for CidLink {
    fn to_value(&self) -> Result<Value, EncodeError> {
        if !self.0.is_blessed() {
            return Err(EncodeError::Custom(CidError::NotBlessed.to_string()));
        }
        Ok(Value::Link(self.0.clone()))
    }
}

impl FromValue for CidLink {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Link(cid) => Ok(Self::new(cid)?),
            other => Err(DecodeError::TypeMismatch {
                expected: "link",
                found: other.kind(),
            }),
        }
    }
}

/// Lexicon `bytes`.
///
/// JSON `{"$bytes": "<base64>"}`, CBOR byte string. Encodes unpadded standard
/// base64 (the reference PDS form) and decodes padded or unpadded (plan
/// decision 6).
#[derive(Debug, Clone, PartialEq, Eq, Hash, Default)]
pub struct Bytes(pub Vec<u8>);

impl ToValue for Bytes {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::Bytes(self.0.clone()))
    }
}

impl FromValue for Bytes {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Bytes(bytes) => Ok(Self(bytes)),
            other => Err(DecodeError::TypeMismatch {
                expected: "bytes",
                found: other.kind(),
            }),
        }
    }
}

/// Lexicon `blob`: a reference to uploaded binary data.
///
/// The legacy form (`{"cid", "mimeType"}` with no `$type`) is kept as its own
/// variant and re-encodes in the legacy shape, byte for byte. Upgrading it
/// would invent a size and change the record's CID.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Blob {
    /// `{"$type": "blob", "ref": {"$link"}, "mimeType", "size"}`.
    Typed {
        /// Link to the blob's bytes (a raw-codec CID).
        r#ref: CidLink,
        /// MIME type. Never empty.
        mime_type: String,
        /// Size in bytes.
        size: u64,
    },
    /// The modern representation retaining its optional compatibility CID.
    TypedWithCid {
        /// Link to the blob's bytes.
        r#ref: CidLink,
        /// MIME type. Never empty.
        mime_type: String,
        /// Size in bytes.
        size: u64,
        /// Compatibility CID string, kept as received.
        cid: String,
    },
    /// The pre-2023 form: `{"cid": "<cid string>", "mimeType"}`.
    Legacy {
        /// The CID, as the string the record carried.
        cid: String,
        /// MIME type.
        mime_type: String,
    },
}

impl Blob {
    /// Whether the blob uses the old form without a length and typed link.
    pub fn is_legacy(&self) -> bool {
        matches!(self, Self::Legacy { .. })
    }

    fn encode_typed(
        reference: &CidLink,
        mime_type: &str,
        size: u64,
        cid: Option<&str>,
    ) -> Result<Value, EncodeError> {
        if mime_type.is_empty() {
            return Err(EncodeError::Custom("blob mimeType is empty".into()));
        }
        let size =
            i64::try_from(size).map_err(|_| EncodeError::Custom("blob size exceeds i64".into()))?;
        let mut writer = ObjectWriter::with_type("blob");
        writer.field("ref", reference)?;
        writer.field("mimeType", mime_type)?;
        writer.field("size", &size)?;
        if let Some(cid) = cid {
            writer.field("cid", cid)?;
        }
        Ok(writer.finish())
    }
}

struct BlobFields<'a> {
    reference: &'a Cid,
    mime_type: &'a str,
    size: u64,
    cid: Option<&'a str>,
}

impl<'a> BlobFields<'a> {
    fn read(fields: &'a BTreeMap<String, Value>) -> Result<Self, DecodeError> {
        let required = |name: &str| {
            fields
                .get(name)
                .ok_or_else(|| DecodeError::MissingField(name.into()))
        };
        let reference = match required("ref")? {
            Value::Link(cid) if cid.blessed_kind() == Some(BlessedKind::Raw) => cid,
            Value::Link(cid) if cid.is_blessed() => {
                return Err(
                    DecodeError::Custom("blob ref must use the raw codec".into()).in_field("ref"),
                );
            }
            Value::Link(_) => return Err(DecodeError::from(CidError::NotBlessed).in_field("ref")),
            other => {
                return Err(DecodeError::TypeMismatch {
                    expected: "link",
                    found: other.kind(),
                }
                .in_field("ref"));
            }
        };
        let mime_type = required("mimeType")?
            .as_str()
            .filter(|text| !text.is_empty())
            .ok_or_else(|| {
                DecodeError::Custom("must be a nonempty string".into()).in_field("mimeType")
            })?;
        let size = match required("size")? {
            Value::Integer(size) => u64::try_from(*size).ok(),
            _ => None,
        }
        .ok_or_else(|| {
            DecodeError::Custom("must be a nonnegative integer".into()).in_field("size")
        })?;
        let cid = match fields.get("cid") {
            None | Some(Value::Null) => None,
            Some(Value::String(text)) => Some(text.as_str()),
            Some(other) => {
                return Err(DecodeError::TypeMismatch {
                    expected: "string",
                    found: other.kind(),
                }
                .in_field("cid"));
            }
        };
        Ok(Self {
            reference,
            mime_type,
            size,
            cid,
        })
    }
}

impl ToValue for Blob {
    fn to_value(&self) -> Result<Value, EncodeError> {
        match self {
            Self::Typed {
                r#ref,
                mime_type,
                size,
            } => Self::encode_typed(r#ref, mime_type, *size, None),
            Self::TypedWithCid {
                r#ref,
                mime_type,
                size,
                cid,
            } => Self::encode_typed(r#ref, mime_type, *size, Some(cid)),
            Self::Legacy { cid, mime_type } => {
                let mut writer = ObjectWriter::new();
                writer.field("cid", cid)?;
                writer.field("mimeType", mime_type)?;
                Ok(writer.finish())
            }
        }
    }
}

impl FromValue for Blob {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        let fields = value.as_object().ok_or(DecodeError::TypeMismatch {
            expected: "object",
            found: value.kind(),
        })?;
        match fields.get("$type") {
            Some(Value::String(kind)) if kind == "blob" => {
                let blob = BlobFields::read(fields)?;
                let r#ref = CidLink(blob.reference.clone());
                let mime_type = blob.mime_type.to_owned();
                let size = blob.size;
                if let Some(cid) = blob.cid {
                    Ok(Self::TypedWithCid {
                        r#ref,
                        mime_type,
                        size,
                        cid: cid.to_owned(),
                    })
                } else {
                    Ok(Self::Typed {
                        r#ref,
                        mime_type,
                        size,
                    })
                }
            }
            Some(_) => Err(DecodeError::InvalidType),
            None => {
                let mut reader = ObjectReader::new(value)?;
                Ok(Self::Legacy {
                    cid: reader.required("cid")?,
                    mime_type: reader.required("mimeType")?,
                })
            }
        }
    }
}

/// The value half of a tri-state field.
///
/// A lexicon property that is both optional and nullable is generated as
/// `Option<Nullable<T>>`: `None` means the key is absent, `Some(Null)` means
/// an explicit `null`, `Some(Value(v))` means a value. The three states are
/// different on the wire (`putRecord.swapRecord` depends on it).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum Nullable<T> {
    /// An explicit `null`.
    Null,
    /// A value.
    Value(T),
}

impl<T: ToValue> ToValue for Nullable<T> {
    fn to_value(&self) -> Result<Value, EncodeError> {
        match self {
            Self::Null => Ok(Value::Null),
            Self::Value(inner) => inner.to_value(),
        }
    }
}

impl<T: FromValue> FromValue for Nullable<T> {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Null => Ok(Self::Null),
            other => T::from_value(other).map(Self::Value),
        }
    }

    fn from_value_strict(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Null => Ok(Self::Null),
            other => T::from_value_strict(other).map(Self::Value),
        }
    }
}

impl<T: ToValue> Serialize for Nullable<T> {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        crate::serde_bridge::serialize(self, serializer)
    }
}

impl<'de, T: FromValue> Deserialize<'de> for Nullable<T> {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        crate::serde_bridge::deserialize(deserializer)
    }
}

serde_via_value!(CidLink, Bytes, Blob);
