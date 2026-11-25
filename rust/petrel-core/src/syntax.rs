//! Lexicon identifiers with validated syntax and verbatim wire values.

use std::fmt;
use std::hash::{Hash, Hasher};
use std::str::FromStr;

mod validate;
use crate::Cid;
use crate::error::{DecodeError, EncodeError, SyntaxError, SyntaxKind};
use crate::serde_bridge::{FromValue, ToValue};
use crate::value::{Value, serde_via_value};
use crate::xrpc::QueryValue;

// The string conversions for identifiers all use the same checked parse path.
macro_rules! wire_string {
    ($name:ident, $query:ident, decode = $decode:ident) => {
        wire_string!(@impl $name, $query, $decode);
    };
    ($name:ident, $query:ident $(, $check:ident)?) => {
        wire_string!(@impl $name, $query, parse_owned $(, $check)?);
    };
    (@impl $name:ident, $query:ident, $decode:ident $(, $check:ident)?) => {
        impl $name {
            /// Validates and wraps a string.
            pub fn parse(value: impl Into<String>) -> Result<Self, SyntaxError> {
                Self::parse_owned(value.into())
            }
        }

        impl fmt::Display for $name {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                f.write_str(self.as_str())
            }
        }

        impl AsRef<str> for $name {
            fn as_ref(&self) -> &str {
                self.as_str()
            }
        }

        impl TryFrom<String> for $name {
            type Error = SyntaxError;

            fn try_from(value: String) -> Result<Self, Self::Error> {
                Self::parse_owned(value)
            }
        }

        impl FromStr for $name {
            type Err = SyntaxError;

            fn from_str(value: &str) -> Result<Self, Self::Err> {
                Self::parse_owned(value.to_owned())
            }
        }

        impl ToValue for $name {
            fn to_value(&self) -> Result<Value, EncodeError> {
                $(self.$check().map_err(|error| EncodeError::Custom(error.to_string()))?;)?
                Ok(Value::String(self.wire_value().to_owned()))
            }
        }

        impl FromValue for $name {
            fn from_value(value: Value) -> Result<Self, DecodeError> {
                Ok(Self::$decode(String::from_value(value)?)?)
            }
        }

        impl QueryValue for $name {
            fn to_query_value(&self) -> String {
                self.$query().to_owned()
            }
        }

        impl $crate::xrpc::FromQueryValue for $name {
            fn from_query_value(value: &str) -> Result<Self, DecodeError> {
                Ok(Self::parse_owned(value.to_owned())?)
            }
        }

        serde_via_value!($name);
    };
}

macro_rules! comparable_by {
    ($name:ident, $method:ident) => {
        impl PartialEq for $name {
            fn eq(&self, other: &Self) -> bool {
                self.$method() == other.$method()
            }
        }

        impl Eq for $name {}

        impl Hash for $name {
            fn hash<H: Hasher>(&self, state: &mut H) {
                self.$method().hash(state);
            }
        }

        impl PartialOrd for $name {
            fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
                Some(self.cmp(other))
            }
        }

        impl Ord for $name {
            fn cmp(&self, other: &Self) -> std::cmp::Ordering {
                self.$method().cmp(&other.$method())
            }
        }
    };
}

