//! Helpers for `$type`-tagged values: unions and lexicon `unknown`.
//!
//! Generated union enums dispatch on `$type` with [`type_of`] and write it
//! with [`tagged`]. An open union keeps a member it does not know as
//! `Unknown(Value)`, the whole raw object including its `$type`, so
//! re-encoding is verbatim. A closed union returns
//! [`DecodeError::UnknownType`].
//!
//! Typed decoding of an `unknown` value is on demand and checks that the
//! typed representation preserves the raw fields.

use crate::error::{DecodeError, EncodeError};
use crate::serde_bridge::{FromValue, ToValue};
use crate::value::Value;

/// A data-model type with a canonical wire discriminator.
pub trait TypedValue: FromValue + ToValue {
    /// Wire discriminator, including any `#def` suffix.
    const NSID: &'static str;
}

/// The `$type` of a union member. A missing or malformed tag is an error.
pub fn type_of(value: &Value) -> Result<&str, DecodeError> {
    let Some(tag) = value.as_object().and_then(|map| map.get("$type")) else {
        return Err(DecodeError::MissingType);
    };
    tag.as_str()
        .filter(|tag| !tag.is_empty())
        .ok_or(DecodeError::InvalidType)
}

/// Removes `$type` from a union member before it is decoded as its typed
/// member. The union writes the tag back itself, so the member's own
/// `extra_data` does not need to keep it.
pub fn untagged(value: Value) -> Value {
    match value {
        Value::Object(mut map) => {
            map.remove("$type");
            Value::Object(map)
        }
        other => other,
    }
}

/// Sets `$type` on an encoded union member.
///
/// If the object already carries a tag, it must be the expected one.
pub fn tagged(value: Value, type_id: &str) -> Result<Value, EncodeError> {
    if type_id.is_empty() {
        return Err(EncodeError::Custom("empty $type discriminator".into()));
    }
    match value {
        Value::Object(mut map) => {
            match map.entry("$type".to_owned()) {
                std::collections::btree_map::Entry::Vacant(entry) => {
                    entry.insert(Value::String(type_id.to_owned()));
                }
                std::collections::btree_map::Entry::Occupied(entry) => {
                    if entry.get().as_str() != Some(type_id) {
                        return Err(EncodeError::Custom(format!(
                            "union member carries a different $type from `{type_id}`"
                        )));
                    }
                }
            }
            Ok(Value::Object(map))
        }
        other => Err(EncodeError::Custom(format!(
            "a union member must encode as an object, found {}",
            other.kind()
        ))),
    }
}

/// Encodes a typed object with its canonical wire discriminator.
pub fn encode_typed<T: TypedValue>(value: &T) -> Result<Value, EncodeError> {
    tagged(value.to_value()?, T::NSID)
}

/// Decodes a raw value with lossless typed projection. The raw value stays
/// available to the caller if the typed decoder would change or drop data.
pub fn decode_as<T: FromValue + ToValue>(value: &Value) -> Result<T, DecodeError> {
    let typed = T::from_value(value.clone())?;
    let encoded = typed.to_value().map_err(|_| DecodeError::LossyProjection)?;
    if is_spec_tolerant_match(&encoded, value) {
        Ok(typed)
    } else {
        Err(DecodeError::LossyProjection)
    }
}

/// Decodes a raw value as the identified type. An absent discriminator is
/// allowed for nested objects, but a present one must match.
pub fn decode_typed<T: TypedValue>(value: &Value) -> Result<T, DecodeError> {
    if value
        .as_object()
        .is_some_and(|fields| fields.contains_key("$type"))
    {
        let type_id = type_of(value)?;
        if type_id != T::NSID {
            return Err(DecodeError::TypeIdMismatch {
                expected: T::NSID.to_owned(),
                found: type_id.to_owned(),
            });
        }
    }
    decode_as(value)
}

/// Checks a typed re-encoding against its raw value. Differences in framing
/// (an absent `$type` on one side, or an absent field versus explicit null)
/// are tolerated. Present values, including nested fields and array order,
/// must match on both sides.
pub fn is_spec_tolerant_match(typed: &Value, raw: &Value) -> bool {
    match (typed, raw) {
        (Value::Object(typed), Value::Object(raw)) => {
            typed.iter().all(|(key, value)| {
                raw.get(key).map_or_else(
                    || key == "$type" || *value == Value::Null,
                    |other| is_spec_tolerant_match(value, other),
                )
            }) && raw.iter().all(|(key, value)| {
                typed.contains_key(key) || key == "$type" || *value == Value::Null
            })
        }
        (Value::Array(typed), Value::Array(raw)) => {
            typed.len() == raw.len()
                && typed
                    .iter()
                    .zip(raw)
                    .all(|(value, other)| is_spec_tolerant_match(value, other))
        }
        _ => typed == raw,
    }
}
