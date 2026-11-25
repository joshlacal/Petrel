//! The bridge between typed structs and [`Value`], and from there to JSON and
//! DAG-CBOR.
//!
//! This module is what plan decision 4 rests on. Generated types do **not**
//! derive serde traits and never use `#[serde(flatten)]`. Instead the
//! generator emits, for every object, record and union:
//!
//! - `impl ToValue` and `impl FromValue`, written as straight-line calls on
//!   [`ObjectWriter`] and [`ObjectReader`];
//! - a two-line `impl serde::Serialize` and `impl serde::Deserialize` that
//!   delegate to [`serialize`] and [`deserialize`] here, so the types also
//!   work with any serde consumer.
//!
//! Why not derive: serde's flatten and tagged-enum support buffer through a
//! private `Content` type that loses CID links and byte strings; derive
//! treats a missing required-nullable key as `None`; and neither can do the
//! lenient rule below. Why a `Value` hop rather than hand-written serde
//! visitors: every one of those behaviours needs the raw value in hand anyway
//! (union dispatch on `$type`, unknown-field retention, keeping a malformed
//! field's raw form), and one small non-generic reader compiles far faster
//! than a monomorphized visitor per generated type.
//!
//! # Field rules (mirroring the Swift generator)
//!
//! | Lexicon property | Rust field | Read with | Written with |
//! |---|---|---|---|
//! | required | `T` | [`ObjectReader::required`] | [`ObjectWriter::field`] |
//! | optional | `Option<T>` | [`ObjectReader::optional`] | [`ObjectWriter::optional`] |
//! | required and nullable | `Option<T>` | [`ObjectReader::required_nullable`] | [`ObjectWriter::required_nullable`] |
//! | optional and nullable | `Option<Nullable<T>>` | [`ObjectReader::optional_nullable`] | [`ObjectWriter::optional_nullable`] |
//!
//! Decoding is lenient by default (plan decision 5): an optional field whose
//! value does not decode becomes `None`, and its raw value is kept in
//! `extra_data` under the same key, so re-encoding reproduces the original
//! bytes. The raw value is written back only while the typed field is still
//! `None`. One case does not round-trip: an explicit `null` in an optional
//! field that the lexicon does not mark nullable reads as absent and is not
//! written back, so a record's CID is that of its original bytes, never of
//! the re-encoded value. A required field that does not decode fails the
//! whole object. XRPC inputs use [`ObjectReader::optional_strict`] and
//! [`ObjectReader::optional_nullable_strict`] instead.
//!
//! # Strict decoding
//!
//! [`strictly`] runs a decode in which no optional field anywhere in the
//! tree may degrade, and `null` is refused in a field the lexicon does not
//! mark nullable: the first such field is the decode's error. The
//! generated `FromValue` of every XRPC input runs inside it, so a nested
//! object, array item or union member in an input is held to the same rule
//! as the input's own fields, whoever calls the decode. [`from_json_strict`]
//! and [`from_dag_cbor_strict`] do the same for any type, such as a record a
//! service is asked to write.
//!
//! # Preservation of optional fields
//!
//! [`ObjectReader::optional`] clones the raw value before decoding so it can
//! keep it on failure. If profiling shows this matters, give [`FromValue`] a
//! provided `try_from_value` that hands the value back on error; the
//! generated code does not need to change.

use std::cell::{Cell, RefCell};
use std::collections::BTreeMap;

use serde::de::Error as _;
use serde::ser::Error as _;

use crate::cid::Cid;
use crate::dagcbor;
use crate::error::{DecodeError, EncodeError};
use crate::value::{Nullable, Value};

/// A type that can be written to the data model.
pub trait ToValue {
    /// Builds the wire value.
    fn to_value(&self) -> Result<Value, EncodeError>;
}

/// A type that can be read from the data model.
pub trait FromValue: Sized {
    /// Reads the typed value, consuming the wire value.
    fn from_value(value: Value) -> Result<Self, DecodeError>;
}

