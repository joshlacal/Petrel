use std::cell::RefCell;
use std::collections::BTreeMap;
use std::fmt;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD;
use petrel_core::{Cid, Nsid, Value, dagcbor};
use serde::de::{self, DeserializeSeed, Deserializer, MapAccess, SeqAccess, Visitor};
use serde_json::{Map as JsonMap, Value as JsonValue};

use crate::error::{RecordCodecError, RecordJsonError};
use crate::limits::RepositoryLimits;
use crate::types::RepositoryReadPolicy;

/// Maximum integer magnitude permitted in strict AT Protocol records (`2^53 - 1`).
pub const MAX_SAFE_INT: i64 = 9_007_199_254_740_991;
/// Minimum integer magnitude permitted in strict AT Protocol records (`-(2^53 - 1)`).
pub const MIN_SAFE_INT: i64 = -9_007_199_254_740_991;
/// Maximum nested depth permitted for AT Protocol records.
pub const MAX_RECORD_DEPTH: usize = 64;

/// Alias for an AT Protocol data-model value inside a repository record.
pub type RecordValue = Value;

/// Typed blob reference (`$type == "blob"`) extracted from a validated record.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TypedBlobReference {
    pub cid: Cid,
    pub mime_type: String,
    pub size: u64,
}

/// Canonical validated AT Protocol record (`PublicRecord`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Record {
    fields: BTreeMap<String, Value>,
}

impl Record {
    /// Wraps an already-constructed field map after validating AT Protocol
    /// data-model rules (strict policy by default).
    pub fn new(fields: BTreeMap<String, Value>) -> Result<Self, RecordCodecError> {
        RecordCodec::validate_record_map(&fields, &RepositoryReadPolicy::strict())?;
        Ok(Self { fields })
    }

    /// Wraps a field map under a custom [`RepositoryReadPolicy`].
    pub fn with_policy(
        fields: BTreeMap<String, Value>,
        policy: &RepositoryReadPolicy,
    ) -> Result<Self, RecordCodecError> {
        RecordCodec::validate_record_map(&fields, policy)?;
        Ok(Self { fields })
    }

    /// Parses strict AT Protocol JSON (`$link`, `$bytes`, exact integers, no floats)
    /// into a validated [`Record`].
    pub fn from_json_bytes(bytes: &[u8]) -> Result<Self, RecordCodecError> {
        Self::from_json_bytes_with_policy(bytes, &RepositoryReadPolicy::strict())
    }

    /// Parses AT Protocol JSON under `policy`.
    pub fn from_json_bytes_with_policy(
        bytes: &[u8],
        policy: &RepositoryReadPolicy,
    ) -> Result<Self, RecordCodecError> {
        let value = parse_strict_json(bytes, policy.requires_safe_integers)?;
        let Value::Object(fields) = value else {
            return Err(RecordJsonError::TopLevelNotObject.into());
        };
        RecordCodec::validate_record_map(&fields, policy)?;
        Ok(Self { fields })
    }

    /// Decodes strict DAG-CBOR bytes into a validated [`Record`].
    pub fn from_dag_cbor(bytes: &[u8]) -> Result<Self, RecordCodecError> {
        Self::from_dag_cbor_with_policy(bytes, &RepositoryReadPolicy::strict())
    }

    /// Decodes DAG-CBOR bytes into a [`Record`] under `policy`.
    pub fn from_dag_cbor_with_policy(
        bytes: &[u8],
        policy: &RepositoryReadPolicy,
    ) -> Result<Self, RecordCodecError> {
        let value = dagcbor::decode_with(bytes, dagcbor::Limits::REPOSITORY_BLOCK)
            .map_err(|err| RecordCodecError::InvalidDagCbor(err.to_string()))?;
        let Value::Object(fields) = value else {
            return Err(RecordCodecError::TopLevelNotMap);
        };
        RecordCodec::validate_record_map(&fields, policy)?;
        Ok(Self { fields })
    }

