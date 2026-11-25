//! Shared RFC 8941 Structured Field parser and serializer.

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;

use crate::error::{Result, SpaceError};

/// Maximum accepted header size in bytes (matching Swift and atproto-spaces limits).
pub const MAX_SF_HEADER_BYTES: usize = 8192;

/// Controls how duplicate dictionary or parameter keys are handled.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DuplicatePolicy {
    /// Reject duplicate keys in dictionaries or parameters (used by `SpaceMACHeader`).
    Reject,
    /// Later values overwrite earlier entries in-place (RFC 8941 §4.2.2/§4.2.3.2, used by `SpaceHTTPSignature`).
    OverwriteLast,
}

/// An RFC 8941 bare item.
#[derive(Debug, Clone, PartialEq)]
pub enum SfBareItem {
    Integer(i64),
    Decimal(f64),
    String(String),
    Token(String),
    ByteSeq(Vec<u8>),
    Boolean(bool),
}

impl SfBareItem {
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Self::String(s) | Self::Token(s) => Some(s.as_str()),
            _ => None,
        }
    }

    pub fn as_string_strict(&self) -> Option<&str> {
        match self {
            Self::String(s) => Some(s.as_str()),
            _ => None,
        }
    }

    pub fn as_token(&self) -> Option<&str> {
        match self {
            Self::Token(s) => Some(s.as_str()),
            _ => None,
        }
    }

    pub fn as_int(&self) -> Option<i64> {
        match self {
            Self::Integer(v) => Some(*v),
            _ => None,
        }
    }

    pub fn as_bytes(&self) -> Option<&[u8]> {
        match self {
            Self::ByteSeq(b) => Some(b.as_slice()),
            _ => None,
        }
    }

    /// Serialize this bare item to canonical RFC 8941 text.
    pub fn format(&self) -> String {
        match self {
            Self::Integer(v) => v.to_string(),
            Self::Decimal(v) => format!("{v}"),
            Self::String(s) => format!("\"{}\"", escape_sf_string(s)),
            Self::Token(t) => t.clone(),
            Self::ByteSeq(b) => format!(":{}:", BASE64_STANDARD.encode(b)),
            Self::Boolean(b) => if *b { "?1" } else { "?0" }.to_owned(),
        }
    }
}

/// Parameter list attached to an item or inner list.
pub type SfParams = Vec<(String, SfBareItem)>;

/// An RFC 8941 item (bare item + parameters).
#[derive(Debug, Clone, PartialEq)]
pub struct SfItem {
    pub bare: SfBareItem,
    pub params: SfParams,
}

impl SfItem {
    pub fn param(&self, key: &str) -> Option<&SfBareItem> {
        self.params
            .iter()
            .rev()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v)
    }

    pub fn format(&self) -> String {
        let mut out = self.bare.format();
        format_params_into(&self.params, &mut out);
        out
    }
}

/// An RFC 8941 dictionary member: either an item or an inner list.
#[derive(Debug, Clone, PartialEq)]
pub enum SfMember {
    Item(SfItem),
    InnerList(Vec<SfItem>, SfParams),
}

impl SfMember {
    pub fn as_item(&self) -> Option<&SfItem> {
        match self {
            Self::Item(item) => Some(item),
            Self::InnerList(_, _) => None,
        }
    }

    pub fn param(&self, key: &str) -> Option<&SfBareItem> {
        let params = match self {
            Self::Item(item) => &item.params,
            Self::InnerList(_, params) => params,
        };
        params.iter().rev().find(|(k, _)| k == key).map(|(_, v)| v)
    }

    pub fn format(&self) -> String {
        match self {
            Self::Item(item) => item.format(),
            Self::InnerList(items, params) => {
                let mut out = String::from("(");
                for (idx, item) in items.iter().enumerate() {
                    if idx > 0 {
                        out.push(' ');
                    }
                    out.push_str(&item.format());
                }
                out.push(')');
                format_params_into(params, &mut out);
                out
            }
        }
    }
}

/// An ordered RFC 8941 dictionary.
#[derive(Debug, Clone, PartialEq)]
pub struct SfDictionary {
    pub entries: Vec<(String, SfMember)>,
}

impl SfDictionary {
    pub fn get(&self, key: &str) -> Option<&SfMember> {
        self.entries
            .iter()
            .rev()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v)
    }

    pub fn format(&self) -> String {
        self.entries
            .iter()
            .map(|(key, member)| match member {
                SfMember::Item(SfItem {
                    bare: SfBareItem::Boolean(true),
                    params,
                }) => {
                    let mut out = key.clone();
                    format_params_into(params, &mut out);
                    out
                }
                other => format!("{key}={}", other.format()),
            })
            .collect::<Vec<_>>()
            .join(", ")
    }
}

