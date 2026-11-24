//! Lexicon string formats: identifier newtypes.
//!
//! Every type here is owned, validates when parsed and when deserialized, and
//! serializes the exact string it was given (never a normalized form).
//!
//! **Lane 0 froze the names and the shape of the API; the validators are
//! placeholders.** Each `validate_*` function below checks only the obvious
//! outline of its grammar. Lane A (work package C1) replaces them with a 1:1
//! port of `Sources/Petrel/Core/Utils/ATProtoSyntax.swift`, proves them
//! against the 536 syntax vectors, and adds the accessors and the Swift
//! equality rules (for example a handle compares case-insensitively while
//! still serializing verbatim). Fields are private so that work changes no
//! signature.

use crate::error::{DecodeError, EncodeError, SyntaxError, SyntaxKind};
use crate::serde_bridge::{FromValue, ToValue};
use crate::value::{Value, serde_via_value};
use crate::xrpc::QueryValue;

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

        $crate::value::serde_via_value!($name);
    };
}
pub(crate) use string_newtype;

type Check = Result<(), &'static str>;

fn non_empty(value: &str) -> Check {
    if value.is_empty() {
        Err("empty string")
    } else if value.chars().any(|c| c.is_whitespace() || c.is_control()) {
        Err("contains whitespace or a control character")
    } else {
        Ok(())
    }
}

fn validate_did(value: &str) -> Check {
    non_empty(value)?;
    match value
        .strip_prefix("did:")
        .and_then(|rest| rest.split_once(':'))
    {
        Some((method, id)) if !method.is_empty() && !id.is_empty() => Ok(()),
        _ => Err("expected did:<method>:<identifier>"),
    }
}

fn validate_handle(value: &str) -> Check {
    non_empty(value)?;
    if value.contains('.') && !value.starts_with('.') && !value.ends_with('.') {
        Ok(())
    } else {
        Err("expected at least two dot-separated labels")
    }
}

fn validate_nsid(value: &str) -> Check {
    non_empty(value)?;
    if value.split('.').count() >= 3 && value.split('.').all(|segment| !segment.is_empty()) {
        Ok(())
    } else {
        Err("expected at least three dot-separated segments")
    }
}

fn validate_at_uri(value: &str) -> Check {
    non_empty(value)?;
    match value.strip_prefix("at://") {
        Some(rest) if !rest.is_empty() => Ok(()),
        _ => Err("expected at://<authority>[/<collection>[/<rkey>]]"),
    }
}

fn validate_uri(value: &str) -> Check {
    non_empty(value)?;
    match value.split_once(':') {
        Some((scheme, rest)) if !scheme.is_empty() && !rest.is_empty() => Ok(()),
        _ => Err("expected <scheme>:<rest>"),
    }
}

fn validate_tid(value: &str) -> Check {
    if value.len() == 13
        && value
            .bytes()
            .all(|b| matches!(b, b'2'..=b'7' | b'a'..=b'z'))
    {
        Ok(())
    } else {
        Err("expected 13 base32-sortable characters")
    }
}

fn validate_record_key(value: &str) -> Check {
    non_empty(value)?;
    if value == "." || value == ".." || value.len() > 512 {
        Err("reserved or too long")
    } else {
        Ok(())
    }
}

fn validate_cid_string(value: &str) -> Check {
    if value.len() >= 8
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'+' || b == b'=')
    {
        Ok(())
    } else {
        Err("expected 8 or more characters of [A-Za-z0-9+=]")
    }
}

string_newtype!(
    /// Lexicon `did`: a decentralized identifier such as `did:plc:…`.
    Did,
    SyntaxKind::Did,
    validate_did
);
string_newtype!(
    /// Lexicon `handle`: a DNS name such as `alice.example.com`.
    Handle,
    SyntaxKind::Handle,
    validate_handle
);
string_newtype!(
    /// Lexicon `nsid`: a namespaced identifier such as `app.bsky.feed.post`.
    Nsid,
    SyntaxKind::Nsid,
    validate_nsid
);
string_newtype!(
    /// Lexicon `at-uri`: `at://<authority>/<collection>/<rkey>`, including
    /// the space forms.
    AtUri,
    SyntaxKind::AtUri,
    validate_at_uri
);
string_newtype!(
    /// Lexicon `space-ref`: the three-segment space AT-URI,
    /// `at://<did>/space/<nsid>/<skey>`. Not interchangeable with [`AtUri`].
    SpaceRef,
    SyntaxKind::SpaceRef,
    validate_at_uri
);
string_newtype!(
    /// Lexicon `uri`: any RFC 3986 URI.
    Uri,
    SyntaxKind::Uri,
    validate_uri
);
string_newtype!(
    /// Lexicon `tid`: a 13-character timestamp identifier. See
    /// [`crate::tid`] for the generator.
    Tid,
    SyntaxKind::Tid,
    validate_tid
);
string_newtype!(
    /// Lexicon `record-key`.
    RecordKey,
    SyntaxKind::RecordKey,
    validate_record_key
);
string_newtype!(
    /// Lexicon `cid` *string format*: checked for syntax only and kept
    /// verbatim. It is a plain string in JSON and in CBOR, never a link; the
    /// link type is [`CidLink`](crate::CidLink).
    CidString,
    SyntaxKind::Cid,
    validate_cid_string
);

/// Lexicon `at-identifier`: a DID or a handle.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum AtIdentifier {
    /// A DID.
    Did(Did),
    /// A handle.
    Handle(Handle),
}

impl AtIdentifier {
    /// Parses a DID if the string starts with `did:`, otherwise a handle.
    pub fn parse(value: impl Into<String>) -> Result<Self, SyntaxError> {
        let value = value.into();
        let parsed = if value.starts_with("did:") {
            Did::parse(value).map(Self::Did)
        } else {
            Handle::parse(value).map(Self::Handle)
        };
        parsed.map_err(|error| SyntaxError::new(SyntaxKind::AtIdentifier, error.reason))
    }

    /// The string exactly as it was given.
    pub fn as_str(&self) -> &str {
        match self {
            Self::Did(did) => did.as_str(),
            Self::Handle(handle) => handle.as_str(),
        }
    }
}

impl std::fmt::Display for AtIdentifier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl std::str::FromStr for AtIdentifier {
    type Err = SyntaxError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::parse(s)
    }
}

impl ToValue for AtIdentifier {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::String(self.as_str().to_owned()))
    }
}

impl FromValue for AtIdentifier {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        Ok(Self::parse(String::from_value(value)?)?)
    }
}

impl QueryValue for AtIdentifier {
    fn to_query_value(&self) -> String {
        self.as_str().to_owned()
    }
}

serde_via_value!(AtIdentifier);