    pub fn fields(&self) -> &BTreeMap<String, Value> {
        &self.fields
    }

    pub fn into_fields(self) -> BTreeMap<String, Value> {
        self.fields
    }

    pub fn as_value(&self) -> Value {
        Value::Object(self.fields.clone())
    }

    pub fn get(&self, key: &str) -> Option<&Value> {
        self.fields.get(key)
    }

    /// Returns the `$type` NSID string if present.
    pub fn record_type(&self) -> Option<&str> {
        match self.fields.get("$type") {
            Some(Value::String(s)) => Some(s.as_str()),
            _ => None,
        }
    }

    /// Encodes the record as canonical DAG-CBOR bytes.
    pub fn to_dag_cbor(&self) -> Vec<u8> {
        dagcbor::encode(&Value::Object(self.fields.clone()))
    }

    /// Computes the canonical `dag-cbor` sha2-256 CID of this record.
    pub fn cid(&self) -> Cid {
        Cid::for_dag_cbor(&self.to_dag_cbor())
    }

    /// Serializes the record to deterministic AT Protocol JSON bytes (`$link`, `$bytes`).
    pub fn to_json_bytes(&self) -> Result<Vec<u8>, RecordJsonError> {
        encode_json_bytes(&Value::Object(self.fields.clone()))
    }

    /// Extracts all modern typed blob references (`$type == "blob"`) recursively.
    pub fn typed_blob_references(&self) -> Result<Vec<TypedBlobReference>, RecordCodecError> {
        let mut out = Vec::new();
        collect_typed_blobs(&Value::Object(self.fields.clone()), &mut out, 0)?;
        Ok(out)
    }

    /// Extracts all blob CIDs (both modern typed blobs and legacy `{cid, mimeType}` blobs).
    pub fn blob_cids(&self) -> Result<Vec<Cid>, RecordCodecError> {
        let mut out = Vec::new();
        collect_blob_cids(&Value::Object(self.fields.clone()), &mut out, 0)?;
        Ok(out)
    }
}

/// Prepared DAG-CBOR block and CID for a validated record (`PreparedPublicRecord`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PreparedRecord {
    pub record: Record,
    pub bytes: Vec<u8>,
    pub cid: Cid,
}

/// Stateless AT Protocol record validator and codec (`PublicRepositoryRecordCodec`).
#[derive(Debug, Clone, Copy, Default)]
pub struct RecordCodec;

