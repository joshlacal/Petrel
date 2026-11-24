//! Strict DAG-CBOR over [`Value`].
//!
//! Hand-written rather than `serde_ipld_dagcbor` (plan decision 3). The
//! encoder always produces the canonical form; the decoder accepts only the
//! canonical form:
//!
//! - map keys are text, sorted by length and then bytewise, with no repeats;
//! - every integer and length uses its shortest head;
//! - no indefinite lengths, no floats, no `undefined`;
//! - the only tag is 42, wrapping a byte string `0x00 ‖ binary CID`;
//! - exactly one top-level item, no trailing bytes.
//!
//! Lane 0 implemented the codec the serialization spike needs. Lane A (work
//! package C6) adds the node and container count limits from
//! `Sources/PetrelCore/CID.swift:760` ([`Limits`] carries only the depth
//! limit today) and the malformed-input goldens.

use std::collections::BTreeMap;

use crate::cid::Cid;
use crate::error::DagCborError;
use crate::value::Value;

/// Decode limits. Lane A adds node and container caps.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub struct Limits {
    /// Maximum nesting depth of arrays and maps.
    pub max_depth: usize,
}

impl Limits {
    /// Limits for records and XRPC bodies.
    pub const STANDARD: Self = Self { max_depth: 64 };
}

impl Default for Limits {
    fn default() -> Self {
        Self::STANDARD
    }
}

/// Encodes a value as canonical DAG-CBOR.
pub fn encode(value: &Value) -> Vec<u8> {
    let mut out = Vec::new();
    encode_into(value, &mut out);
    out
}

fn write_head(major: u8, arg: u64, out: &mut Vec<u8>) {
    let major = major << 5;
    let bytes = arg.to_be_bytes();
    if arg < 24 {
        out.push(major | bytes[7]);
    } else if arg <= 0xff {
        out.extend_from_slice(&[major | 0x18, bytes[7]]);
    } else if arg <= 0xffff {
        out.push(major | 0x19);
        out.extend_from_slice(&bytes[6..]);
    } else if arg <= 0xffff_ffff {
        out.push(major | 0x1a);
        out.extend_from_slice(&bytes[4..]);
    } else {
        out.push(major | 0x1b);
        out.extend_from_slice(&bytes);
    }
}

fn encode_into(value: &Value, out: &mut Vec<u8>) {
    match value {
        Value::Null => out.push(0xf6),
        Value::Bool(false) => out.push(0xf4),
        Value::Bool(true) => out.push(0xf5),
        Value::Integer(n) => {
            if *n >= 0 {
                write_head(0, n.unsigned_abs(), out);
            } else {
                // -1 - n, computed without overflow at i64::MIN.
                write_head(1, n.unsigned_abs() - 1, out);
            }
        }
        Value::String(text) => {
            write_head(3, text.len() as u64, out);
            out.extend_from_slice(text.as_bytes());
        }
        Value::Bytes(bytes) => {
            write_head(2, bytes.len() as u64, out);
            out.extend_from_slice(bytes);
        }
        Value::Link(cid) => {
            write_head(6, 42, out);
            write_head(2, cid.as_bytes().len() as u64 + 1, out);
            out.push(0);
            out.extend_from_slice(cid.as_bytes());
        }
        Value::Array(items) => {
            write_head(4, items.len() as u64, out);
            for item in items {
                encode_into(item, out);
            }
        }
        Value::Object(map) => {
            write_head(5, map.len() as u64, out);
            let mut entries: Vec<(&String, &Value)> = map.iter().collect();
            entries.sort_by(|(a, _), (b, _)| canonical_order(a.as_bytes(), b.as_bytes()));
            for (key, item) in entries {
                write_head(3, key.len() as u64, out);
                out.extend_from_slice(key.as_bytes());
                encode_into(item, out);
            }
        }
    }
}

fn canonical_order(a: &[u8], b: &[u8]) -> std::cmp::Ordering {
    a.len().cmp(&b.len()).then_with(|| a.cmp(b))
}

/// Decodes one canonical DAG-CBOR item with [`Limits::STANDARD`].
pub fn decode(bytes: &[u8]) -> Result<Value, DagCborError> {
    decode_with(bytes, Limits::STANDARD)
}

/// Decodes one canonical DAG-CBOR item.
pub fn decode_with(bytes: &[u8], limits: Limits) -> Result<Value, DagCborError> {
    let mut reader = Reader {
        bytes,
        pos: 0,
        limits,
    };
    let value = reader.item(0)?;
    if reader.pos != bytes.len() {
        return Err(DagCborError::TrailingBytes);
    }
    Ok(value)
}

struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
    limits: Limits,
}

