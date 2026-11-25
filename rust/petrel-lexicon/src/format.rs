//! AT Protocol Lexicon string formats and strict syntax validation.

use std::fmt;

use petrel_core::{
    AtIdentifier, AtUri, CidString, Datetime, Did, Handle, Language, Nsid, RecordKey, SpaceRef,
    Tid, Uri,
};
use serde::{Deserialize, Deserializer, Serialize, Serializer};

/// String `format` specifier on a Lexicon string schema.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum LexStringFormat {
    /// Decentralized Identifier (`did:method:id`).
    Did,
    /// DNS hostname handle.
    Handle,
    /// Either a DID or a handle.
    AtIdentifier,
    /// Namespaced Identifier (`com.example.foo`).
    Nsid,
    /// AT-URI (`at://...` or PR #90 `at:space/...`).
    AtUri,
    /// Generic RFC 3986 URI (`scheme:...`).
    Uri,
    /// Content Identifier string.
    Cid,
    /// AT Protocol RFC 3339 / ISO 8601 timestamp.
    Datetime,
    /// BCP-47 language tag.
    Language,
    /// Timestamp Identifier (13-char base32-sortable).
    Tid,
    /// Repository record key (`rkey`).
    RecordKey,
    /// Any non-v1 string format name (e.g. `"space-ref"` in permissioned-spaces drafts).
    Custom(String),
}

impl LexStringFormat {
    /// The 11 string formats defined in Lexicon version 1.
    pub const STANDARD: &'static [Self] = &[
        Self::Did,
        Self::Handle,
        Self::AtIdentifier,
        Self::Nsid,
        Self::AtUri,
        Self::Uri,
        Self::Cid,
        Self::Datetime,
        Self::Language,
        Self::Tid,
        Self::RecordKey,
    ];

    /// Parse a wire `"format"` string into a [`LexStringFormat`].
    pub fn parse(raw: &str) -> Self {
        match raw {
            "did" => Self::Did,
            "handle" => Self::Handle,
            "at-identifier" => Self::AtIdentifier,
            "nsid" => Self::Nsid,
            "at-uri" => Self::AtUri,
            "uri" => Self::Uri,
            "cid" => Self::Cid,
            "datetime" => Self::Datetime,
            "language" => Self::Language,
            "tid" => Self::Tid,
            "record-key" => Self::RecordKey,
            other => Self::Custom(other.to_owned()),
        }
    }

    /// The wire format name (e.g. `"at-uri"`, `"space-ref"`).
    pub fn as_str(&self) -> &str {
        match self {
            Self::Did => "did",
            Self::Handle => "handle",
            Self::AtIdentifier => "at-identifier",
            Self::Nsid => "nsid",
            Self::AtUri => "at-uri",
            Self::Uri => "uri",
            Self::Cid => "cid",
            Self::Datetime => "datetime",
            Self::Language => "language",
            Self::Tid => "tid",
            Self::RecordKey => "record-key",
            Self::Custom(name) => name.as_str(),
        }
    }

    /// Returns `true` if this format is one of the 11 standard Lexicon v1 string formats.
    pub const fn is_standard(&self) -> bool {
        !matches!(self, Self::Custom(_))
    }

    /// Returns `true` when `value` satisfies this string format's syntax rules.
    pub fn is_valid(&self, value: &str) -> bool {
        match self {
            Self::Did => Did::parse(value).is_ok(),
            Self::Handle => Handle::parse(value).is_ok(),
            Self::AtIdentifier => AtIdentifier::parse(value).is_ok(),
            Self::Nsid => Nsid::parse(value).is_ok(),
            Self::AtUri => is_valid_at_uri(value),
            Self::Uri => Uri::parse(value).is_ok(),
            Self::Cid => CidString::parse(value).is_ok(),
            Self::Datetime => Datetime::parse(value).is_ok(),
            Self::Language => Language::parse_validated(value).is_ok(),
            Self::Tid => Tid::parse(value).is_ok(),
            Self::RecordKey => RecordKey::parse(value).is_ok(),
            Self::Custom(name) if name == "space-ref" => SpaceRef::parse(value).is_ok(),
            Self::Custom(_) => true,
        }
    }
}

fn is_valid_at_uri(value: &str) -> bool {
    if value.starts_with("at:space/") {
        return AtUri::parse(value).is_ok();
    }
    if AtUri::parse(value).is_err() {
        return false;
    }
    if let Some((_, fragment)) = value.split_once('#') {
        return is_valid_at_uri_fragment(fragment);
    }
    true
}

fn is_valid_at_uri_fragment(fragment: &str) -> bool {
    if fragment.is_empty() || !fragment.starts_with('/') {
        return false;
    }
    for byte in fragment.bytes() {
        let valid = byte.is_ascii_alphanumeric()
            || matches!(
                byte,
                b'%' | b'/'
                    | b'-'
                    | b'_'
                    | b'.'
                    | b'~'
                    | b'!'
                    | b'$'
                    | b'&'
                    | b'\''
                    | b'('
                    | b')'
                    | b'*'
                    | b'+'
                    | b','
                    | b';'
                    | b'='
                    | b':'
                    | b'@'
            );
        if !valid {
            return false;
        }
    }
    true
}

impl fmt::Display for LexStringFormat {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

impl Serialize for LexStringFormat {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(self.as_str())
    }
}

impl<'de> Deserialize<'de> for LexStringFormat {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let raw = String::deserialize(deserializer)?;
        Ok(Self::parse(&raw))
    }
}