impl RecordCodec {
    /// Validates and canonicalizes a record for writing to `expected_collection`.
    pub fn prepare_for_write(
        value: &Value,
        expected_collection: &Nsid,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<PreparedRecord, RecordCodecError> {
        let Value::Object(fields) = value else {
            return Err(RecordCodecError::TopLevelNotMap);
        };
        Self::validate_record_map(fields, policy)?;
        if policy.requires_record_type_to_match_collection {
            let Some(Value::String(record_type)) = fields.get("$type") else {
                return Err(RecordCodecError::InvalidTypeField(
                    "record missing required '$type' string".into(),
                ));
            };
            if record_type != expected_collection.as_str() {
                return Err(RecordCodecError::TypeCollectionMismatch {
                    expected: expected_collection.as_str().to_owned(),
                    actual: record_type.clone(),
                });
            }
        }
        let record = Record {
            fields: fields.clone(),
        };
        let bytes = record.to_dag_cbor();
        if bytes.len() > limits.max_single_block_bytes {
            return Err(RecordCodecError::BlockTooLarge {
                len: bytes.len(),
                limit: limits.max_single_block_bytes,
            });
        }
        let cid = Cid::for_dag_cbor(&bytes);
        Ok(PreparedRecord { record, bytes, cid })
    }

    /// Validates raw DAG-CBOR record bytes retrieved from a CAR/store against
    /// `expected_collection` and `policy`.
    pub fn validate_record_bytes(
        bytes: &[u8],
        expected_collection: Option<&Nsid>,
        policy: &RepositoryReadPolicy,
    ) -> Result<Record, RecordCodecError> {
        let record = Record::from_dag_cbor_with_policy(bytes, policy)?;
        if policy.requires_record_type_to_match_collection
            && let Some(collection) = expected_collection
        {
            match record.record_type() {
                Some(actual) if actual == collection.as_str() => {}
                Some(actual) => {
                    return Err(RecordCodecError::TypeCollectionMismatch {
                        expected: collection.as_str().to_owned(),
                        actual: actual.to_owned(),
                    });
                }
                None => {
                    return Err(RecordCodecError::InvalidTypeField(
                        "record missing required '$type'".into(),
                    ));
                }
            }
        }
        Ok(record)
    }

    pub fn validate_record_map(
        fields: &BTreeMap<String, Value>,
        policy: &RepositoryReadPolicy,
    ) -> Result<(), RecordCodecError> {
        if let Some(type_val) = fields.get("$type") {
            let Value::String(type_str) = type_val else {
                return Err(RecordCodecError::InvalidTypeField(
                    "$type must be a string".into(),
                ));
            };
            if Nsid::parse(type_str).is_err() {
                return Err(RecordCodecError::InvalidTypeField(format!(
                    "top-level $type {type_str:?} is not a valid NSID"
                )));
            }
        }
        for val in fields.values() {
            validate_value(val, *policy, 1)?;
        }
        Ok(())
    }
}

fn validate_value(
    val: &Value,
    policy: RepositoryReadPolicy,
    depth: usize,
) -> Result<(), RecordCodecError> {
    if depth > MAX_RECORD_DEPTH {
        return Err(RecordCodecError::DepthExceeded {
            max: MAX_RECORD_DEPTH,
        });
    }
    match val {
        Value::Null | Value::Bool(_) | Value::String(_) | Value::Bytes(_) => Ok(()),
        Value::Float(_) => Err(RecordCodecError::FloatingPointDisallowed),
        Value::Integer(n) => {
            if policy.requires_safe_integers && (*n < MIN_SAFE_INT || *n > MAX_SAFE_INT) {
                return Err(RecordCodecError::UnsafeInteger(*n));
            }
            Ok(())
        }
        Value::Link(cid) => {
            if policy.requires_blessed_links_in_records && !cid.is_blessed() {
                return Err(RecordCodecError::UnblessedLink(cid.to_string()));
            }
            Ok(())
        }
        Value::Array(items) => {
            for item in items {
                validate_value(item, policy, depth + 1)?;
            }
            Ok(())
        }
        Value::Object(map) => {
            if let Some(t) = map.get("$type") {
                let Value::String(kind) = t else {
                    return Err(RecordCodecError::InvalidTypeField(
                        "$type must be a string".into(),
                    ));
                };
                if kind.is_empty() {
                    return Err(RecordCodecError::InvalidTypeField(
                        "$type cannot be empty".into(),
                    ));
                }
                if kind == "blob" {
                    validate_typed_blob(map, policy)?;
                }
            }
            for child in map.values() {
                validate_value(child, policy, depth + 1)?;
            }
            Ok(())
        }
    }
}

fn validate_typed_blob(
    map: &BTreeMap<String, Value>,
    policy: RepositoryReadPolicy,
) -> Result<TypedBlobReference, RecordCodecError> {
    let Some(Value::Link(cid)) = map.get("ref") else {
        return Err(RecordCodecError::InvalidBlob(
            "blob object missing CID link 'ref'".into(),
        ));
    };
    if policy.requires_blessed_links_in_records && !cid.is_blessed() {
        return Err(RecordCodecError::UnblessedLink(cid.to_string()));
    }
    let Some(Value::String(mime_type)) = map.get("mimeType") else {
        return Err(RecordCodecError::InvalidBlob(
            "blob object missing string 'mimeType'".into(),
        ));
    };
    if !is_valid_mime_type(mime_type) {
        return Err(RecordCodecError::InvalidBlob(format!(
            "invalid blob mimeType {mime_type:?}"
        )));
    }
    let Some(Value::Integer(size)) = map.get("size") else {
        return Err(RecordCodecError::InvalidBlob(
            "blob object missing integer 'size'".into(),
        ));
    };
    if *size < 0 {
        return Err(RecordCodecError::InvalidBlob(format!(
            "blob size must be non-negative (got {size})"
        )));
    }
    if policy.requires_safe_integers && *size > MAX_SAFE_INT {
        return Err(RecordCodecError::UnsafeInteger(*size));
    }
    Ok(TypedBlobReference {
        cid: cid.clone(),
        mime_type: mime_type.clone(),
        size: (*size).cast_unsigned(),
    })
}

fn is_valid_mime_type(mime: &str) -> bool {
    let Some((major, rest)) = mime.split_once('/') else {
        return false;
    };
    let subtype = rest.split(';').next().unwrap_or("").trim();
    !major.is_empty()
        && !subtype.is_empty()
        && !major.chars().any(char::is_whitespace)
        && !subtype.chars().any(char::is_whitespace)
}

fn collect_typed_blobs(
    val: &Value,
    out: &mut Vec<TypedBlobReference>,
    depth: usize,
) -> Result<(), RecordCodecError> {
    if depth > MAX_RECORD_DEPTH {
        return Err(RecordCodecError::DepthExceeded {
            max: MAX_RECORD_DEPTH,
        });
    }
    match val {
        Value::Array(items) => {
            for item in items {
                collect_typed_blobs(item, out, depth + 1)?;
            }
        }
        Value::Object(map) => {
            if let Some(Value::String(kind)) = map.get("$type")
                && kind == "blob"
            {
                let blob = validate_typed_blob(map, RepositoryReadPolicy::data_model())?;
                out.push(blob);
            }
            for child in map.values() {
                collect_typed_blobs(child, out, depth + 1)?;
            }
        }
        _ => {}
    }
    Ok(())
}

fn collect_blob_cids(
    val: &Value,
    out: &mut Vec<Cid>,
    depth: usize,
) -> Result<(), RecordCodecError> {
    if depth > MAX_RECORD_DEPTH {
        return Err(RecordCodecError::DepthExceeded {
            max: MAX_RECORD_DEPTH,
        });
    }
    match val {
        Value::Array(items) => {
            for item in items {
                collect_blob_cids(item, out, depth + 1)?;
            }
        }
        Value::Object(map) => {
            if let Some(Value::String(kind)) = map.get("$type")
                && kind == "blob"
            {
                let blob = validate_typed_blob(map, RepositoryReadPolicy::data_model())?;
                out.push(blob.cid);
            } else if map.get("$type").is_none()
                && map.len() == 2
                && let (Some(Value::String(cid_str)), Some(Value::String(mime))) =
                    (map.get("cid"), map.get("mimeType"))
                && is_valid_mime_type(mime)
                && let Ok(cid) = Cid::parse(cid_str)
            {
                out.push(cid);
            }
            for child in map.values() {
                collect_blob_cids(child, out, depth + 1)?;
            }
        }
        _ => {}
    }
    Ok(())
}

/// Parses strict AT Protocol JSON (`RepositoryRecordJSON`):
/// rejects duplicate keys, floating-point tokens, and excessive nesting depth,
/// and accepts exact integer literals, `$link`, and `$bytes` wrappers.
pub fn parse_strict_json(bytes: &[u8], require_safe_int: bool) -> Result<Value, RecordJsonError> {
    let json_text = std::str::from_utf8(bytes).map_err(|_| RecordJsonError::InvalidUtf8)?;
    let error_slot = RefCell::new(None);
    let mut de = serde_json::Deserializer::from_str(json_text);
    let seed = StrictJsonSeed {
        require_safe_int,
        depth: 0,
        error: &error_slot,
    };
    let value = match seed.deserialize(&mut de) {
        Ok(val) => val,
        Err(err) => {
            if let Some(typed_err) = error_slot.into_inner() {
                return Err(typed_err);
            }
            return Err(RecordJsonError::Syntax(err.to_string()));
        }
    };
    de.end()
        .map_err(|err| RecordJsonError::Syntax(err.to_string()))?;
    Ok(value)
}

#[derive(Clone, Copy)]
struct StrictJsonSeed<'a> {
    require_safe_int: bool,
    depth: usize,
    error: &'a RefCell<Option<RecordJsonError>>,
}