/// Declares a validated string newtype with the standard trait set.
macro_rules! string_newtype {
    ($(#[$meta:meta])* $name:ident, $kind:expr, $validate:path) => {
        $(#[$meta])*
        #[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
        pub struct $name(String);

        impl $name {
            /// Validates and wraps a string.
            pub fn parse(value: impl Into<String>) -> Result<Self, $crate::error::SyntaxError> {
                let value = value.into();
                $validate(&value)
                    .map_err(|reason| $crate::error::SyntaxError::new($kind, reason))?;
                Ok(Self(value))
            }

            /// The string exactly as it was given.
            pub fn as_str(&self) -> &str {
                &self.0
            }

            /// The original wire spelling.
            pub fn wire_value(&self) -> &str {
                self.as_str()
            }

            /// Unwraps the string exactly as it was given.
            pub fn into_string(self) -> String {
                self.0
            }
        }

        impl std::fmt::Display for $name {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                f.write_str(&self.0)
            }
        }

        impl std::str::FromStr for $name {
            type Err = $crate::error::SyntaxError;

            fn from_str(s: &str) -> Result<Self, Self::Err> {
                Self::parse(s)
            }
        }

        impl TryFrom<String> for $name {
            type Error = $crate::error::SyntaxError;

            fn try_from(value: String) -> Result<Self, Self::Error> {
                Self::parse(value)
            }
        }

        impl AsRef<str> for $name {
            fn as_ref(&self) -> &str {
                &self.0
            }
        }

        impl $crate::serde_bridge::ToValue for $name {
            fn to_value(&self) -> Result<$crate::value::Value, $crate::error::EncodeError> {
                Ok($crate::value::Value::String(self.0.clone()))
            }
        }

        impl $crate::serde_bridge::FromValue for $name {
            fn from_value(
                value: $crate::value::Value,
            ) -> Result<Self, $crate::error::DecodeError> {
                match value {
                    $crate::value::Value::String(text) => Ok(Self::parse(text)?),
                    other => Err($crate::error::DecodeError::TypeMismatch {
                        expected: "string",
                        found: other.kind(),
                    }),
                }
            }
        }

        impl $crate::xrpc::QueryValue for $name {
            fn to_query_value(&self) -> String {
                self.0.clone()
            }
        }

        impl $crate::xrpc::FromQueryValue for $name {
            fn from_query_value(value: &str) -> Result<Self, $crate::error::DecodeError> {
                Ok(Self::parse(value)?)
            }
        }

        $crate::value::serde_via_value!($name);
    };
}
pub(crate) use string_newtype;

/// The DID methods supported for AT Protocol account identifiers.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum AtprotoMethod {
    /// An identifier in the public ledger of credentials.
    Plc,
    /// An identifier hosted on the named web domain.
    Web,
}

/// A syntactically valid decentralized identifier (DID).
///
/// Use [`Did::atproto_method`] to check whether AT Protocol accepts its method.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Did {
    wire: String,
    method_end: usize,
}

impl Did {
    /// Unwraps the original wire spelling.
    pub fn into_string(self) -> String {
        self.wire
    }

    fn parse_owned(wire: String) -> Result<Self, SyntaxError> {
        let method_end =
            validate::did(&wire).map_err(|reason| SyntaxError::new(SyntaxKind::Did, reason))?;
        Ok(Self { wire, method_end })
    }

    /// Constructs a DID from its method and method-specific identifier.
    pub fn from_parts(method: &str, identifier: &str) -> Result<Self, SyntaxError> {
        Self::parse_owned(format!("did:{method}:{identifier}"))
    }

    /// The original wire spelling.
    pub fn as_str(&self) -> &str {
        &self.wire
    }

    /// The original wire spelling.
    pub fn wire_value(&self) -> &str {
        self.as_str()
    }

    /// The lowercase method between the first two colons.
    pub fn method(&self) -> &str {
        &self.wire[4..self.method_end]
    }

    /// The entire method-specific portion following the method.
    pub fn method_specific_identifier(&self) -> &str {
        &self.wire[self.method_end + 1..]
    }

    /// The first colon-separated segment of the method-specific identifier.
    pub fn authority(&self) -> &str {
        let identifier = self.method_specific_identifier();
        identifier
            .split_once(':')
            .map_or(identifier, |(head, _)| head)
    }

    /// The segments after the authority, including any empty segments.
    pub fn segments(&self) -> impl Iterator<Item = &str> {
        self.method_specific_identifier().split(':').skip(1)
    }

    /// The AT Protocol method, allowing localhost web identifiers for development.
    pub fn atproto_method(&self) -> Option<AtprotoMethod> {
        self.atproto_method_with_localhost(true)
    }

    /// The AT Protocol method, with explicit control over localhost web identifiers.
    pub fn atproto_method_with_localhost(&self, allow_localhost: bool) -> Option<AtprotoMethod> {
        let identifier = self.method_specific_identifier();
        match self.method() {
            "plc"
                if identifier.len() == 24
                    && identifier
                        .bytes()
                        .all(|b| b.is_ascii_lowercase() || (b'2'..=b'7').contains(&b)) =>
            {
                Some(AtprotoMethod::Plc)
            }
            "web" if !identifier.contains(':') => {
                let port = identifier
                    .as_bytes()
                    .windows(3)
                    .position(|part| part.eq_ignore_ascii_case(b"%3a"));
                let host = if let Some(index) = port {
                    let digits = &identifier[index + 3..];
                    let value = digits.parse::<u16>().ok()?;
                    if value == 0 || !digits.bytes().all(|b| b.is_ascii_digit()) {
                        return None;
                    }
                    &identifier[..index]
                } else {
                    identifier
                };
                let allowed = if host.eq_ignore_ascii_case("localhost") {
                    allow_localhost
                } else {
                    port.is_none() && validate::handle(host).is_ok() && allowed_handle_tld(host)
                };
                allowed.then_some(AtprotoMethod::Web)
            }
            _ => None,
        }
    }
}