impl<'a> Reader<'a> {
    fn take(&mut self, len: usize) -> Result<&'a [u8], DagCborError> {
        let end = self
            .pos
            .checked_add(len)
            .filter(|end| *end <= self.bytes.len())
            .ok_or(DagCborError::UnexpectedEof)?;
        let slice = &self.bytes[self.pos..end];
        self.pos = end;
        Ok(slice)
    }

    /// Reads a head and returns `(major, argument)`, enforcing minimal form.
    /// Major type 7 is handled by the caller because its low bits are not a
    /// length.
    fn head(&mut self) -> Result<(u8, u64), DagCborError> {
        let first = self.take(1)?[0];
        let (major, info) = (first >> 5, first & 0x1f);
        if major == 7 {
            return Ok((major, u64::from(info)));
        }
        let arg = match info {
            0..=23 => u64::from(info),
            24..=27 => {
                let width = 1usize << (info - 24);
                let mut buf = [0u8; 8];
                buf[8 - width..].copy_from_slice(self.take(width)?);
                let arg = u64::from_be_bytes(buf);
                let minimum = match info {
                    24 => 24,
                    25 => 0x100,
                    26 => 0x1_0000,
                    _ => 0x1_0000_0000,
                };
                if arg < minimum {
                    return Err(DagCborError::NonMinimalEncoding);
                }
                arg
            }
            31 => return Err(DagCborError::IndefiniteLength),
            _ => return Err(DagCborError::Unsupported(first)),
        };
        Ok((major, arg))
    }

    /// A length that must fit in the remaining input (each element of an
    /// array or map takes at least one byte), so a hostile head cannot make
    /// the decoder reserve memory it will never fill.
    fn length(&self, arg: u64) -> Result<usize, DagCborError> {
        usize::try_from(arg)
            .ok()
            .filter(|len| *len <= self.bytes.len() - self.pos)
            .ok_or(DagCborError::LengthExceedsInput)
    }

    fn text(&mut self, arg: u64) -> Result<&'a str, DagCborError> {
        let len = self.length(arg)?;
        std::str::from_utf8(self.take(len)?).map_err(|_| DagCborError::InvalidUtf8)
    }

    fn item(&mut self, depth: usize) -> Result<Value, DagCborError> {
        let (major, arg) = self.head()?;
        match major {
            0 => i64::try_from(arg)
                .map(Value::Integer)
                .map_err(|_| DagCborError::IntegerOutOfRange),
            1 => i64::try_from(arg)
                .map(|n| Value::Integer(-1 - n))
                .map_err(|_| DagCborError::IntegerOutOfRange),
            2 => {
                let len = self.length(arg)?;
                Ok(Value::Bytes(self.take(len)?.to_vec()))
            }
            3 => Ok(Value::String(self.text(arg)?.to_owned())),
            4 => {
                let depth = self.descend(depth)?;
                let len = self.length(arg)?;
                let mut items = Vec::with_capacity(len);
                for _ in 0..len {
                    items.push(self.item(depth)?);
                }
                Ok(Value::Array(items))
            }
            5 => self.map(arg, depth),
            6 => self.link(arg),
            _ => match arg {
                20 => Ok(Value::Bool(false)),
                21 => Ok(Value::Bool(true)),
                22 => Ok(Value::Null),
                25..=27 => Err(DagCborError::FloatNotAllowed),
                31 => Err(DagCborError::IndefiniteLength),
                // `arg` came from the five low bits of one byte.
                other => Err(DagCborError::Unsupported(0xe0 | other.to_be_bytes()[7])),
            },
        }
    }

    fn descend(&self, depth: usize) -> Result<usize, DagCborError> {
        if depth >= self.limits.max_depth {
            return Err(DagCborError::DepthExceeded(self.limits.max_depth));
        }
        Ok(depth + 1)
    }

    fn map(&mut self, arg: u64, depth: usize) -> Result<Value, DagCborError> {
        let depth = self.descend(depth)?;
        let len = self.length(arg)?;
        let mut map = BTreeMap::new();
        let mut previous: Option<&'a str> = None;
        for _ in 0..len {
            let (major, key_arg) = self.head()?;
            if major != 3 {
                return Err(DagCborError::NonStringKey);
            }
            let key = self.text(key_arg)?;
            if let Some(previous) = previous
                && canonical_order(previous.as_bytes(), key.as_bytes()).is_ge()
            {
                return Err(DagCborError::KeyOrder);
            }
            previous = Some(key);
            let value = self.item(depth)?;
            map.insert(key.to_owned(), value);
        }
        Ok(Value::Object(map))
    }

    fn link(&mut self, tag: u64) -> Result<Value, DagCborError> {
        if tag != 42 {
            return Err(DagCborError::UnsupportedTag(tag));
        }
        let (major, arg) = self.head()?;
        if major != 2 {
            return Err(DagCborError::InvalidLink(
                "tag 42 must wrap a byte string".into(),
            ));
        }
        let len = self.length(arg)?;
        match self.take(len)? {
            [0, cid @ ..] if !cid.is_empty() => Cid::from_bytes(cid)
                .map(Value::Link)
                .map_err(|error| DagCborError::InvalidLink(error.to_string())),
            _ => Err(DagCborError::InvalidLink(
                "missing the 0x00 multibase prefix".into(),
            )),
        }
    }
}