impl StrictJsonSeed<'_> {
    fn fail<E: de::Error>(self, err: RecordJsonError) -> E {
        let mut guard = self.error.borrow_mut();
        if guard.is_none() {
            *guard = Some(err);
        }
        de::Error::custom("strict JSON validation failed")
    }

    fn check_integer<E: de::Error>(self, integer: i64) -> Result<Value, E> {
        if self.require_safe_int && !(MIN_SAFE_INT..=MAX_SAFE_INT).contains(&integer) {
            return Err(self.fail(RecordJsonError::IntegerOutOfRange(integer.to_string())));
        }
        Ok(Value::Integer(integer))
    }
}

impl<'de> DeserializeSeed<'de> for StrictJsonSeed<'_> {
    type Value = Value;

    fn deserialize<D: Deserializer<'de>>(self, deserializer: D) -> Result<Self::Value, D::Error> {
        if self.depth > MAX_RECORD_DEPTH {
            return Err(self.fail(RecordJsonError::DepthExceeded(MAX_RECORD_DEPTH)));
        }
        deserializer.deserialize_any(self)
    }
}

impl<'de> Visitor<'de> for StrictJsonSeed<'_> {
    type Value = Value;

    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("a strict AT Protocol JSON value")
    }

    fn visit_bool<E: de::Error>(self, v: bool) -> Result<Self::Value, E> {
        Ok(Value::Bool(v))
    }

    fn visit_i64<E: de::Error>(self, v: i64) -> Result<Self::Value, E> {
        self.check_integer(v)
    }

    fn visit_u64<E: de::Error>(self, v: u64) -> Result<Self::Value, E> {
        let integer = i64::try_from(v)
            .map_err(|_| self.fail::<E>(RecordJsonError::IntegerOutOfRange(v.to_string())))?;
        self.check_integer(integer)
    }

    fn visit_f64<E: de::Error>(self, _v: f64) -> Result<Self::Value, E> {
        Err(self.fail(RecordJsonError::FloatingPointDisallowed))
    }

    fn visit_str<E: de::Error>(self, v: &str) -> Result<Self::Value, E> {
        Ok(Value::String(v.to_owned()))
    }

    fn visit_string<E: de::Error>(self, v: String) -> Result<Self::Value, E> {
        Ok(Value::String(v))
    }

    fn visit_unit<E: de::Error>(self) -> Result<Self::Value, E> {
        Ok(Value::Null)
    }

    fn visit_none<E: de::Error>(self) -> Result<Self::Value, E> {
        Ok(Value::Null)
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<Self::Value, A::Error> {
        let mut out = Vec::with_capacity(seq.size_hint().unwrap_or(0));
        let child_seed = StrictJsonSeed {
            require_safe_int: self.require_safe_int,
            depth: self.depth + 1,
            error: self.error,
        };
        while let Some(item) = seq.next_element_seed(child_seed)? {
            out.push(item);
        }
        Ok(Value::Array(out))
    }

    fn visit_map<A: MapAccess<'de>>(self, mut access: A) -> Result<Self::Value, A::Error> {
        let mut map = BTreeMap::new();
        let child_seed = StrictJsonSeed {
            require_safe_int: self.require_safe_int,
            depth: self.depth + 1,
            error: self.error,
        };
        while let Some(key) = access.next_key::<String>()? {
            if map.contains_key(&key) {
                return Err(self.fail(RecordJsonError::DuplicateKey(key)));
            }
            let val = access.next_value_seed(child_seed)?;
            map.insert(key, val);
        }

        if let Some(link_val) = map.get("$link") {
            if map.len() != 1 {
                return Err(self.fail(RecordJsonError::InvalidSpecialWrapper(
                    "$link object cannot contain extra fields".into(),
                )));
            }
            let Value::String(cid_str) = link_val else {
                return Err(self.fail(RecordJsonError::InvalidSpecialWrapper(
                    "$link value must be a string".into(),
                )));
            };
            let cid = Cid::parse(cid_str).map_err(|err| {
                self.fail::<A::Error>(RecordJsonError::InvalidSpecialWrapper(format!(
                    "invalid $link CID: {err}"
                )))
            })?;
            return Ok(Value::Link(cid));
        }
        if let Some(bytes_val) = map.get("$bytes") {
            if map.len() != 1 {
                return Err(self.fail(RecordJsonError::InvalidSpecialWrapper(
                    "$bytes object cannot contain extra fields".into(),
                )));
            }
            let Value::String(b64) = bytes_val else {
                return Err(self.fail(RecordJsonError::InvalidSpecialWrapper(
                    "$bytes value must be a string".into(),
                )));
            };
            let decoded = decode_lenient_unpadded_base64(b64).map_err(|err| self.fail(err))?;
            return Ok(Value::Bytes(decoded));
        }

        Ok(Value::Object(map))
    }
}