wire_string!(Did, as_str);

const RESERVED_TLDS: &[&str] = &[
    "alt",
    "arpa",
    "example",
    "internal",
    "invalid",
    "local",
    "localhost",
    "onion",
];

fn allowed_handle_tld(handle: &str) -> bool {
    handle.rsplit_once('.').is_none_or(|(_, tld)| {
        !RESERVED_TLDS
            .iter()
            .any(|reserved| tld.eq_ignore_ascii_case(reserved))
    })
}

/// A handle with its wire spelling and its case-insensitive normalized value.
#[derive(Clone, Debug)]
pub struct Handle {
    wire: String,
    normalized: String,
}

impl Handle {
    /// Unwraps the original wire spelling.
    pub fn into_string(self) -> String {
        self.wire
    }

    fn parse_owned(wire: String) -> Result<Self, SyntaxError> {
        validate::handle(&wire).map_err(|reason| SyntaxError::new(SyntaxKind::Handle, reason))?;
        let normalized = wire.to_ascii_lowercase();
        Ok(Self { wire, normalized })
    }

    /// The original spelling used in JSON and DAG-CBOR.
    pub fn as_str(&self) -> &str {
        self.wire_value()
    }

    /// The lowercase handle used for comparisons and lookups.
    pub fn normalized(&self) -> &str {
        &self.normalized
    }

    /// The original spelling used in JSON and DAG-CBOR.
    pub fn wire_value(&self) -> &str {
        &self.wire
    }

    /// Whether the handle is outside the reserved top-level domains.
    pub fn is_valid_tld(&self) -> bool {
        allowed_handle_tld(self.normalized())
    }

    /// Whether this is the reserved placeholder for an invalid handle.
    pub fn is_invalid_sentinel(&self) -> bool {
        self.normalized() == "handle.invalid"
    }
}

wire_string!(Handle, normalized);
comparable_by!(Handle, normalized);

/// Either a DID or a handle.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum AtIdentifier {
    /// A decentralized identifier.
    Did(Did),
    /// A handle.
    Handle(Handle),
}

impl AtIdentifier {
    fn parse_owned(value: String) -> Result<Self, SyntaxError> {
        let parsed = if value.starts_with("did:") {
            Did::parse_owned(value).map(Self::Did)
        } else {
            Handle::parse_owned(value).map(Self::Handle)
        };
        parsed.map_err(|error| SyntaxError::new(SyntaxKind::AtIdentifier, error.reason))
    }

    /// The original wire spelling.
    pub fn as_str(&self) -> &str {
        self.wire_value()
    }

    /// The DID or lowercase handle.
    pub fn normalized(&self) -> &str {
        match self {
            Self::Did(did) => did.as_str(),
            Self::Handle(handle) => handle.normalized(),
        }
    }

    /// The original spelling used in JSON and DAG-CBOR.
    pub fn wire_value(&self) -> &str {
        match self {
            Self::Did(did) => did.wire_value(),
            Self::Handle(handle) => handle.wire_value(),
        }
    }
}

impl From<Did> for AtIdentifier {
    fn from(did: Did) -> Self {
        Self::Did(did)
    }
}

impl From<Handle> for AtIdentifier {
    fn from(handle: Handle) -> Self {
        Self::Handle(handle)
    }
}

wire_string!(AtIdentifier, normalized);

/// A lexicon namespace identifier.
#[derive(Clone, Debug)]
pub struct Nsid {
    wire: String,
    normalized: String,
    name_start: usize,
}

impl Nsid {
    /// Unwraps the original wire spelling.
    pub fn into_string(self) -> String {
        self.wire
    }

    fn parse_owned(wire: String) -> Result<Self, SyntaxError> {
        let name_start =
            validate::nsid(&wire).map_err(|reason| SyntaxError::new(SyntaxKind::Nsid, reason))?;
        let mut normalized = wire.clone();
        normalized[..name_start].make_ascii_lowercase();
        Ok(Self {
            wire,
            normalized,
            name_start,
        })
    }

    /// The original wire spelling.
    pub fn as_str(&self) -> &str {
        &self.wire
    }

    /// The original wire spelling.
    pub fn wire_value(&self) -> &str {
        self.as_str()
    }