/// Encodes a typed value as JSON. Object keys are written in sorted order.
pub fn to_json<T: ToValue + ?Sized>(value: &T) -> Result<Vec<u8>, EncodeError> {
    serde_json::to_vec(&value.to_value()?).map_err(|error| EncodeError::Custom(error.to_string()))
}

/// Decodes a typed value from JSON. Floats and duplicate keys are refused.
pub fn from_json<T: FromValue>(json: &[u8]) -> Result<T, DecodeError> {
    let value: Value =
        serde_json::from_slice(json).map_err(|error| DecodeError::Json(error.to_string()))?;
    T::from_value(value)
}

/// Decodes a typed value from JSON strictly: see [`strictly`].
pub fn from_json_strict<T: FromValue>(json: &[u8]) -> Result<T, DecodeError> {
    strictly(|| from_json(json))
}

/// Encodes a typed value as canonical DAG-CBOR.
pub fn to_dag_cbor<T: ToValue + ?Sized>(value: &T) -> Result<Vec<u8>, EncodeError> {
    Ok(dagcbor::encode(&value.to_value()?))
}

/// Computes the CID of a typed value's canonical DAG-CBOR representation.
pub fn cid_of<T: ToValue + ?Sized>(value: &T) -> Result<Cid, EncodeError> {
    Ok(value.to_value()?.cid())
}

/// Decodes a typed value from canonical DAG-CBOR. Non-canonical input is
/// refused.
pub fn from_dag_cbor<T: FromValue>(bytes: &[u8]) -> Result<T, DecodeError> {
    T::from_value(dagcbor::decode(bytes)?)
}

/// Decodes a typed value from canonical DAG-CBOR strictly: see [`strictly`].
pub fn from_dag_cbor_strict<T: FromValue>(bytes: &[u8]) -> Result<T, DecodeError> {
    strictly(|| from_dag_cbor(bytes))
}

/// Decodes a typed canonical DAG-CBOR value using custom resource limits.
pub fn from_dag_cbor_with<T: FromValue>(
    bytes: &[u8],
    limits: dagcbor::Limits,
) -> Result<T, DecodeError> {
    T::from_value(dagcbor::decode_with(bytes, limits)?)
}

/// Body of a generated `impl serde::Serialize`.
pub fn serialize<T, S>(value: &T, serializer: S) -> Result<S::Ok, S::Error>
where
    T: ToValue + ?Sized,
    S: serde::Serializer,
{
    serde::Serialize::serialize(&value.to_value().map_err(S::Error::custom)?, serializer)
}

/// Body of a generated `impl serde::Deserialize`.
pub fn deserialize<'de, T, D>(deserializer: D) -> Result<T, D::Error>
where
    T: FromValue,
    D: serde::Deserializer<'de>,
{
    let value = <Value as serde::Deserialize>::deserialize(deserializer)?;
    T::from_value(value).map_err(D::Error::custom)
}

fn mismatch(expected: &'static str, found: &Value) -> DecodeError {
    DecodeError::TypeMismatch {
        expected,
        found: found.kind(),
    }
}

impl ToValue for Value {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(self.clone())
    }
}

impl FromValue for Value {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        Ok(value)
    }
}

impl ToValue for String {
    fn to_value(&self) -> Result<Value, EncodeError> {
        self.as_str().to_value()
    }
}

impl ToValue for str {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::String(self.to_owned()))
    }
}

impl FromValue for String {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::String(text) => Ok(text),
            other => Err(mismatch("string", &other)),
        }
    }
}

impl ToValue for bool {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::Bool(*self))
    }
}

impl FromValue for bool {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Bool(flag) => Ok(flag),
            other => Err(mismatch("boolean", &other)),
        }
    }
}

impl ToValue for i64 {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::Integer(*self))
    }
}

impl FromValue for i64 {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Integer(number) => Ok(number),
            other => Err(mismatch("integer", &other)),
        }
    }
}

impl<T: ToValue> ToValue for Vec<T> {
    fn to_value(&self) -> Result<Value, EncodeError> {
        self.iter()
            .map(T::to_value)
            .collect::<Result<_, _>>()
            .map(Value::Array)
    }
}

