//! Helpers for `$type`-tagged values: unions and lexicon `unknown`.
//!
//! Generated union enums dispatch on `$type` with [`type_of`] and write it
//! with [`tagged`]. An open union keeps a member it does not know as
//! `Unknown(Value)`, the whole raw object including its `$type`, so
//! re-encoding is verbatim. A closed union returns
//! [`DecodeError::UnknownType`].
//!
//! There is no global `$type` registry (the Swift runtime has one). Typed
//! decoding of an `unknown` value is on demand: `T::from_value(value)`.
//!
//! Lane A (work package C8) adds the rest here: the typed-decode guard that
//! keeps the raw form when a typed re-encode would lose a field, and a
//! `TypedValue` trait carrying a type's NSID.

use crate::error::{DecodeError, EncodeError};
use crate::value::Value;

/// The `$type` of a union member. Missing or non-string is an error.
pub fn type_of(value: &Value) -> Result<&str, DecodeError> {
    value
        .as_object()
        .and_then(|map| map.get("$type"))
        .and_then(Value::as_str)
        .ok_or(DecodeError::MissingType)
}

/// Sets `$type` on an encoded union member.
///
/// A record used as a union member has already written its own `$type`; this
/// overwrites the same key, so the result carries `$type` exactly once (CBOR
/// forbids duplicate keys, and [`Value::Object`] cannot hold one).
pub fn tagged(value: Value, type_id: &str) -> Result<Value, EncodeError> {
    match value {
        Value::Object(mut map) => {
            map.insert("$type".to_owned(), Value::String(type_id.to_owned()));
            Ok(Value::Object(map))
        }
        other => Err(EncodeError::Custom(format!(
            "a union member must encode as an object, found {}",
            other.kind()
        ))),
    }
}
