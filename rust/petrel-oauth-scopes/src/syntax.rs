use std::{collections::BTreeSet, fmt};

use crate::is_scope_token;

/// Why a scope or one of its parameters was rejected.
#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub enum ScopeParseError {
    NotAScopeToken,
    MalformedPercentEncoding,
    UnknownPrefix,
    PrefixMismatch { expected: &'static str },
    UnknownParameter { prefix: &'static str, key: String },
    RepeatedSingleValue { key: &'static str },
    PositionalConflict { key: &'static str },
    EmptyMultiValue { key: &'static str },
    InvalidParameter { key: &'static str },
    InvalidPositional { key: &'static str },
    MissingRequiredParameter { key: &'static str },
    ForbiddenCombination { prefix: &'static str },
}

impl fmt::Display for ScopeParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NotAScopeToken => f.write_str("not an RFC 6749 scope token"),
            Self::MalformedPercentEncoding => f.write_str("invalid positional percent encoding"),
            Self::UnknownPrefix => f.write_str("unknown scope prefix"),
            Self::PrefixMismatch { expected } => write!(f, "expected a {expected} scope"),
            Self::UnknownParameter { prefix, .. } => write!(f, "unknown {prefix} parameter"),
            Self::RepeatedSingleValue { key } => write!(f, "{key} is single-valued"),
            Self::PositionalConflict { key } => write!(f, "{key} is both positional and named"),
            Self::EmptyMultiValue { key } => write!(f, "{key} has no values"),
            Self::InvalidParameter { key } => write!(f, "invalid value for {key}"),
            Self::InvalidPositional { key } => write!(f, "invalid positional value for {key}"),
            Self::MissingRequiredParameter { key } => write!(f, "{key} is required"),
            Self::ForbiddenCombination { prefix } => write!(f, "forbidden {prefix} parameters"),
        }
    }
}

impl std::error::Error for ScopeParseError {}

/// The result of looking up a key that accepts a single value.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SingleLookup<'a> {
    Absent,
    Present(&'a str),
    Repeated(Vec<&'a str>),
}

/// The named parameters of a scope in the order they were written.
#[derive(Clone, Debug, Default, Eq, Hash, PartialEq)]
pub struct ScopeParameterBag(Vec<(String, String)>);

impl ScopeParameterBag {
    pub fn entries(&self) -> &[(String, String)] {
        &self.0
    }

    pub fn append(&mut self, key: String, value: String) {
        self.0.push((key, value));
    }

    pub fn set(&mut self, key: String, value: String) {
        self.0.retain(|(name, _)| *name != key);
        self.append(key, value);
    }

    pub fn ordered_keys(&self) -> Vec<&str> {
        let mut seen = BTreeSet::new();
        self.0
            .iter()
            .filter_map(|(key, _)| seen.insert(key).then_some(key.as_str()))
            .collect()
    }

    pub fn values(&self, key: &str) -> Vec<&str> {
        self.0
            .iter()
            .filter(|(name, _)| name == key)
            .map(|(_, value)| value.as_str())
            .collect()
    }

    pub fn single(&self, key: &str) -> SingleLookup<'_> {
        let values = self.values(key);
        match values.as_slice() {
            [] => SingleLookup::Absent,
            [value] => SingleLookup::Present(value),
            _ => SingleLookup::Repeated(values),
        }
    }
}

/// The lexical decomposition of `prefix:positional?key=value`.
#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub struct ScopeStringSyntax {
    pub prefix: String,
    pub positional: Option<String>,
    pub parameters: ScopeParameterBag,
}

impl ScopeStringSyntax {
    pub fn parse(value: &str) -> Result<Self, ScopeParseError> {
        if !is_scope_token(value) {
            return Err(ScopeParseError::NotAScopeToken);
        }

        let (head, query) = value.split_once('?').unwrap_or((value, ""));
        let (prefix, positional) = match head.split_once(':') {
            Some((prefix, raw)) => {
                let decoded = percent_decode(raw, false, true)
                    .ok_or(ScopeParseError::MalformedPercentEncoding)?;
                let positional = String::from_utf8(decoded)
                    .map_err(|_| ScopeParseError::MalformedPercentEncoding)?;
                (prefix, Some(positional))
            }
            None => (head, None),
        };

        let mut parameters = ScopeParameterBag::default();
        for raw in query.split('&').filter(|pair| !pair.is_empty()) {
            let (key, value) = raw.split_once('=').unwrap_or((raw, ""));
            parameters.append(decode_form_component(key), decode_form_component(value));
        }

        Ok(Self {
            prefix: prefix.to_owned(),
            positional,
            parameters,
        })
    }

    pub fn is_scope_string(value: &str, prefix: &str) -> bool {
        value == prefix
            || value
                .strip_prefix(prefix)
                .is_some_and(|suffix| suffix.starts_with([':', '?']))
    }

    /// Reproduce the upstream canonical form. Certain literal percent and plus
    /// characters can change meaning if this form is parsed again.
    pub fn canonical_string(&self) -> Result<String, ScopeParseError> {
        self.format(true)
    }

    /// Use the interoperable scope spelling that preserves the parsed values.
    pub fn wire_string(&self) -> Result<String, ScopeParseError> {
        self.format(false)
    }

    fn format(&self, canonical: bool) -> Result<String, ScopeParseError> {
        let mut result = self.prefix.clone();
        if let Some(positional) = &self.positional {
            result.push(':');
            result.push_str(&unescape(encode_uri_component(positional), true, canonical));
        }
        for (index, (key, value)) in self.parameters.0.iter().enumerate() {
            result.push(if index == 0 { '?' } else { '&' });
            result.push_str(&unescape(encode_form_component(key), canonical, canonical));
            result.push('=');
            result.push_str(&unescape(
                encode_form_component(value),
                canonical,
                canonical,
            ));
        }
        is_scope_token(&result)
            .then_some(result)
            .ok_or(ScopeParseError::NotAScopeToken)
    }
}

fn unescape(mut encoded: String, plus: bool, percent: bool) -> String {
    for (escaped, raw) in [("%3A", ":"), ("%2F", "/"), ("%2C", ","), ("%40", "@")] {
        encoded = encoded.replace(escaped, raw);
    }
    if plus {
        encoded = encoded.replace("%2B", "+");
    }
    if percent {
        encoded = encoded.replace("%25", "%");
    }
    encoded
}

/// Encode a positional scope component as JavaScript's `encodeURIComponent`.
pub fn encode_uri_component(value: &str) -> String {
    percent_encode(value, b"-_.!~*'()", false)
}

/// Encode a query component as JavaScript's `URLSearchParams`.
pub fn encode_form_component(value: &str) -> String {
    percent_encode(value, b"*-._", true)
}

fn percent_encode(value: &str, unreserved: &[u8], form: bool) -> String {
    const HEX: &[u8; 16] = b"0123456789ABCDEF";
    let mut encoded = String::with_capacity(value.len());
    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || unreserved.contains(&byte) {
            encoded.push(char::from(byte));
        } else if form && byte == b' ' {
            encoded.push('+');
        } else {
            encoded.push('%');
            encoded.push(char::from(HEX[usize::from(byte >> 4)]));
            encoded.push(char::from(HEX[usize::from(byte & 15)]));
        }
    }
    encoded
}

fn decode_form_component(input: &str) -> String {
    // Form decoding is lossy. Invalid percent sequences are copied verbatim.
    String::from_utf8_lossy(&percent_decode(input, true, false).unwrap_or_default()).into_owned()
}

pub(crate) fn percent_decode(input: &str, form: bool, strict: bool) -> Option<Vec<u8>> {
    let mut bytes = input.bytes().peekable();
    let mut result = Vec::with_capacity(input.len());
    while let Some(byte) = bytes.next() {
        if byte == b'%' {
            let mut lookahead = bytes.clone();
            let decoded = lookahead
                .next()
                .and_then(hex)
                .zip(lookahead.next().and_then(hex));
            if let Some((high, low)) = decoded {
                result.push(high << 4 | low);
                bytes = lookahead;
                continue;
            }
            if strict {
                return None;
            }
        }
        result.push(if form && byte == b'+' { b' ' } else { byte });
    }
    Some(result)
}

pub(crate) fn hex(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}