    /// The spelling with the authority lowercased and the name preserved.
    pub fn normalized(&self) -> &str {
        &self.normalized
    }

    /// The original namespace authority, excluding the final name.
    pub fn authority(&self) -> &str {
        &self.wire[..self.name_start - 1]
    }

    /// The case-sensitive final name.
    pub fn name(&self) -> &str {
        &self.wire[self.name_start..]
    }
}

wire_string!(Nsid, as_str);
comparable_by!(Nsid, normalized);

string_newtype!(
    /// An AT Protocol repository record key.
    RecordKey,
    SyntaxKind::RecordKey,
    validate::record_key
);

string_newtype!(
    /// A lexicon CID string, checked for syntax without decoding its multibase.
    CidString,
    SyntaxKind::Cid,
    validate::cid_string
);

impl CidString {
    /// Decodes the string when it contains a canonical, AT Protocol blessed CID.
    pub fn cid(&self) -> Option<Cid> {
        Cid::parse_blessed(self.as_str()).ok()
    }
}

/// A base32-sortable AT Protocol timestamp identifier.
#[derive(Clone, Debug)]
pub struct Tid {
    wire: String,
    value: u64,
}

impl Tid {
    /// Unwraps the original wire spelling.
    pub fn into_string(self) -> String {
        self.wire
    }

    /// The maximum timestamp accepted when constructing a TID from its parts.
    pub const MAX_TIMESTAMP_MICROS: u64 = (1 << 53) - 1;

    fn parse_owned(wire: String) -> Result<Self, SyntaxError> {
        let value =
            validate::tid(&wire).map_err(|reason| SyntaxError::new(SyntaxKind::Tid, reason))?;
        Ok(Self { wire, value })
    }

    /// Constructs a TID from its 53-bit timestamp and 10-bit clock ID.
    pub fn from_parts(timestamp_micros: u64, clock_id: u16) -> Result<Self, SyntaxError> {
        if timestamp_micros > Self::MAX_TIMESTAMP_MICROS {
            return Err(SyntaxError::new(
                SyntaxKind::Tid,
                "timestamp exceeds 53 bits",
            ));
        }
        if clock_id >= 1024 {
            return Err(SyntaxError::new(
                SyntaxKind::Tid,
                "clock ID exceeds 10 bits",
            ));
        }
        let value = (timestamp_micros << 10) | u64::from(clock_id);
        Ok(Self {
            value,
            wire: validate::tid_string(value),
        })
    }

    /// The original wire spelling.
    pub fn as_str(&self) -> &str {
        &self.wire
    }

    /// The original wire spelling.
    pub fn wire_value(&self) -> &str {
        self.as_str()
    }

    /// The decoded numeric value, including the high bit when present.
    pub fn value(&self) -> u64 {
        self.value
    }

    /// Whether the high bit is set. These TIDs parse but cannot be generated.
    pub fn has_high_bit(&self) -> bool {
        self.value >> 63 != 0
    }

    /// The timestamp bits, without the reserved high bit.
    pub fn timestamp_micros(&self) -> u64 {
        (self.value >> 10) & Self::MAX_TIMESTAMP_MICROS
    }

    /// The clock ID in the low 10 bits.
    pub fn clock_id(&self) -> u16 {
        (self.value & 1023) as u16
    }
}

wire_string!(Tid, as_str);
comparable_by!(Tid, value);

/// Which path forms an AT URI parser accepts.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum Grammar {
    /// Only the standard authority, collection and record key:
    /// `at://AUTHORITY[/COLLECTION[/RKEY]]`.
    Restricted,
    /// Standard AT URIs plus the permissioned-data space grammar
    /// `at:space/SPACE-DID/SPACE-TYPE/SKEY[/AUTHOR-DID/COLLECTION/RKEY]`.
    #[default]
    RestrictedOrSpace,
}

/// The prefix of every space URI.
pub const SPACE_URI_PREFIX: &str = "at:space/";

/// An AT Protocol URI: the Lexicon `at-uri` string format, including the
/// permissioned-data space form
/// `at:space/SPACE-DID/SPACE-TYPE/SKEY[/AUTHOR-DID/COLLECTION/RKEY]`.
///
/// Both the space and the author must be DIDs. Parsing ([`AtUri::parse`],
/// [`FromStr`]) rejects the spaces alpha form `at://SPACE-DID/space/…`.
/// Decoding a record value still accepts it, because records written during
/// the alpha may embed it and their CIDs cover those bytes: the decoded value
/// keeps the string as written, while [`AtUri::normalized`] and query values
/// use the `at:space/` form. See [`AtUri::from_legacy_space_uri`].
#[derive(Clone, Debug)]
pub struct AtUri {
    wire: String,
    /// The `at:space/` spelling of a URI decoded from the spaces alpha form.
    // TODO: remove before beta, with `from_legacy_space_uri`.
    current: Option<String>,
    authority: AtIdentifier,
    collection: Option<Nsid>,
    key: Option<RecordKey>,
    space: Option<SpacePath>,
}