fn decode_lenient_unpadded_base64(raw: &str) -> Result<Vec<u8>, RecordJsonError> {
    if raw.contains('=') {
        return Err(RecordJsonError::InvalidSpecialWrapper(
            "$bytes must use unpadded standard base64".into(),
        ));
    }
    base64::engine::general_purpose::STANDARD_NO_PAD
        .decode(raw)
        .map_err(|err| {
            RecordJsonError::InvalidSpecialWrapper(format!("invalid base64 in $bytes: {err}"))
        })
}

/// Encodes a [`Value`] as deterministic AT Protocol data-model JSON bytes.
pub fn encode_json_bytes(value: &Value) -> Result<Vec<u8>, RecordJsonError> {
    let json = value_to_json(value, 0)?;
    serde_json::to_vec(&json).map_err(|err| RecordJsonError::SerializationFailed(err.to_string()))
}

fn value_to_json(val: &Value, depth: usize) -> Result<JsonValue, RecordJsonError> {
    if depth > MAX_RECORD_DEPTH {
        return Err(RecordJsonError::DepthExceeded(MAX_RECORD_DEPTH));
    }
    match val {
        Value::Null => Ok(JsonValue::Null),
        Value::Bool(b) => Ok(JsonValue::Bool(*b)),
        Value::Integer(n) => Ok(JsonValue::Number((*n).into())),
        Value::String(s) => Ok(JsonValue::String(s.clone())),
        Value::Float(_) => Err(RecordJsonError::FloatingPointDisallowed),
        Value::Bytes(bytes) => {
            let mut map = JsonMap::new();
            let encoded = STANDARD.encode(bytes);
            let unpadded = encoded.trim_end_matches('=').to_owned();
            map.insert("$bytes".to_owned(), JsonValue::String(unpadded));
            Ok(JsonValue::Object(map))
        }
        Value::Link(cid) => {
            let mut map = JsonMap::new();
            map.insert("$link".to_owned(), JsonValue::String(cid.to_string()));
            Ok(JsonValue::Object(map))
        }
        Value::Array(items) => {
            let mut out = Vec::with_capacity(items.len());
            for item in items {
                out.push(value_to_json(item, depth + 1)?);
            }
            Ok(JsonValue::Array(out))
        }
        Value::Object(obj) => {
            let mut map = JsonMap::new();
            for (k, v) in obj {
                map.insert(k.clone(), value_to_json(v, depth + 1)?);
            }
            Ok(JsonValue::Object(map))
        }
    }
}
