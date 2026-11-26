//! AT Protocol Lexicon document AST and JSON serialization.

use std::collections::BTreeMap;
use std::fmt;

use serde::{Deserialize, Deserializer, Serialize, Serializer};
use thiserror::Error;

use crate::format::LexStringFormat;
use crate::value::LexValue;

/// Errors returned when decoding or encoding a [`LexiconDoc`].
#[derive(Debug, Error)]
pub enum LexiconCodingError {
    /// Failed to decode Lexicon JSON.
    #[error("failed to decode lexicon JSON: {0}")]
    JsonDecode(#[from] serde_json::Error),
}

/// Top-level AT Protocol Lexicon document.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexiconDoc {
    /// Lexicon specification version (always `1` in v1 schemas).
    pub lexicon: i64,
    /// Document NSID identifier (e.g. `"app.bsky.feed.post"`).
    pub id: String,
    /// Optional schema revision number.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub revision: Option<i64>,
    /// Optional human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Map of definition name (`"main"` or named fragment) to schema definition.
    pub defs: BTreeMap<String, LexiconDefinition>,
}

impl LexiconDoc {
    /// Decode a [`LexiconDoc`] from UTF-8 JSON bytes.
    pub fn from_json_bytes(bytes: &[u8]) -> Result<Self, LexiconCodingError> {
        Ok(serde_json::from_slice(bytes)?)
    }

    /// Encode this [`LexiconDoc`] to compact JSON bytes.
    pub fn to_json_bytes(&self) -> Result<Vec<u8>, LexiconCodingError> {
        Ok(serde_json::to_vec(self)?)
    }
}

/// Record key allocation constraint for `"type": "record"` and `"type": "space"`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LexRecordKeyType {
    /// `"tid"`
    Tid,
    /// `"nsid"`
    Nsid,
    /// `"any"`
    Any,
    /// `"literal:<value>"`
    Literal(String),
    /// Any other/unrecognized key rule string.
    Custom(String),
}

impl LexRecordKeyType {
    /// Parse a wire record-key specification string.
    pub fn parse(raw: &str) -> Self {
        match raw {
            "tid" => Self::Tid,
            "nsid" => Self::Nsid,
            "any" => Self::Any,
            _ => raw.strip_prefix("literal:").map_or_else(
                || Self::Custom(raw.to_owned()),
                |lit| Self::Literal(lit.to_owned()),
            ),
        }
    }

    /// Return the wire representation of this record-key rule.
    pub fn as_str(&self) -> String {
        match self {
            Self::Tid => "tid".to_owned(),
            Self::Nsid => "nsid".to_owned(),
            Self::Any => "any".to_owned(),
            Self::Literal(lit) => format!("literal:{lit}"),
            Self::Custom(other) => other.clone(),
        }
    }

    /// Validate a candidate record key against this rule.
    pub fn is_valid_key(&self, key: &str) -> bool {
        if petrel_core::RecordKey::parse(key).is_err() {
            return false;
        }
        match self {
            Self::Tid => petrel_core::Tid::parse(key).is_ok(),
            Self::Nsid => petrel_core::Nsid::parse(key).is_ok(),
            Self::Any => true,
            Self::Literal(expected) => key == expected,
            Self::Custom(_) => false,
        }
    }
}

impl fmt::Display for LexRecordKeyType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.as_str())
    }
}

impl Serialize for LexRecordKeyType {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(&self.as_str())
    }
}

impl<'de> Deserialize<'de> for LexRecordKeyType {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let raw = String::deserialize(deserializer)?;
        Ok(Self::parse(&raw))
    }
}

/// Every schema definition / property type supported in Lexicon JSON.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LexiconDefinition {
    /// `"record"` primary definition.
    Record(LexRecord),
    /// `"query"` XRPC GET definition.
    Query(LexXrpcQuery),
    /// `"procedure"` XRPC POST definition.
    Procedure(LexXrpcProcedure),
    /// `"subscription"` XRPC event-stream definition.
    Subscription(LexXrpcSubscription),
    /// `"permission-set"` OAuth permission bundle definition.
    PermissionSet(LexPermissionSet),
    /// Experimental `"space"` definition (outside Lexicon v1).
    Space(LexSpace),
    /// `"object"` schema.
    Object(LexObject),
    /// `"array"` schema.
    Array(LexArray),
    /// `"string"` schema.
    String(LexString),
    /// `"integer"` schema.
    Integer(LexInteger),
    /// `"boolean"` schema.
    Boolean(LexBoolean),
    /// `"bytes"` schema.
    Bytes(LexBytes),
    /// `"blob"` schema.
    Blob(LexBlob),
    /// `"cid-link"` schema.
    CidLink(LexCidLink),
    /// `"token"` nominal marker definition.
    Token(LexToken),
    /// `"unknown"` arbitrary data-model object schema.
    Unknown(LexUnknown),
    /// `"null"` schema.
    Null(LexNull),
    /// `"ref"` schema reference.
    Ref(LexRef),
    /// `"union"` open or closed schema union.
    Union(LexRefUnion),
    /// `"params"` query parameter schema.
    Params(LexXrpcParameters),
    /// Unrecognized `"type"` kept for lenient schema loading and error reporting.
    Unsupported {
        /// The raw `"type"` tag from the JSON document.
        kind: String,
    },
}