#[derive(Clone, Debug)]
struct SpacePath {
    space_type: Nsid,
    key: RecordKey,
    author: Option<Did>,
}

impl AtUri {
    /// Unwraps the original wire spelling.
    pub fn into_string(self) -> String {
        self.wire
    }

    fn parse_owned(wire: String) -> Result<Self, SyntaxError> {
        Self::parse_owned_with_grammar(wire, Grammar::default())
    }

    /// Decodes a wire value. Unlike parsing, this also accepts the spaces
    /// alpha form `at://SPACE-DID/space/…`, keeping the string as written.
    // TODO: remove the legacy branch before beta, with `from_legacy_space_uri`.
    fn decode_owned(wire: String) -> Result<Self, SyntaxError> {
        if wire.len() <= 8192
            && let Some(current) = Self::from_legacy_space_uri(&wire)
        {
            let parsed = Self::parse_space(&current[SPACE_URI_PREFIX.len()..])?;
            return Ok(Self {
                wire,
                current: Some(current),
                ..parsed
            });
        }
        Self::parse_owned(wire)
    }

    /// Rewrites a space URI in its spaces alpha form,
    /// `at://{spaceDid}/space/{rest}`, as `at:space/{spaceDid}/{rest}`.
    /// Returns `None` for any other input. The result is not validated.
    ///
    /// Only for record values read back from storage or the network, which may
    /// embed the old form; requests, space refs, credentials and MAC headers
    /// take the current form only.
    // TODO: remove before beta, along with support for the old form.
    pub fn from_legacy_space_uri(wire: &str) -> Option<String> {
        // Mirrors `^at:\/\/([^/?#\s]+)\/space\/` upstream.
        let rest = wire.strip_prefix("at://")?;
        let (authority, after) = rest.split_once('/')?;
        let excluded =
            |c: char| matches!(c, '?' | '#' | ' ' | '\t' | '\n' | '\u{b}' | '\u{c}' | '\r');
        if authority.is_empty() || authority.contains(excluded) {
            return None;
        }
        let tail = after.strip_prefix("space/")?;
        Some(format!("{SPACE_URI_PREFIX}{authority}/{tail}"))
    }

    /// Parses with an explicit choice of AT URI grammar.
    pub fn parse_with_grammar(wire: &str, grammar: Grammar) -> Result<Self, SyntaxError> {
        Self::parse_owned_with_grammar(wire.to_owned(), grammar)
    }

    fn parse_owned_with_grammar(wire: String, grammar: Grammar) -> Result<Self, SyntaxError> {
        let failure = |reason| SyntaxError::new(SyntaxKind::AtUri, reason);
        if wire.len() > 8192 {
            return Err(failure("longer than 8192 bytes"));
        }
        if grammar == Grammar::RestrictedOrSpace {
            if let Some(body) = wire.strip_prefix(SPACE_URI_PREFIX) {
                let parsed = Self::parse_space(body)?;
                return Ok(Self { wire, ..parsed });
            }
            // TODO: remove before beta, with `from_legacy_space_uri`.
            if Self::from_legacy_space_uri(&wire).is_some() {
                return Err(failure("a space URI must start with at:space/"));
            }
        }
        let rest = wire.strip_prefix("at://").ok_or_else(|| {
            failure(match grammar {
                Grammar::Restricted => "must start with at://",
                Grammar::RestrictedOrSpace => "must start with at:// or at:space/",
            })
        })?;
        let (authority, path) = rest
            .split_once('/')
            .map_or((rest, None), |(a, p)| (a, Some(p)));
        let authority = authority
            .parse()
            .map_err(|_| failure("authority is neither a DID nor a handle"))?;
        // A third segment always makes the path invalid.
        let segments: Vec<_> = path
            .into_iter()
            .flat_map(|path| path.split('/'))
            .take(3)
            .collect();
        let nsid = |text: &str| {
            text.parse::<Nsid>()
                .map_err(|_| failure("collection is not an NSID"))
        };
        let key = |text: &str| {
            text.parse::<RecordKey>()
                .map_err(|_| failure("invalid record key"))
        };
        let (collection, key) = match segments.as_slice() {
            [] => (None, None),
            [collection] => (Some(nsid(collection)?), None),
            [collection, record_key] => (Some(nsid(collection)?), Some(key(record_key)?)),
            _ => return Err(failure("invalid path for the selected grammar")),
        };
        Ok(Self {
            wire,
            current: None,
            authority,
            collection,
            key,
            space: None,
        })
    }

