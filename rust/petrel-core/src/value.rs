//! The AT Protocol data model: [`Value`] and the wire wrapper types.
//!
//! [`Value`] is the type for lexicon `unknown`, for the `Unknown(Value)` arm
//! of open unions, and for `extra_data` on objects and records. It has no
//! float variant: floats are rejected at every entry point.
//!
//! JSON spelling of the two non-JSON kinds follows the data model: a link is
//! `{"$link": "<cid>"}` and bytes are `{"$bytes": "<base64>"}`. An object with
//! exactly that one key is read as a link or bytes; with any extra key it
//! stays a plain object.
//!
//! Lane A (work package C5) completes the port: the strict JSON parser
//! option, integrality rules, depth limits and the full blob checks.

use std::collections::BTreeMap;
use std::fmt;

use base64::Engine as _;
use base64::alphabet;
use base64::engine::DecodePaddingMode;
use base64::engine::general_purpose::{GeneralPurpose, GeneralPurposeConfig, STANDARD_NO_PAD};
use serde::de::{self, Deserialize, Deserializer, MapAccess, SeqAccess, Visitor};
use serde::ser::{Serialize, SerializeMap, SerializeSeq, Serializer};

use crate::cid::Cid;
use crate::error::{DecodeError, EncodeError};
use crate::serde_bridge::{FromValue, ObjectReader, ObjectWriter, ToValue};

/// Decodes padded or unpadded standard base64 and ignores non-zero trailing
/// bits, matching the Swift `Bytes` decoder. The URL-safe alphabet is refused.
const BASE64_LENIENT: GeneralPurpose = GeneralPurpose::new(
    &alphabet::STANDARD,
    GeneralPurposeConfig::new()
        .with_decode_padding_mode(DecodePaddingMode::Indifferent)
        .with_decode_allow_trailing_bits(true),
);

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

    /// Reads the JSON spelling of a link or bytes out of a freshly parsed
    /// object. Anything else stays an object.
    fn from_json_object(map: BTreeMap<String, Value>) -> Result<Self, DecodeError> {
        if map.len() == 1 {
            if let Some(link) = map.get("$link") {
                let text = link.as_str().ok_or(DecodeError::TypeMismatch {
                    expected: "string in `$link`",
                    found: link.kind(),
                })?;
                return Ok(Self::Link(Cid::parse(text)?));
            }
            if let Some(bytes) = map.get("$bytes") {
                let text = bytes.as_str().ok_or(DecodeError::TypeMismatch {
                    expected: "string in `$bytes`",
                    found: bytes.kind(),
                })?;
                return BASE64_LENIENT
                    .decode(text)
                    .map(Self::Bytes)
                    .map_err(|error| DecodeError::Custom(format!("invalid `$bytes`: {error}")));
            }
        }
        Ok(Self::Object(map))
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
                let mut out = serializer.serialize_map(Some(map.len()))?;
                for (key, item) in map {
                    out.serialize_entry(key, item)?;
                }
                out.end()
            }
        }
    }
}

struct ValueVisitor;

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

    fn visit_f64<E: de::Error>(self, _: f64) -> Result<Value, E> {
        Err(E::custom(
            "floats are not allowed in the AT Protocol data model",
        ))
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
        Value::deserialize(deserializer)
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<Value, A::Error> {
        let mut items = Vec::new();
        while let Some(item) = seq.next_element()? {
            items.push(item);
        }
        Ok(Value::Array(items))
    }

    fn visit_map<A: MapAccess<'de>>(self, mut access: A) -> Result<Value, A::Error> {
        let mut map = BTreeMap::new();
        while let Some(key) = access.next_key::<String>()? {
            let item = access.next_value()?;
            if map.contains_key(&key) {
                return Err(de::Error::custom(format!("duplicate key `{key}`")));
            }
            map.insert(key, item);
        }
        Value::from_json_object(map).map_err(de::Error::custom)
    }
}

impl<'de> Deserialize<'de> for Value {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        deserializer.deserialize_any(ValueVisitor)
    }
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

impl ToValue for CidLink {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::Link(self.0.clone()))
    }
}

impl FromValue for CidLink {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Link(cid) => Ok(Self(cid)),
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
    /// The pre-2023 form: `{"cid": "<cid string>", "mimeType"}`.
    Legacy {
        /// The CID, as the string the record carried.
        cid: String,
        /// MIME type.
        mime_type: String,
    },
}

impl ToValue for Blob {
    fn to_value(&self) -> Result<Value, EncodeError> {
        match self {
            Self::Typed {
                r#ref,
                mime_type,
                size,
            } => {
                let size = i64::try_from(*size)
                    .map_err(|_| EncodeError::Custom("blob size exceeds i64".into()))?;
                let mut writer = ObjectWriter::with_type("blob");
                writer.field("ref", r#ref)?;
                writer.field("mimeType", mime_type)?;
                writer.field("size", &size)?;
                Ok(writer.finish())
            }
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
        let mut reader = ObjectReader::new(value)?;
        match reader.type_id() {
            Some("blob") => {
                let r#ref = reader.required("ref")?;
                let mime_type: String = reader.required("mimeType")?;
                let size: i64 = reader.required("size")?;
                if mime_type.is_empty() {
                    return Err(DecodeError::Custom("blob mimeType is empty".into()));
                }
                let size = u64::try_from(size)
                    .map_err(|_| DecodeError::Custom("blob size is negative".into()))?;
                Ok(Self::Typed {
                    r#ref,
                    mime_type,
                    size,
                })
            }
            Some(other) => Err(DecodeError::Custom(format!(
                "blob `$type` must be `blob`, found `{other}`"
            ))),
            None => Ok(Self::Legacy {
                cid: reader.required("cid")?,
                mime_type: reader.required("mimeType")?,
            }),
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
}

serde_via_value!(CidLink, Bytes, Blob);