impl LexiconDefinition {
    /// Return the Lexicon wire `"type"` name for this definition.
    pub fn type_name(&self) -> &str {
        match self {
            Self::Record(_) => "record",
            Self::Query(_) => "query",
            Self::Procedure(_) => "procedure",
            Self::Subscription(_) => "subscription",
            Self::PermissionSet(_) => "permission-set",
            Self::Space(_) => "space",
            Self::Object(_) => "object",
            Self::Array(_) => "array",
            Self::String(_) => "string",
            Self::Integer(_) => "integer",
            Self::Boolean(_) => "boolean",
            Self::Bytes(_) => "bytes",
            Self::Blob(_) => "blob",
            Self::CidLink(_) => "cid-link",
            Self::Token(_) => "token",
            Self::Unknown(_) => "unknown",
            Self::Null(_) => "null",
            Self::Ref(_) => "ref",
            Self::Union(_) => "union",
            Self::Params(_) => "params",
            Self::Unsupported { kind } => kind.as_str(),
        }
    }

    /// Returns `true` if this is a primary RPC/record/token/permission-set definition.
    pub const fn is_primary_definition(&self) -> bool {
        matches!(
            self,
            Self::Record(_)
                | Self::Query(_)
                | Self::Procedure(_)
                | Self::Subscription(_)
                | Self::PermissionSet(_)
                | Self::Space(_)
        )
    }

    /// Returns `true` if this is a schema definition defined outside Lexicon v1.
    pub const fn is_experimental(&self) -> bool {
        matches!(self, Self::Space(_) | Self::Unsupported { .. })
    }
}

#[derive(Deserialize)]
#[serde(tag = "type")]
enum KnownLexiconDefinition {
    #[serde(rename = "record")]
    Record(LexRecord),
    #[serde(rename = "query")]
    Query(LexXrpcQuery),
    #[serde(rename = "procedure")]
    Procedure(LexXrpcProcedure),
    #[serde(rename = "subscription")]
    Subscription(LexXrpcSubscription),
    #[serde(rename = "permission-set")]
    PermissionSet(LexPermissionSet),
    #[serde(rename = "space")]
    Space(LexSpace),
    #[serde(rename = "object")]
    Object(LexObject),
    #[serde(rename = "array")]
    Array(LexArray),
    #[serde(rename = "string")]
    String(LexString),
    #[serde(rename = "integer")]
    Integer(LexInteger),
    #[serde(rename = "boolean")]
    Boolean(LexBoolean),
    #[serde(rename = "bytes")]
    Bytes(LexBytes),
    #[serde(rename = "blob")]
    Blob(LexBlob),
    #[serde(rename = "cid-link")]
    CidLink(LexCidLink),
    #[serde(rename = "token")]
    Token(LexToken),
    #[serde(rename = "unknown")]
    Unknown(LexUnknown),
    #[serde(rename = "null")]
    Null(LexNull),
    #[serde(rename = "ref")]
    Ref(LexRef),
    #[serde(rename = "union")]
    Union(LexRefUnion),
    #[serde(rename = "params")]
    Params(LexXrpcParameters),
}