    /// Validates the part of a space URI after `at:space/`:
    /// `{spaceDid}/{spaceType}/{skey}[/{authorDid}/{collection}/{rkey}]`.
    /// The returned value's wire string is empty; the caller sets it.
    fn parse_space(body: &str) -> Result<Self, SyntaxError> {
        let failure = |reason| SyntaxError::new(SyntaxKind::AtUri, reason);
        let segments: Vec<_> = body.split('/').take(7).collect();
        let did = |text: &str| {
            text.parse::<Did>()
                .map_err(|_| failure("the authority of a space URI must be a DID"))
        };
        let nsid = |text: &str| {
            text.parse::<Nsid>()
                .map_err(|_| failure("collection or space type is not an NSID"))
        };
        let key = |text: &str| {
            text.parse::<RecordKey>()
                .map_err(|_| failure("invalid record or space key"))
        };
        let (owner, collection, record_key, space) = match segments.as_slice() {
            [owner, space_type, skey] => (
                did(owner)?,
                None,
                None,
                SpacePath {
                    space_type: nsid(space_type)?,
                    key: key(skey)?,
                    author: None,
                },
            ),
            [owner, space_type, skey, author, collection, record_key] => {
                let owner = did(owner)?;
                let space = SpacePath {
                    space_type: nsid(space_type)?,
                    key: key(skey)?,
                    author: Some(
                        author
                            .parse()
                            .map_err(|_| failure("space record author is not a DID"))?,
                    ),
                };
                (
                    owner,
                    Some(nsid(collection)?),
                    Some(key(record_key)?),
                    space,
                )
            }
            _ => {
                return Err(failure(
                    "a space URI is at:space/{spaceDid}/{type}/{skey}, optionally followed by /{authorDid}/{collection}/{rkey}",
                ));
            }
        };
        Ok(Self {
            wire: String::new(),
            current: None,
            authority: AtIdentifier::Did(owner),
            collection,
            key: record_key,
            space: Some(space),
        })
    }

    /// Builds a standard AT URI. A record key requires a collection.
    pub fn from_parts(
        authority: &AtIdentifier,
        collection: Option<&Nsid>,
        key: Option<&RecordKey>,
    ) -> Result<Self, SyntaxError> {
        if key.is_some() && collection.is_none() {
            return Err(SyntaxError::new(
                SyntaxKind::AtUri,
                "a key requires a collection",
            ));
        }

        let mut wire = format!("at://{}", authority.wire_value());
        if let Some(collection) = collection {
            wire.push('/');
            wire.push_str(collection.as_str());
        }
        if let Some(key) = key {
            wire.push('/');
            wire.push_str(key.as_str());
        }
        Self::parse_owned_with_grammar(wire, Grammar::Restricted)
    }

    /// The original wire spelling.
    pub fn as_str(&self) -> &str {
        &self.wire
    }

    /// The original wire spelling.
    pub fn wire_value(&self) -> &str {
        self.as_str()
    }

    /// The spelling to send in a request: the wire spelling, except that a
    /// value decoded from the spaces alpha form is sent as `at:space/…`.
    // TODO: return `as_str` before beta, with `from_legacy_space_uri`.
    pub fn request_value(&self) -> &str {
        self.current.as_deref().unwrap_or(&self.wire)
    }

    /// Whether the value was decoded from the spaces alpha form
    /// `at://SPACE-DID/space/…`.
    pub fn is_legacy_space_form(&self) -> bool {
        self.current.is_some()
    }

    /// The URI authority. On a space URI this is the DID that owns the space.
    pub fn authority(&self) -> &AtIdentifier {
        &self.authority
    }

    /// The collection, if the URI names one.
    pub fn collection(&self) -> Option<&Nsid> {
        self.collection.as_ref()
    }

    /// The record key, if the URI names a record.
    pub fn rkey(&self) -> Option<&RecordKey> {
        self.key.as_ref()
    }