impl<T: FromValue> FromValue for Vec<T> {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Array(items) => items.into_iter().map(T::from_value).collect(),
            other => Err(mismatch("array", &other)),
        }
    }
}

impl<T: ToValue + ?Sized> ToValue for Box<T> {
    fn to_value(&self) -> Result<Value, EncodeError> {
        (**self).to_value()
    }
}

impl<T: FromValue> FromValue for Box<T> {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        T::from_value(value).map(Box::new)
    }
}

impl<T: ToValue> ToValue for BTreeMap<String, T> {
    fn to_value(&self) -> Result<Value, EncodeError> {
        self.iter()
            .map(|(key, item)| Ok((key.clone(), item.to_value()?)))
            .collect::<Result<_, _>>()
            .map(Value::Object)
    }
}

impl<T: FromValue> FromValue for BTreeMap<String, T> {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Object(map) => map
                .into_iter()
                .map(|(key, item)| Ok((key, T::from_value(item)?)))
                .collect(),
            other => Err(mismatch("object", &other)),
        }
    }
}

thread_local! {
    /// How many [`strictly`] calls enclose the current decode.
    static STRICT_DEPTH: Cell<u32> = const { Cell::new(0) };
    /// Wire names of the fields being decoded, outermost first, while strict.
    static STRICT_PATH: RefCell<Vec<String>> = const { RefCell::new(Vec::new()) };
    /// The first optional field that degraded inside the outermost [`strictly`].
    static STRICT_VIOLATION: RefCell<Option<DecodeError>> = const { RefCell::new(None) };
}

/// Runs `decode` so that an optional field that does not decode, at any
/// depth, fails the whole decode instead of degrading to `None`.
///
/// Decoding is synchronous, so the rule is carried in thread-local state for
/// the duration of the call; nested calls join the outermost one. Unknown
/// fields and unknown members of open unions are still accepted, as the
/// data model requires.
pub fn strictly<T>(decode: impl FnOnce() -> Result<T, DecodeError>) -> Result<T, DecodeError> {
    let outer = STRICT_DEPTH.get();
    if outer == 0 {
        // A panic inside an earlier strict decode may have left a violation.
        STRICT_VIOLATION.take();
    }
    STRICT_DEPTH.set(outer + 1);
    let scope = StrictScope { outer };
    let result = decode();
    let violation = if outer == 0 {
        STRICT_VIOLATION.take()
    } else {
        None
    };
    drop(scope);
    match (result, violation) {
        (Err(error), _) => Err(error),
        (Ok(_), Some(violation)) => Err(violation),
        (Ok(value), None) => Ok(value),
    }
}

/// Restores the strict depth when a [`strictly`] call ends, panics included.
struct StrictScope {
    outer: u32,
}

impl Drop for StrictScope {
    fn drop(&mut self) {
        STRICT_DEPTH.set(self.outer);
        if self.outer == 0 {
            STRICT_PATH.with_borrow_mut(Vec::clear);
        }
    }
}

/// Pops a field name off the strict path when its decode ends.
struct StrictPathEntry;

impl Drop for StrictPathEntry {
    fn drop(&mut self) {
        STRICT_PATH.with_borrow_mut(Vec::pop);
    }
}

fn is_strict() -> bool {
    STRICT_DEPTH.get() > 0
}

/// Decodes one field's value, tracking its name while strict so a degraded
/// field deeper down is reported with its full path.
fn decode_field<T: FromValue>(name: &str, value: Value) -> Result<T, DecodeError> {
    if !is_strict() {
        return T::from_value(value);
    }
    STRICT_PATH.with_borrow_mut(|path| path.push(name.to_owned()));
    let _entry = StrictPathEntry;
    T::from_value(value)
}

fn not_nullable() -> DecodeError {
    DecodeError::TypeMismatch {
        expected: "a value (the field is not nullable)",
        found: "null",
    }
}

