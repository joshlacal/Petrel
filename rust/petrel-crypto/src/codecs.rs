//! Hex, canonical unpadded Base64URL, and duplicate-free StrictJSON codecs.

use std::collections::HashSet;

use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use serde::de::DeserializeOwned;

use crate::error::PetrelCryptoError;

/// Lowercase hexadecimal encoder and case-insensitive hexadecimal decoder.
#[derive(Debug, Clone, Copy)]
pub struct Hex;

impl Hex {
    /// Encodes bytes as lowercase hexadecimal.
    pub fn encode(data: &[u8]) -> String {
        const LUT: &[u8; 16] = b"0123456789abcdef";
        let mut out = String::with_capacity(data.len() * 2);
        for &byte in data {
            out.push(char::from(LUT[(byte >> 4) as usize]));
            out.push(char::from(LUT[(byte & 0x0f) as usize]));
        }
        out
    }

    /// Decodes an even-length hexadecimal string into bytes, returning `None` on invalid input.
    pub fn decode(string: &str) -> Option<Vec<u8>> {
        let bytes = string.as_bytes();
        if !bytes.len().is_multiple_of(2) {
            return None;
        }
        let mut out = Vec::with_capacity(bytes.len() / 2);
        for i in (0..bytes.len()).step_by(2) {
            let high = nibble(bytes[i])?;
            let low = nibble(bytes[i + 1])?;
            out.push((high << 4) | low);
        }
        Some(out)
    }
}

const fn nibble(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}

/// Canonical unpadded Base64URL encoding and decoding used by JOSE and ATProto.
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct JWTBase64URL;

impl JWTBase64URL {
    /// Default decode limit matching Swift `JWTBase64URL.decode(_:maxBytes:)`.
    pub const DEFAULT_MAX_BYTES: usize = 16_384;

    /// Encodes bytes to canonical unpadded Base64URL text.
    pub fn encode(data: &[u8]) -> String {
        URL_SAFE_NO_PAD.encode(data)
    }

    /// Decodes strictly canonical unpadded Base64URL text up to `max_bytes`.
    pub fn decode(value: &str, max_bytes: usize) -> Result<Vec<u8>, PetrelCryptoError> {
        if value.is_empty()
            || !value
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
        {
            return Err(PetrelCryptoError::Malformed(
                "invalid base64url value".into(),
            ));
        }
        let max_encoded = (max_bytes / 3)
            .saturating_mul(4)
            .saturating_add(match max_bytes % 3 {
                0 => 0,
                1 => 2,
                _ => 3,
            });
        if value.len() > max_encoded {
            return Err(PetrelCryptoError::Malformed(
                "invalid base64url value".into(),
            ));
        }
        let decoded = URL_SAFE_NO_PAD
            .decode(value)
            .map_err(|_| PetrelCryptoError::Malformed("invalid base64url value".into()))?;
        if decoded.len() > max_bytes || Self::encode(&decoded) != value {
            return Err(PetrelCryptoError::Malformed(
                "invalid base64url value".into(),
            ));
        }
        Ok(decoded)
    }
}

/// Duplicate-member-free JSON validator shared by cryptographic verifiers.
///
/// Validates complete UTF-8 JSON before `serde_json` would otherwise accept
/// duplicate object keys with last-value-wins semantics.
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct StrictJSON;

impl StrictJSON {
    /// Maximum nesting depth permitted for JSON objects and arrays.
    pub const MAXIMUM_NESTING_DEPTH: usize = 64;

    /// Validates complete duplicate-free UTF-8 JSON.
    pub fn validate(data: &[u8]) -> Result<(), PetrelCryptoError> {
        let mut parser = Parser {
            bytes: data,
            top_level_integer_members: &[],
            index: 0,
        };
        parser.parse_document()
    }

    /// Validates complete duplicate-free UTF-8 JSON while additionally
    /// requiring the named members of the root object to use JSON integer tokens.
    pub fn validate_top_level_integer_members(
        members: &[&str],
        data: &[u8],
    ) -> Result<(), PetrelCryptoError> {
        let mut parser = Parser {
            bytes: data,
            top_level_integer_members: members,
            index: 0,
        };
        parser.parse_document()
    }

    /// Validates duplicate-free JSON and deserializes into `T`.
    pub fn decode<T: DeserializeOwned>(data: &[u8]) -> Result<T, PetrelCryptoError> {
        Self::validate(data)?;
        serde_json::from_slice(data)
            .map_err(|_| PetrelCryptoError::Malformed("invalid JSON".into()))
    }
}

struct Parser<'a> {
    bytes: &'a [u8],
    top_level_integer_members: &'a [&'a str],
    index: usize,
}