    /// Whether the URI identifies a space or a record inside a space.
    pub fn is_space(&self) -> bool {
        self.space.is_some()
    }

    /// The DID that owns the space.
    pub fn space_did(&self) -> Option<&Did> {
        match (&self.space, &self.authority) {
            (Some(_), AtIdentifier::Did(did)) => Some(did),
            _ => None,
        }
    }

    /// The NSID defining the space's type.
    pub fn space_type(&self) -> Option<&Nsid> {
        self.space.as_ref().map(|space| &space.space_type)
    }

    /// The key of the space.
    pub fn skey(&self) -> Option<&RecordKey> {
        self.space.as_ref().map(|space| &space.key)
    }

    /// The author DID, when the URI encodes it.
    pub fn author_did(&self) -> Option<&Did> {
        if let Some(space) = &self.space {
            space.author.as_ref()
        } else if let AtIdentifier::Did(did) = &self.authority {
            Some(did)
        } else {
            None
        }
    }

    /// The reference to the space itself, even for a URI to a record in it.
    pub fn space_ref(&self) -> Option<SpaceRef> {
        SpaceRef::from_parts(self.space_did()?, self.space_type()?, self.skey()?).ok()
    }

    /// The wire form with handle and NSID authorities lowercased. A space URI
    /// always comes out in the `at:space/` form, also when it was decoded from
    /// the spaces alpha form.
    #[must_use]
    pub fn normalized(&self) -> Self {
        use std::fmt::Write as _;

        let mut wire = if let Some(space) = &self.space {
            let mut wire = format!(
                "{SPACE_URI_PREFIX}{}/{}/{}",
                self.authority.normalized(),
                space.space_type.normalized(),
                space.key
            );
            if let Some(author) = &space.author {
                let _ = write!(wire, "/{author}");
            }
            wire
        } else {
            format!("at://{}", self.authority.normalized())
        };
        if let Some(collection) = &self.collection {
            let _ = write!(wire, "/{}", collection.normalized());
        }
        if let Some(key) = &self.key {
            let _ = write!(wire, "/{key}");
        }
        // The normalized components were already validated and ASCII case changes preserve syntax.
        Self::parse_owned(wire).unwrap_or_else(|_| self.clone())
    }
}

wire_string!(AtUri, request_value, decode = decode_owned);
comparable_by!(AtUri, as_str);

/// A reference to a permissioned-data space itself, as distinct from a record
/// within one: `at:space/{spaceDid}/{spaceType}/{skey}`.
///
/// This is the lexicon string format `space-ref`. Parsing is strict: the
/// spaces alpha form `at://{spaceDid}/space/…` is rejected, as by
/// `SpaceRef.parse` upstream.
#[derive(Clone, Debug)]
pub struct SpaceRef {
    wire: String,
    did: Did,
    space_type: Nsid,
    key: RecordKey,
}

impl SpaceRef {
    fn parse_owned(wire: String) -> Result<Self, SyntaxError> {
        let failure = || SyntaxError::new(SyntaxKind::SpaceRef, "requires at:space/DID/NSID/key");
        if wire.len() > 8192 {
            return Err(failure());
        }
        let mut parts = wire
            .strip_prefix(SPACE_URI_PREFIX)
            .ok_or_else(failure)?
            .split('/');
        let (Some(did), Some(space_type), Some(key), None) =
            (parts.next(), parts.next(), parts.next(), parts.next())
        else {
            return Err(failure());
        };
        let did = Did::parse(did)
            .map_err(|error| SyntaxError::new(SyntaxKind::SpaceRef, error.reason))?;
        let space_type = Nsid::parse(space_type)
            .map_err(|error| SyntaxError::new(SyntaxKind::SpaceRef, error.reason))?;
        let key = RecordKey::parse(key)
            .map_err(|error| SyntaxError::new(SyntaxKind::SpaceRef, error.reason))?;
        Ok(Self {
            wire,
            did,
            space_type,
            key,
        })
    }

    /// Constructs a space reference from its owner DID, type and key.
    pub fn from_parts(did: &Did, space_type: &Nsid, key: &RecordKey) -> Result<Self, SyntaxError> {
        Self::parse_owned(format!("{SPACE_URI_PREFIX}{did}/{space_type}/{key}"))
    }

    /// The original wire spelling.
    pub fn as_str(&self) -> &str {
        &self.wire
    }

    /// The original wire spelling.
    pub fn wire_value(&self) -> &str {
        self.as_str()
    }

    /// Unwraps the original wire spelling.
    pub fn into_string(self) -> String {
        self.wire
    }