/// Records that the optional field `name` degraded with `error`, when strict.
fn record_degraded(name: &str, error: DecodeError) {
    if !is_strict() {
        return;
    }
    STRICT_VIOLATION.with_borrow_mut(|violation| {
        if violation.is_none() {
            let error = STRICT_PATH.with_borrow(|path| {
                path.iter()
                    .rev()
                    .fold(error.in_field(name), |error, parent| error.in_field(parent))
            });
            *violation = Some(error);
        }
    });
}

/// Reads the fields of one object. See the [module docs](self) for the rules.
#[derive(Debug)]
pub struct ObjectReader {
    fields: BTreeMap<String, Value>,
    degraded: BTreeMap<String, Value>,
}

impl ObjectReader {
    /// Starts reading an object. Fails if the value is not an object.
    pub fn new(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::Object(fields) => Ok(Self {
                fields,
                degraded: BTreeMap::new(),
            }),
            other => Err(mismatch("object", &other)),
        }
    }

    /// The object's `$type`, if it has a string one.
    pub fn type_id(&self) -> Option<&str> {
        self.fields.get("$type").and_then(Value::as_str)
    }

    /// A required field: the key must be present and decode.
    pub fn required<T: FromValue>(&mut self, name: &str) -> Result<T, DecodeError> {
        let value = self
            .fields
            .remove(name)
            .ok_or_else(|| DecodeError::MissingField(name.to_owned()))?;
        decode_field(name, value).map_err(|error| error.in_field(name))
    }

    /// An optional field, read leniently: absent or `null` is `None`; a value
    /// that does not decode is also `None`, and its raw form is kept for
    /// [`finish`](Self::finish) to return.
    ///
    /// Inside [`strictly`], a value that does not decode, or `null` (the
    /// field is not nullable), fails the decode.
    pub fn optional<T: FromValue>(&mut self, name: &str) -> Option<T> {
        match self.fields.remove(name)? {
            Value::Null => {
                record_degraded(name, not_nullable());
                None
            }
            value => match decode_field(name, value.clone()) {
                Ok(typed) => Some(typed),
                Err(error) => {
                    record_degraded(name, error);
                    self.degraded.insert(name.to_owned(), value);
                    None
                }
            },
        }
    }

    /// An optional field, read strictly (XRPC inputs): absent or `null` is
    /// `None`, a value that does not decode is an error. Inside [`strictly`],
    /// `null` is an error too: the field is not nullable.
    pub fn optional_strict<T: FromValue>(&mut self, name: &str) -> Result<Option<T>, DecodeError> {
        match self.fields.remove(name) {
            Some(Value::Null) if is_strict() => Err(not_nullable().in_field(name)),
            None | Some(Value::Null) => Ok(None),
            Some(value) => decode_field(name, value)
                .map(Some)
                .map_err(|error| error.in_field(name)),
        }
    }

    /// A required, nullable field: the key must be present; `null` is `None`.
    pub fn required_nullable<T: FromValue>(
        &mut self,
        name: &str,
    ) -> Result<Option<T>, DecodeError> {
        match self.fields.remove(name) {
            None => Err(DecodeError::MissingField(name.to_owned())),
            Some(Value::Null) => Ok(None),
            Some(value) => decode_field(name, value)
                .map(Some)
                .map_err(|error| error.in_field(name)),
        }
    }

    /// An optional, nullable field (tri-state): absent is `None`, `null` is
    /// `Some(Nullable::Null)`. A value that does not decode degrades like
    /// [`optional`](Self::optional).
    pub fn optional_nullable<T: FromValue>(&mut self, name: &str) -> Option<Nullable<T>> {
        match self.fields.remove(name)? {
            Value::Null => Some(Nullable::Null),
            value => match decode_field(name, value.clone()) {
                Ok(typed) => Some(Nullable::Value(typed)),
                Err(error) => {
                    record_degraded(name, error);
                    self.degraded.insert(name.to_owned(), value);
                    None
                }
            },
        }
    }

    /// The tri-state field of a strict object (an XRPC input): absent is
    /// `None`, `null` is `Some(Nullable::Null)`, and a value that does not
    /// decode is an error, never silently "absent".
    pub fn optional_nullable_strict<T: FromValue>(
        &mut self,
        name: &str,
    ) -> Result<Option<Nullable<T>>, DecodeError> {
        match self.fields.remove(name) {
            None => Ok(None),
            Some(Value::Null) => Ok(Some(Nullable::Null)),
            Some(value) => decode_field(name, value)
                .map(|typed| Some(Nullable::Value(typed)))
                .map_err(|error| error.in_field(name)),
        }
    }

    /// Wire names of the optional fields that failed to decode so far. The
    /// strict decode API is "decode, then require this to be empty".
    pub fn degraded(&self) -> impl Iterator<Item = &str> {
        self.degraded.keys().map(String::as_str)
    }

    /// Finishes while rejecting optional fields that failed typed decoding.
    /// Unknown fields remain valid and are returned as extra data.
    pub fn finish_strict(self) -> Result<Option<BTreeMap<String, Value>>, DecodeError> {
        if let Some((key, _)) = self.degraded.first_key_value() {
            return Err(DecodeError::DegradedField(key.clone()));
        }
        Ok(self.finish())
    }

    /// Finishes an object or record: everything not read (minus `$type`) plus
    /// the raw form of every degraded field, or `None` when there is nothing.
    /// This is the type's `extra_data`.
    pub fn finish(mut self) -> Option<BTreeMap<String, Value>> {
        self.fields.remove("$type");
        self.fields.append(&mut self.degraded);
        (!self.fields.is_empty()).then_some(self.fields)
    }
}