/// Parse an RFC 8941 dictionary with the requested duplicate-key policy.
pub fn parse_dictionary(input: &str, policy: DuplicatePolicy) -> Result<SfDictionary> {
    if input.len() > MAX_SF_HEADER_BYTES {
        return Err(SpaceError::MalformedHeader(format!(
            "structured field exceeds {MAX_SF_HEADER_BYTES} bytes"
        )));
    }
    let mut parser = Parser::new(input.as_bytes(), policy);
    parser.skip_ows();
    let mut entries: Vec<(String, SfMember)> = Vec::new();
    if parser.is_eof() {
        return Ok(SfDictionary { entries });
    }
    loop {
        let key = parser.parse_key()?;
        let member = if parser.peek() == Some(b'=') {
            parser.advance();
            parser.parse_item_or_inner_list()?
        } else {
            let params = parser.parse_params()?;
            SfMember::Item(SfItem {
                bare: SfBareItem::Boolean(true),
                params,
            })
        };
        insert_kv(&mut entries, key, member, policy, "dictionary key")?;
        parser.skip_ows();
        if parser.is_eof() {
            break;
        }
        if parser.peek() != Some(b',') {
            return Err(SpaceError::MalformedHeader(format!(
                "expected ',' at byte {}",
                parser.pos
            )));
        }
        parser.advance();
        parser.skip_ows();
        if parser.is_eof() {
            return Err(SpaceError::MalformedHeader(
                "trailing comma in structured field dictionary".to_owned(),
            ));
        }
    }
    Ok(SfDictionary { entries })
}

/// Parse a standalone RFC 8941 item.
pub fn parse_item(input: &str, policy: DuplicatePolicy) -> Result<SfItem> {
    if input.len() > MAX_SF_HEADER_BYTES {
        return Err(SpaceError::MalformedHeader(format!(
            "structured field exceeds {MAX_SF_HEADER_BYTES} bytes"
        )));
    }
    let mut parser = Parser::new(input.as_bytes(), policy);
    parser.skip_sp();
    let item = parser.parse_item()?;
    parser.skip_sp();
    if !parser.is_eof() {
        return Err(SpaceError::MalformedHeader(format!(
            "trailing bytes at position {}",
            parser.pos
        )));
    }
    Ok(item)
}

/// Escape `\` and `"` inside an RFC 8941 quoted string.
pub fn escape_sf_string(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for ch in value.chars() {
        if ch == '\\' || ch == '"' {
            out.push('\\');
        }
        out.push(ch);
    }
    out
}

/// Format an RFC 8941 parameter list (`;k=v;flag`) into `out`.
pub fn format_params_into(params: &[(String, SfBareItem)], out: &mut String) {
    for (k, v) in params {
        out.push(';');
        out.push_str(k);
        if !matches!(v, SfBareItem::Boolean(true)) {
            out.push('=');
            out.push_str(&v.format());
        }
    }
}

fn insert_kv<V>(
    list: &mut Vec<(String, V)>,
    key: String,
    value: V,
    policy: DuplicatePolicy,
    label: &str,
) -> Result<()> {
    if let Some(idx) = list.iter().position(|(k, _)| k == &key) {
        match policy {
            DuplicatePolicy::Reject => {
                return Err(SpaceError::MalformedHeader(format!(
                    "duplicate {label}: {key}"
                )));
            }
            DuplicatePolicy::OverwriteLast => {
                list[idx].1 = value;
                return Ok(());
            }
        }
    }
    list.push((key, value));
    Ok(())
}

struct Parser<'a> {
    src: &'a [u8],
    pos: usize,
    policy: DuplicatePolicy,
}

impl<'a> Parser<'a> {
    fn new(src: &'a [u8], policy: DuplicatePolicy) -> Self {
        Self {
            src,
            pos: 0,
            policy,
        }
    }

    fn is_eof(&self) -> bool {
        self.pos >= self.src.len()
    }

    fn peek(&self) -> Option<u8> {
        self.src.get(self.pos).copied()
    }

    fn advance(&mut self) -> Option<u8> {
        let b = self.peek()?;
        self.pos += 1;
        Some(b)
    }

    fn skip_sp(&mut self) {
        while self.peek() == Some(b' ') {
            self.pos += 1;
        }
    }