    /// The space owner.
    pub fn space_did(&self) -> &Did {
        &self.did
    }

    /// The space's type.
    pub fn space_type(&self) -> &Nsid {
        &self.space_type
    }

    /// The space's key.
    pub fn skey(&self) -> &RecordKey {
        &self.key
    }

    /// Constructs a URI for a record published inside this space.
    pub fn record_uri(
        &self,
        author: &Did,
        collection: &Nsid,
        key: &RecordKey,
    ) -> Result<AtUri, SyntaxError> {
        AtUri::parse_owned(format!("{self}/{author}/{collection}/{key}"))
    }
}

comparable_by!(SpaceRef, as_str);
wire_string!(SpaceRef, as_str);

/// A generic URI with the AT Protocol lexicon's syntax restrictions.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Uri(String);

impl Uri {
    /// Unwraps the original wire spelling.
    pub fn into_string(self) -> String {
        self.0
    }

    fn parse_owned(wire: String) -> Result<Self, SyntaxError> {
        let result = Self(wire);
        result.validate()?;
        Ok(result)
    }

    fn validate(&self) -> Result<(), SyntaxError> {
        validate::uri(self.as_str()).map_err(|reason| SyntaxError::new(SyntaxKind::Uri, reason))
    }

    /// Stores the URI as given. Serializing it still requires valid syntax.
    pub fn new_unchecked(wire: impl Into<String>) -> Self {
        Self(wire.into())
    }

    /// Whether the value has valid URI syntax.
    pub fn has_valid_syntax(&self) -> bool {
        self.validate().is_ok()
    }

    /// The original wire spelling.
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// The original wire spelling.
    pub fn wire_value(&self) -> &str {
        self.as_str()
    }

    /// The scheme, when present and syntactically valid.
    pub fn scheme(&self) -> Option<&str> {
        let (scheme, _) = self.as_str().split_once(':')?;
        (scheme
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_alphabetic)
            && scheme
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'+' | b'-' | b'.')))
        .then_some(scheme)
    }
    /// The hostname for a hierarchical URI or the method for a DID URI.
    pub fn authority(&self) -> Option<&str> {
        self.components().authority
    }

    /// The URI path, if present.
    pub fn path(&self) -> Option<&str> {
        self.components().path
    }

    /// The URI query, if present.
    pub fn query(&self) -> Option<&str> {
        self.components().query
    }

    /// The URI fragment, if present.
    pub fn fragment(&self) -> Option<&str> {
        self.components().fragment
    }

    fn components(&self) -> UriComponents<'_> {
        let Some(scheme) = self.scheme() else {
            return UriComponents::default();
        };
        let rest = &self.0[scheme.len() + 1..];
        if scheme == "did" {
            let (method, path) = before_after(rest, ':');
            return UriComponents {
                authority: Some(method),
                path,
                ..UriComponents::default()
            };
        }
        if let Some(rest) = self.0.strip_prefix("at://") {
            let (authority, path) = hierarchical(rest);
            return UriComponents {
                authority: Some(authority),
                path,
                ..UriComponents::default()
            };
        }

        let (rest, fragment) = before_after(rest, '#');
        let (rest, query) = before_after(rest, '?');
        let (authority, path) = if let Some(host_path) = rest.strip_prefix("//") {
            let (authority, path) = hierarchical(host_path);
            let authority = authority
                .rsplit_once('@')
                .map_or(authority, |(_, host)| host);
            let host = if authority.starts_with('[') {
                authority
                    .find(']')
                    .map_or(authority, |end| &authority[..=end])
            } else {
                authority
                    .rsplit_once(':')
                    .map_or(authority, |(host, _)| host)
            };
            (Some(host), path)
        } else {
            (None, (!rest.is_empty()).then_some(rest))
        };
        UriComponents {
            authority,
            path,
            query,
            fragment,
        }
    }
}

#[derive(Default)]
struct UriComponents<'a> {
    authority: Option<&'a str>,
    path: Option<&'a str>,
    query: Option<&'a str>,
    fragment: Option<&'a str>,
}

fn before_after(text: &str, delimiter: char) -> (&str, Option<&str>) {
    text.split_once(delimiter)
        .map_or((text, None), |(head, tail)| (head, Some(tail)))
}

fn hierarchical(text: &str) -> (&str, Option<&str>) {
    text.find('/')
        .map_or((text, None), |index| (&text[..index], Some(&text[index..])))
}

wire_string!(Uri, as_str, validate);