impl Parser<'_> {
    fn parse_document(&mut self) -> Result<(), PetrelCryptoError> {
        self.skip_whitespace();
        self.parse_value(true, false, 0)?;
        self.skip_whitespace();
        if self.index == self.bytes.len() {
            Ok(())
        } else {
            Err(PetrelCryptoError::Malformed("invalid JSON".into()))
        }
    }

    fn parse_value(
        &mut self,
        is_top_level: bool,
        requires_integer_token: bool,
        nesting_depth: usize,
    ) -> Result<(), PetrelCryptoError> {
        self.skip_whitespace();
        let byte = self
            .bytes
            .get(self.index)
            .copied()
            .ok_or_else(|| PetrelCryptoError::Malformed("invalid JSON".into()))?;
        if requires_integer_token && byte != b'-' && !byte.is_ascii_digit() {
            return Err(PetrelCryptoError::Malformed(
                "JSON member must be an integer".into(),
            ));
        }
        match byte {
            b'{' => {
                if requires_integer_token {
                    return Err(PetrelCryptoError::Malformed(
                        "JSON member must be an integer".into(),
                    ));
                }
                let nested_depth = Self::next_nesting_depth(nesting_depth)?;
                self.parse_object(is_top_level, nested_depth)?;
            }
            b'[' => {
                if requires_integer_token {
                    return Err(PetrelCryptoError::Malformed(
                        "JSON member must be an integer".into(),
                    ));
                }
                let nested_depth = Self::next_nesting_depth(nesting_depth)?;
                self.parse_array(nested_depth)?;
            }
            b'"' => {
                let _ = self.parse_string()?;
            }
            b't' => self.consume_literal(b"true")?,
            b'f' => self.consume_literal(b"false")?,
            b'n' => self.consume_literal(b"null")?,
            b'-' | b'0'..=b'9' => self.parse_number(requires_integer_token)?,
            _ => return Err(PetrelCryptoError::Malformed("invalid JSON".into())),
        }
        Ok(())
    }

    fn parse_object(
        &mut self,
        is_top_level: bool,
        nesting_depth: usize,
    ) -> Result<(), PetrelCryptoError> {
        self.consume(b'{')?;
        self.skip_whitespace();
        if self.consume_if(b'}') {
            return Ok(());
        }
        let mut keys = HashSet::new();
        loop {
            self.skip_whitespace();
            let key = self.parse_string()?;
            if !keys.insert(key.clone()) {
                return Err(PetrelCryptoError::Malformed("duplicate JSON member".into()));
            }
            self.skip_whitespace();
            self.consume(b':')?;
            let requires_int =
                is_top_level && self.top_level_integer_members.contains(&key.as_str());
            self.parse_value(false, requires_int, nesting_depth)?;
            self.skip_whitespace();
            if self.consume_if(b'}') {
                return Ok(());
            }
            self.consume(b',')?;
        }
    }

    fn parse_array(&mut self, nesting_depth: usize) -> Result<(), PetrelCryptoError> {
        self.consume(b'[')?;
        self.skip_whitespace();
        if self.consume_if(b']') {
            return Ok(());
        }
        loop {
            self.parse_value(false, false, nesting_depth)?;
            self.skip_whitespace();
            if self.consume_if(b']') {
                return Ok(());
            }
            self.consume(b',')?;
        }
    }

    fn next_nesting_depth(current_depth: usize) -> Result<usize, PetrelCryptoError> {
        if current_depth >= StrictJSON::MAXIMUM_NESTING_DEPTH {
            return Err(PetrelCryptoError::Malformed(
                "JSON exceeds maximum nesting depth".into(),
            ));
        }
        Ok(current_depth + 1)
    }

    fn parse_string(&mut self) -> Result<String, PetrelCryptoError> {
        self.consume(b'"')?;
        let mut result = String::new();
        let mut chunk_start = self.index;
        while let Some(&byte) = self.bytes.get(self.index) {
            if byte == b'"' {
                self.append_utf8_chunk(chunk_start, self.index, &mut result)?;
                self.index += 1;
                return Ok(result);
            }
            if byte == b'\\' {
                self.append_utf8_chunk(chunk_start, self.index, &mut result)?;
                self.index += 1;
                let escape =
                    self.bytes.get(self.index).copied().ok_or_else(|| {
                        PetrelCryptoError::Malformed("invalid JSON string".into())
                    })?;
                self.index += 1;
                match escape {
                    b'"' => result.push('"'),
                    b'\\' => result.push('\\'),
                    b'/' => result.push('/'),
                    b'b' => result.push('\u{0008}'),
                    b'f' => result.push('\u{000C}'),
                    b'n' => result.push('\n'),
                    b'r' => result.push('\r'),
                    b't' => result.push('\t'),
                    b'u' => self.append_unicode_escape(&mut result)?,
                    _ => return Err(PetrelCryptoError::Malformed("invalid JSON string".into())),
                }
                chunk_start = self.index;
            } else {
                if byte < 0x20 {
                    return Err(PetrelCryptoError::Malformed("invalid JSON string".into()));
                }
                self.index += 1;
            }
        }
        Err(PetrelCryptoError::Malformed("invalid JSON string".into()))
    }

    fn append_unicode_escape(&mut self, output: &mut String) -> Result<(), PetrelCryptoError> {
        let first = self.parse_hex16()?;
        if (0xD800..=0xDBFF).contains(&first) {
            if !self.consume_if(b'\\') || !self.consume_if(b'u') {
                return Err(PetrelCryptoError::Malformed(
                    "invalid JSON surrogate".into(),
                ));
            }
            let second = self.parse_hex16()?;
            if !(0xDC00..=0xDFFF).contains(&second) {
                return Err(PetrelCryptoError::Malformed(
                    "invalid JSON surrogate".into(),
                ));
            }
            let scalar =
                0x10000 + ((u32::from(first) - 0xD800) << 10) + (u32::from(second) - 0xDC00);
            let ch = char::from_u32(scalar)
                .ok_or_else(|| PetrelCryptoError::Malformed("invalid JSON scalar".into()))?;
            output.push(ch);
        } else {
            if (0xDC00..=0xDFFF).contains(&first) {
                return Err(PetrelCryptoError::Malformed(
                    "invalid JSON surrogate".into(),
                ));
            }
            let ch = char::from_u32(u32::from(first))
                .ok_or_else(|| PetrelCryptoError::Malformed("invalid JSON scalar".into()))?;
            output.push(ch);
        }
        Ok(())
    }

    fn parse_hex16(&mut self) -> Result<u16, PetrelCryptoError> {
        let slice = self
            .bytes
            .get(self.index..self.index + 4)
            .ok_or_else(|| PetrelCryptoError::Malformed("invalid JSON escape".into()))?;
        let mut result: u16 = 0;
        for &byte in slice {
            let n = nibble(byte)
                .ok_or_else(|| PetrelCryptoError::Malformed("invalid JSON escape".into()))?;
            result = (result << 4) | u16::from(n);
        }
        self.index += 4;
        Ok(result)
    }

    fn parse_number(&mut self, requires_integer_token: bool) -> Result<(), PetrelCryptoError> {
        let _ = self.consume_if(b'-');
        let first = self
            .bytes
            .get(self.index)
            .copied()
            .ok_or_else(|| PetrelCryptoError::Malformed("invalid JSON number".into()))?;
        if first == b'0' {
            self.index += 1;
        } else if (b'1'..=b'9').contains(&first) {
            self.index += 1;
            while self.bytes.get(self.index).is_some_and(u8::is_ascii_digit) {
                self.index += 1;
            }
        } else {
            return Err(PetrelCryptoError::Malformed("invalid JSON number".into()));
        }

        let has_fraction = self.consume_if(b'.');
        if has_fraction {
            if !self.bytes.get(self.index).is_some_and(u8::is_ascii_digit) {
                return Err(PetrelCryptoError::Malformed("invalid JSON number".into()));
            }
            while self.bytes.get(self.index).is_some_and(u8::is_ascii_digit) {
                self.index += 1;
            }
        }

        let mut has_exponent = false;
        if self
            .bytes
            .get(self.index)
            .is_some_and(|&b| b == b'E' || b == b'e')
        {
            has_exponent = true;
            self.index += 1;
            let _ = self.consume_if(b'+') || self.consume_if(b'-');
            if !self.bytes.get(self.index).is_some_and(u8::is_ascii_digit) {
                return Err(PetrelCryptoError::Malformed("invalid JSON number".into()));
            }
            while self.bytes.get(self.index).is_some_and(u8::is_ascii_digit) {
                self.index += 1;
            }
        }

        if requires_integer_token && (has_fraction || has_exponent) {
            return Err(PetrelCryptoError::Malformed(
                "JSON member must be an integer".into(),
            ));
        }
        Ok(())
    }

    fn consume_literal(&mut self, literal: &[u8]) -> Result<(), PetrelCryptoError> {
        for &byte in literal {
            self.consume(byte)?;
        }
        Ok(())
    }

    fn skip_whitespace(&mut self) {
        while self
            .bytes
            .get(self.index)
            .is_some_and(|&b| matches!(b, b' ' | b'\t' | b'\n' | b'\r'))
        {
            self.index += 1;
        }
    }

    fn consume(&mut self, expected: u8) -> Result<(), PetrelCryptoError> {
        if self.consume_if(expected) {
            Ok(())
        } else {
            Err(PetrelCryptoError::Malformed("invalid JSON".into()))
        }
    }

    fn consume_if(&mut self, expected: u8) -> bool {
        if self.bytes.get(self.index) == Some(&expected) {
            self.index += 1;
            true
        } else {
            false
        }
    }

    fn append_utf8_chunk(
        &self,
        start: usize,
        end: usize,
        output: &mut String,
    ) -> Result<(), PetrelCryptoError> {
        let slice = self
            .bytes
            .get(start..end)
            .ok_or_else(|| PetrelCryptoError::Malformed("invalid JSON UTF-8".into()))?;
        let chunk = std::str::from_utf8(slice)
            .map_err(|_| PetrelCryptoError::Malformed("invalid JSON UTF-8".into()))?;
        output.push_str(chunk);
        Ok(())
    }
}