    fn skip_ows(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\t')) {
            self.pos += 1;
        }
    }

    fn parse_key(&mut self) -> Result<String> {
        let start = self.pos;
        match self.peek() {
            Some(b) if b.is_ascii_lowercase() || b == b'*' => {
                self.pos += 1;
            }
            _ => {
                return Err(SpaceError::MalformedHeader(format!(
                    "invalid structured field key at byte {}",
                    self.pos
                )));
            }
        }
        while let Some(b) = self.peek() {
            if b.is_ascii_lowercase()
                || b.is_ascii_digit()
                || matches!(b, b'_' | b'-' | b'.' | b'*')
            {
                self.pos += 1;
            } else {
                break;
            }
        }
        std::str::from_utf8(&self.src[start..self.pos])
            .map(str::to_owned)
            .map_err(|_| SpaceError::MalformedHeader("non-utf8 key".to_owned()))
    }

    fn parse_item_or_inner_list(&mut self) -> Result<SfMember> {
        if self.peek() == Some(b'(') {
            self.parse_inner_list()
        } else {
            Ok(SfMember::Item(self.parse_item()?))
        }
    }

    fn parse_inner_list(&mut self) -> Result<SfMember> {
        if self.advance() != Some(b'(') {
            return Err(SpaceError::MalformedHeader("expected '('".to_owned()));
        }
        let mut items = Vec::new();
        loop {
            self.skip_sp();
            if self.peek() == Some(b')') {
                self.advance();
                break;
            }
            if self.is_eof() {
                return Err(SpaceError::MalformedHeader(
                    "unterminated inner list".to_owned(),
                ));
            }
            items.push(self.parse_item()?);
            if matches!(self.peek(), Some(b' ' | b')')) {
                continue;
            }
            return Err(SpaceError::MalformedHeader(format!(
                "expected SP or ')' in inner list at byte {}",
                self.pos
            )));
        }
        let params = self.parse_params()?;
        Ok(SfMember::InnerList(items, params))
    }

    fn parse_item(&mut self) -> Result<SfItem> {
        let bare = self.parse_bare_item()?;
        let params = self.parse_params()?;
        Ok(SfItem { bare, params })
    }

    fn parse_params(&mut self) -> Result<SfParams> {
        let mut params = Vec::new();
        while self.peek() == Some(b';') {
            self.advance();
            self.skip_sp();
            let key = self.parse_key()?;
            let value = if self.peek() == Some(b'=') {
                self.advance();
                self.parse_bare_item()?
            } else {
                SfBareItem::Boolean(true)
            };
            insert_kv(&mut params, key, value, self.policy, "parameter key")?;
        }
        Ok(params)
    }

    fn parse_bare_item(&mut self) -> Result<SfBareItem> {
        match self.peek() {
            Some(b'"') => self.parse_string(),
            Some(b':') => self.parse_byte_seq(),
            Some(b'?') => self.parse_boolean(),
            Some(b'-') => self.parse_number(),
            Some(b) if b.is_ascii_digit() => self.parse_number(),
            Some(b) if b.is_ascii_alphabetic() || b == b'*' => self.parse_token(),
            _ => Err(SpaceError::MalformedHeader(format!(
                "unexpected structured field item at byte {}",
                self.pos
            ))),
        }
    }

    fn parse_string(&mut self) -> Result<SfBareItem> {
        if self.advance() != Some(b'"') {
            return Err(SpaceError::MalformedHeader("expected '\"'".to_owned()));
        }
        let mut out = String::new();
        loop {
            let b = self.advance().ok_or_else(|| {
                SpaceError::MalformedHeader("unterminated structured field string".to_owned())
            })?;
            if b == b'"' {
                return Ok(SfBareItem::String(out));
            }
            if b == b'\\' {
                let esc = self.advance().ok_or_else(|| {
                    SpaceError::MalformedHeader("trailing backslash in string".to_owned())
                })?;
                if esc != b'\\' && esc != b'"' {
                    return Err(SpaceError::MalformedHeader(
                        "invalid escape sequence in structured field string".to_owned(),
                    ));
                }
                out.push(esc as char);
            } else if !(0x20..=0x7e).contains(&b) {
                return Err(SpaceError::MalformedHeader(
                    "invalid control/non-ASCII byte in structured field string".to_owned(),
                ));
            } else {
                out.push(b as char);
            }
        }
    }

    fn parse_byte_seq(&mut self) -> Result<SfBareItem> {
        if self.advance() != Some(b':') {
            return Err(SpaceError::MalformedHeader("expected ':'".to_owned()));
        }
        let start = self.pos;
        while let Some(b) = self.peek() {
            if b == b':' {
                let encoded = std::str::from_utf8(&self.src[start..self.pos]).map_err(|_| {
                    SpaceError::MalformedHeader("non-utf8 byte sequence".to_owned())
                })?;
                self.advance();
                let decoded = BASE64_STANDARD.decode(encoded).map_err(|e| {
                    SpaceError::MalformedHeader(format!("invalid base64 byte sequence: {e}"))
                })?;
                return Ok(SfBareItem::ByteSeq(decoded));
            }
            if !(b.is_ascii_alphanumeric() || matches!(b, b'+' | b'/' | b'=')) {
                return Err(SpaceError::MalformedHeader(
                    "invalid character in structured field byte sequence".to_owned(),
                ));
            }
            self.pos += 1;
        }
        Err(SpaceError::MalformedHeader(
            "unterminated byte sequence".to_owned(),
        ))
    }

    fn parse_boolean(&mut self) -> Result<SfBareItem> {
        self.advance(); // '?'
        match self.advance() {
            Some(b'1') => Ok(SfBareItem::Boolean(true)),
            Some(b'0') => Ok(SfBareItem::Boolean(false)),
            _ => Err(SpaceError::MalformedHeader(
                "invalid boolean in structured field".to_owned(),
            )),
        }
    }

    fn parse_number(&mut self) -> Result<SfBareItem> {
        let start = self.pos;
        let mut is_negative = false;
        if self.peek() == Some(b'-') {
            is_negative = true;
            self.advance();
        }
        let digit_start = self.pos;
        while matches!(self.peek(), Some(b) if b.is_ascii_digit()) {
            self.pos += 1;
        }
        let int_digits = self.pos - digit_start;
        if int_digits == 0 {
            return Err(SpaceError::MalformedHeader(
                "missing digits in structured field number".to_owned(),
            ));
        }
        if self.peek() == Some(b'.') {
            if int_digits > 12 {
                return Err(SpaceError::MalformedHeader(
                    "decimal integer part exceeds 12 digits".to_owned(),
                ));
            }
            self.advance();
            let frac_start = self.pos;
            while matches!(self.peek(), Some(b) if b.is_ascii_digit()) {
                self.pos += 1;
            }
            let frac_digits = self.pos - frac_start;
            if frac_digits == 0 || frac_digits > 3 {
                return Err(SpaceError::MalformedHeader(
                    "decimal fractional part must have 1-3 digits".to_owned(),
                ));
            }
            let raw = std::str::from_utf8(&self.src[start..self.pos])
                .map_err(|_| SpaceError::MalformedHeader("non-utf8 decimal".to_owned()))?;
            let val: f64 = raw
                .parse()
                .map_err(|_| SpaceError::MalformedHeader("invalid decimal".to_owned()))?;
            let _ = is_negative;
            Ok(SfBareItem::Decimal(val))
        } else {
            if int_digits > 15 {
                return Err(SpaceError::MalformedHeader(
                    "integer exceeds 15 digits".to_owned(),
                ));
            }
            let raw = std::str::from_utf8(&self.src[start..self.pos])
                .map_err(|_| SpaceError::MalformedHeader("non-utf8 integer".to_owned()))?;
            let val: i64 = raw
                .parse()
                .map_err(|_| SpaceError::MalformedHeader("invalid integer".to_owned()))?;
            Ok(SfBareItem::Integer(val))
        }
    }

    fn parse_token(&mut self) -> Result<SfBareItem> {
        let start = self.pos;
        self.advance(); // already validated alphabetic or '*'
        while let Some(b) = self.peek() {
            if is_token_char(b) {
                self.pos += 1;
            } else {
                break;
            }
        }
        let tok = std::str::from_utf8(&self.src[start..self.pos])
            .map_err(|_| SpaceError::MalformedHeader("non-utf8 token".to_owned()))?;
        Ok(SfBareItem::Token(tok.to_owned()))
    }
}

fn is_token_char(b: u8) -> bool {
    b.is_ascii_alphanumeric()
        || matches!(
            b,
            b'!' | b'#'
                | b'$'
                | b'%'
                | b'&'
                | b'\''
                | b'*'
                | b'+'
                | b'-'
                | b'.'
                | b'^'
                | b'_'
                | b'`'
                | b'|'
                | b'~'
                | b':'
                | b'/'
        )
}