#[derive(Serialize)]
#[serde(tag = "type")]
enum KnownLexiconDefinitionRef<'a> {
    #[serde(rename = "record")]
    Record(&'a LexRecord),
    #[serde(rename = "query")]
    Query(&'a LexXrpcQuery),
    #[serde(rename = "procedure")]
    Procedure(&'a LexXrpcProcedure),
    #[serde(rename = "subscription")]
    Subscription(&'a LexXrpcSubscription),
    #[serde(rename = "permission-set")]
    PermissionSet(&'a LexPermissionSet),
    #[serde(rename = "space")]
    Space(&'a LexSpace),
    #[serde(rename = "object")]
    Object(&'a LexObject),
    #[serde(rename = "array")]
    Array(&'a LexArray),
    #[serde(rename = "string")]
    String(&'a LexString),
    #[serde(rename = "integer")]
    Integer(&'a LexInteger),
    #[serde(rename = "boolean")]
    Boolean(&'a LexBoolean),
    #[serde(rename = "bytes")]
    Bytes(&'a LexBytes),
    #[serde(rename = "blob")]
    Blob(&'a LexBlob),
    #[serde(rename = "cid-link")]
    CidLink(&'a LexCidLink),
    #[serde(rename = "token")]
    Token(&'a LexToken),
    #[serde(rename = "unknown")]
    Unknown(&'a LexUnknown),
    #[serde(rename = "null")]
    Null(&'a LexNull),
    #[serde(rename = "ref")]
    Ref(&'a LexRef),
    #[serde(rename = "union")]
    Union(&'a LexRefUnion),
    #[serde(rename = "params")]
    Params(&'a LexXrpcParameters),
}

impl Serialize for LexiconDefinition {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let tagged = match self {
            Self::Record(v) => KnownLexiconDefinitionRef::Record(v),
            Self::Query(v) => KnownLexiconDefinitionRef::Query(v),
            Self::Procedure(v) => KnownLexiconDefinitionRef::Procedure(v),
            Self::Subscription(v) => KnownLexiconDefinitionRef::Subscription(v),
            Self::PermissionSet(v) => KnownLexiconDefinitionRef::PermissionSet(v),
            Self::Space(v) => KnownLexiconDefinitionRef::Space(v),
            Self::Object(v) => KnownLexiconDefinitionRef::Object(v),
            Self::Array(v) => KnownLexiconDefinitionRef::Array(v),
            Self::String(v) => KnownLexiconDefinitionRef::String(v),
            Self::Integer(v) => KnownLexiconDefinitionRef::Integer(v),
            Self::Boolean(v) => KnownLexiconDefinitionRef::Boolean(v),
            Self::Bytes(v) => KnownLexiconDefinitionRef::Bytes(v),
            Self::Blob(v) => KnownLexiconDefinitionRef::Blob(v),
            Self::CidLink(v) => KnownLexiconDefinitionRef::CidLink(v),
            Self::Token(v) => KnownLexiconDefinitionRef::Token(v),
            Self::Unknown(v) => KnownLexiconDefinitionRef::Unknown(v),
            Self::Null(v) => KnownLexiconDefinitionRef::Null(v),
            Self::Ref(v) => KnownLexiconDefinitionRef::Ref(v),
            Self::Union(v) => KnownLexiconDefinitionRef::Union(v),
            Self::Params(v) => KnownLexiconDefinitionRef::Params(v),
            Self::Unsupported { kind } => {
                #[derive(Serialize)]
                struct UnsupportedTag<'a> {
                    #[serde(rename = "type")]
                    kind: &'a str,
                }
                return UnsupportedTag { kind }.serialize(serializer);
            }
        };
        tagged.serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for LexiconDefinition {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let raw = serde_json::Value::deserialize(deserializer)?;
        let kind = raw
            .get("type")
            .and_then(serde_json::Value::as_str)
            .map(str::to_owned)
            .ok_or_else(|| serde::de::Error::missing_field("type"))?;

        match kind.as_str() {
            "record" | "query" | "procedure" | "subscription" | "permission-set" | "space"
            | "object" | "array" | "string" | "integer" | "boolean" | "bytes" | "blob"
            | "cid-link" | "token" | "unknown" | "null" | "ref" | "union" | "params" => {
                let known: KnownLexiconDefinition =
                    serde_json::from_value(raw).map_err(serde::de::Error::custom)?;
                Ok(match known {
                    KnownLexiconDefinition::Record(v) => Self::Record(v),
                    KnownLexiconDefinition::Query(v) => Self::Query(v),
                    KnownLexiconDefinition::Procedure(v) => Self::Procedure(v),
                    KnownLexiconDefinition::Subscription(v) => Self::Subscription(v),
                    KnownLexiconDefinition::PermissionSet(v) => Self::PermissionSet(v),
                    KnownLexiconDefinition::Space(v) => Self::Space(v),
                    KnownLexiconDefinition::Object(v) => Self::Object(v),
                    KnownLexiconDefinition::Array(v) => Self::Array(v),
                    KnownLexiconDefinition::String(v) => Self::String(v),
                    KnownLexiconDefinition::Integer(v) => Self::Integer(v),
                    KnownLexiconDefinition::Boolean(v) => Self::Boolean(v),
                    KnownLexiconDefinition::Bytes(v) => Self::Bytes(v),
                    KnownLexiconDefinition::Blob(v) => Self::Blob(v),
                    KnownLexiconDefinition::CidLink(v) => Self::CidLink(v),
                    KnownLexiconDefinition::Token(v) => Self::Token(v),
                    KnownLexiconDefinition::Unknown(v) => Self::Unknown(v),
                    KnownLexiconDefinition::Null(v) => Self::Null(v),
                    KnownLexiconDefinition::Ref(v) => Self::Ref(v),
                    KnownLexiconDefinition::Union(v) => Self::Union(v),
                    KnownLexiconDefinition::Params(v) => Self::Params(v),
                })
            }
            _ => Ok(Self::Unsupported { kind }),
        }
    }
}

/// `"record"` schema definition.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexRecord {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Record key allocation rule (`"tid"`, `"nsid"`, `"any"`, `"literal:self"`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub key: Option<LexRecordKeyType>,
    /// Record body object schema.
    pub record: LexObject,
}

/// Experimental `"space"` schema definition.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexSpace {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Space key allocation rule.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub key: Option<LexRecordKeyType>,
    /// Optional display title.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// Collection NSIDs hosted in this space.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub collections: Option<Vec<String>>,
}

/// `"query"` XRPC schema definition.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexXrpcQuery {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Query parameters schema.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parameters: Option<LexXrpcParameters>,
    /// Response body definition.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output: Option<LexXrpcBody>,
    /// Declared XRPC errors.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub errors: Option<Vec<LexXrpcError>>,
}

/// `"procedure"` XRPC schema definition.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexXrpcProcedure {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Query parameters schema.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parameters: Option<LexXrpcParameters>,
    /// Request body definition.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub input: Option<LexXrpcBody>,
    /// Response body definition.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output: Option<LexXrpcBody>,
    /// Declared XRPC errors.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub errors: Option<Vec<LexXrpcError>>,
}

/// `"subscription"` XRPC schema definition.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexXrpcSubscription {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Query parameters schema.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parameters: Option<LexXrpcParameters>,
    /// Streamed message union/object payload.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message: Option<LexXrpcSubscriptionMessage>,
    /// Declared XRPC errors.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub errors: Option<Vec<LexXrpcError>>,
}

/// `"params"` query parameter schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexXrpcParameters {
    /// Optional `"type": "params"` tag when serialized standalone.
    #[serde(rename = "type", default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Required parameter names.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub required: Option<Vec<String>>,
    /// Parameter property schemas.
    #[serde(default)]
    pub properties: BTreeMap<String, LexiconDefinition>,
}

/// Input or output body descriptor on an XRPC query or procedure.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexXrpcBody {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// MIME media type (e.g. `"application/json"` or `"*/*"`).
    pub encoding: String,
    /// Optional body JSON schema (`object`, `ref`, `union`, etc.).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub schema: Option<Box<LexiconDefinition>>,
}

/// Event message payload descriptor on an XRPC subscription.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexXrpcSubscriptionMessage {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Payload schema (usually a `union` or `object`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub schema: Option<Box<LexiconDefinition>>,
}

/// Declared XRPC error entry.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexXrpcError {
    /// Wire error identifier.
    pub name: String,
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

/// `"permission-set"` OAuth permission set definition.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexPermissionSet {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Short display title.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// Localized titles keyed by BCP-47 language tag.
    #[serde(
        rename = "title:lang",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub title_lang: Option<BTreeMap<String, String>>,
    /// Extended description shown in consent prompts.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
    /// Localized details keyed by BCP-47 language tag.
    #[serde(
        rename = "detail:lang",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub detail_lang: Option<BTreeMap<String, String>>,
    /// Individual OAuth permissions granted by this set.
    #[serde(default)]
    pub permissions: Vec<LexPermission>,
}

/// Single permission entry inside a [`LexPermissionSet`].
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexPermission {
    /// Discriminator (`"permission"`).
    #[serde(rename = "type", default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    /// Resource class (`"rpc"`, `"repo"`, `"blob"`, `"account"`, `"identity"`).
    pub resource: String,
    /// Target collection NSIDs (for `"repo"` permissions).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub collection: Option<Vec<String>>,
    /// Allowed RPC actions (`"create"`, `"update"`, `"delete"`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub action: Option<Vec<String>>,
    /// Allowed LXMs (NSIDs) for `"rpc"` permissions.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub lxm: Option<Vec<String>>,
    /// Audience (`"*"` or DID service ref).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub aud: Option<String>,
    /// Whether audience inheritance is enabled.
    #[serde(
        rename = "inheritAud",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub inherit_aud: Option<bool>,
    /// Allowed MIME types for `"blob"` permissions.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub accept: Option<Vec<String>>,
    /// Account attribute (`"email"`, `"repo"`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub attr: Option<String>,
}

/// `"object"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexObject {
    /// Optional `"type": "object"` tag (present on `record.record` bodies).
    #[serde(rename = "type", default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Required property names.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub required: Option<Vec<String>>,
    /// Nullable property names.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub nullable: Option<Vec<String>>,
    /// Object properties keyed by JSON wire field name.
    #[serde(default)]
    pub properties: BTreeMap<String, LexiconDefinition>,
}

/// `"array"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexArray {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Schema for array elements.
    pub items: Box<LexiconDefinition>,
    /// Minimum item count.
    #[serde(rename = "minLength", default, skip_serializing_if = "Option::is_none")]
    pub min_length: Option<i64>,
    /// Maximum item count.
    #[serde(rename = "maxLength", default, skip_serializing_if = "Option::is_none")]
    pub max_length: Option<i64>,
}

/// `"string"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexString {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Optional AT Protocol string format constraint.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub format: Option<LexStringFormat>,
    /// Default string value.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default: Option<String>,
    /// Constant string value.
    #[serde(rename = "const", default, skip_serializing_if = "Option::is_none")]
    pub const_value: Option<String>,
    /// Closed enumeration of permitted string values.
    #[serde(rename = "enum", default, skip_serializing_if = "Option::is_none")]
    pub enum_values: Option<Vec<String>>,
    /// Open list of known/suggested string values.
    #[serde(
        rename = "knownValues",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub known_values: Option<Vec<String>>,
    /// Minimum UTF-8 byte length.
    #[serde(rename = "minLength", default, skip_serializing_if = "Option::is_none")]
    pub min_length: Option<i64>,
    /// Maximum UTF-8 byte length.
    #[serde(rename = "maxLength", default, skip_serializing_if = "Option::is_none")]
    pub max_length: Option<i64>,
    /// Minimum Unicode extended grapheme cluster count.
    #[serde(
        rename = "minGraphemes",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub min_graphemes: Option<i64>,
    /// Maximum Unicode extended grapheme cluster count.
    #[serde(
        rename = "maxGraphemes",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub max_graphemes: Option<i64>,
}

/// `"integer"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexInteger {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Default integer value.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default: Option<i64>,
    /// Constant integer value.
    #[serde(rename = "const", default, skip_serializing_if = "Option::is_none")]
    pub const_value: Option<i64>,
    /// Closed enumeration of permitted integer values.
    #[serde(rename = "enum", default, skip_serializing_if = "Option::is_none")]
    pub enum_values: Option<Vec<i64>>,
    /// Inclusive minimum bound.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub minimum: Option<i64>,
    /// Inclusive maximum bound.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub maximum: Option<i64>,
}

/// `"boolean"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexBoolean {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Default boolean value.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default: Option<bool>,
    /// Constant boolean value.
    #[serde(rename = "const", default, skip_serializing_if = "Option::is_none")]
    pub const_value: Option<bool>,
}

/// `"bytes"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexBytes {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Minimum byte length.
    #[serde(rename = "minLength", default, skip_serializing_if = "Option::is_none")]
    pub min_length: Option<i64>,
    /// Maximum byte length.
    #[serde(rename = "maxLength", default, skip_serializing_if = "Option::is_none")]
    pub max_length: Option<i64>,
}

/// `"blob"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexBlob {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Allowed MIME patterns (e.g. `["image/*", "video/mp4"]`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub accept: Option<Vec<String>>,
    /// Maximum allowed blob byte size.
    #[serde(rename = "maxSize", default, skip_serializing_if = "Option::is_none")]
    pub max_size: Option<i64>,
}

/// `"cid-link"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexCidLink {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

/// `"token"` nominal definition.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexToken {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

/// `"unknown"` arbitrary ATProto object schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexUnknown {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Unused extra default if any; preserved for round-trip fidelity.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default: Option<LexValue>,
}

/// `"null"` schema.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexNull {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

/// `"ref"` schema reference (`#fragment` or `nsid#fragment`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexRef {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Reference string (`"#def"` or `"com.example.nsid#def"` or `"com.example.nsid"`).
    #[serde(rename = "ref")]
    pub target: String,
}

/// `"union"` open or closed schema union.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexRefUnion {
    /// Human-readable description.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Member schema references.
    #[serde(default)]
    pub refs: Vec<String>,
    /// When `true`, unknown `$type` values are rejected.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub closed: Option<bool>,
}