/// Writes the fields of one object. See the [module docs](self) for the rules.
#[derive(Debug, Default)]
pub struct ObjectWriter {
    fields: BTreeMap<String, Value>,
}

impl ObjectWriter {
    /// Starts an object with no `$type` (named and inline object defs).
    pub fn new() -> Self {
        Self::default()
    }

    /// Starts an object that carries `$type` (records, blobs).
    pub fn with_type(type_id: &str) -> Self {
        let mut writer = Self::default();
        writer
            .fields
            .insert("$type".to_owned(), Value::String(type_id.to_owned()));
        writer
    }

    fn put(&mut self, name: &str, value: &(impl ToValue + ?Sized)) -> Result<(), EncodeError> {
        let value = value.to_value().map_err(|error| EncodeError::Field {
            field: name.to_owned(),
            source: Box::new(error),
        })?;
        self.fields.insert(name.to_owned(), value);
        Ok(())
    }

    /// A required field.
    pub fn field(
        &mut self,
        name: &str,
        value: &(impl ToValue + ?Sized),
    ) -> Result<(), EncodeError> {
        self.put(name, value)
    }

    /// An optional field: omitted when `None`.
    pub fn optional<T: ToValue>(
        &mut self,
        name: &str,
        value: &Option<T>,
    ) -> Result<(), EncodeError> {
        match value {
            Some(value) => self.put(name, value),
            None => Ok(()),
        }
    }

    /// A required, nullable field: always written, `null` when `None`.
    pub fn required_nullable<T: ToValue>(
        &mut self,
        name: &str,
        value: &Option<T>,
    ) -> Result<(), EncodeError> {
        match value {
            Some(value) => self.put(name, value),
            None => self.put(name, &Value::Null),
        }
    }

    /// An optional, nullable field: omitted when `None`, `null` for
    /// `Some(Nullable::Null)`.
    pub fn optional_nullable<T: ToValue>(
        &mut self,
        name: &str,
        value: &Option<Nullable<T>>,
    ) -> Result<(), EncodeError> {
        self.optional(name, value)
    }

    /// Writes `extra_data` back. A key that a typed field already wrote is
    /// skipped, which is what makes "the raw form of a degraded field is
    /// written back only while the typed field is `None`" true.
    pub fn extra(&mut self, extra: Option<&BTreeMap<String, Value>>) {
        for (key, value) in extra.into_iter().flatten() {
            self.fields
                .entry(key.clone())
                .or_insert_with(|| value.clone());
        }
    }

    /// The finished object.
    pub fn finish(self) -> Value {
        Value::Object(self.fields)
    }
}
