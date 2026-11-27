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
use std::collections::BTreeMap;

use crate::cid::Cid;
use crate::error::{DagCborError, EncodeError};
use crate::value::Value;

/// Bounds on recursive work when decoding a DAG-CBOR value.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub struct Limits {
    /// Maximum nesting depth of arrays and maps.
    pub max_depth: usize,
    /// Maximum number of values, including containers and the root.
    pub max_nodes: usize,
    /// Maximum number of elements in one array or entries in one map.
    pub max_container_elements: usize,
}

impl Limits {
    /// Limits for ordinary values and XRPC bodies.
    pub const STANDARD: Self = Self {
        max_depth: 64,
        max_nodes: 10_000,
        max_container_elements: 65_536,
    };

    /// Limits for one repository block. Each value occupies at least one
    /// byte, so this admits any value count a 1 MB block can contain.
    pub const REPOSITORY_BLOCK: Self = Self {
        max_depth: 64,
        max_nodes: 1_000_000,
        max_container_elements: 1_000_000,
    };
}

impl Default for Limits {
    fn default() -> Self {
        Self::STANDARD
    }
}

/// Encodes a value as canonical DAG-CBOR.
///
/// A [`Value::Float`] (which only lenient JSON decoding produces, and which is
/// not AT Protocol data) is written as a CBOR float64, so the bytes are never
/// those of a data-model value and [`decode`] refuses them. Use [`try_encode`]
/// to refuse such a value instead.
pub fn encode(value: &Value) -> Vec<u8> {
    let mut out = Vec::new();
    encode_into(value, &mut out);
    out
}

/// Encodes a data-model value as canonical DAG-CBOR, refusing a value that
/// holds a [`Value::Float`]: the AT Protocol data model has no floats.
pub fn try_encode(value: &Value) -> Result<Vec<u8>, EncodeError> {
    if value.contains_float() {
        return Err(EncodeError::Custom(
            "floats are not allowed in the AT Protocol data model".into(),
        ));
    }
    Ok(encode(value))
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
        Value::Float(number) => {
            out.push(0xfb);
            out.extend_from_slice(&number.get().to_bits().to_be_bytes());
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
    let (value, remainder) = decode_prefix_with(bytes, limits)?;
    if !remainder.is_empty() {
        return Err(DagCborError::TrailingBytes);
    }
    Ok(value)
}

/// Decodes the first canonical item and returns the remaining bytes.
///
/// Use this only in a framed format that permits more bytes after an item.
pub fn decode_prefix_with(bytes: &[u8], limits: Limits) -> Result<(Value, &[u8]), DagCborError> {
    let mut reader = Reader {
        bytes,
        pos: 0,
        limits,
        remaining_nodes: limits.max_nodes,
    };
    let value = reader.item(0)?;
    Ok((value, &bytes[reader.pos..]))
}

struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
    limits: Limits,
    remaining_nodes: usize,
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

    /// A byte or text string length must fit in the remaining input.
    fn length(&self, arg: u64) -> Result<usize, DagCborError> {
        usize::try_from(arg)
            .ok()
            .filter(|len| *len <= self.bytes.len() - self.pos)
            .ok_or(DagCborError::LengthExceedsInput)
    }

    fn container_length(&self, arg: u64, bytes_per_element: usize) -> Result<usize, DagCborError> {
        let len = usize::try_from(arg).map_err(|_| DagCborError::LengthExceedsInput)?;
        if len > self.limits.max_container_elements {
            return Err(DagCborError::ContainerLimitExceeded(
                self.limits.max_container_elements,
            ));
        }
        if len > (self.bytes.len() - self.pos) / bytes_per_element {
            return Err(DagCborError::LengthExceedsInput);
        }
        if len > self.remaining_nodes {
            return Err(DagCborError::NodeLimitExceeded(self.limits.max_nodes));
        }
        Ok(len)
    }

    fn text(&mut self, arg: u64) -> Result<&'a str, DagCborError> {
        let len = self.length(arg)?;
        std::str::from_utf8(self.take(len)?).map_err(|_| DagCborError::InvalidUtf8)
    }

    fn item(&mut self, depth: usize) -> Result<Value, DagCborError> {
        self.remaining_nodes = self
            .remaining_nodes
            .checked_sub(1)
            .ok_or(DagCborError::NodeLimitExceeded(self.limits.max_nodes))?;
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
                let len = self.container_length(arg, 1)?;
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
        let len = self.container_length(arg, 2)?;
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
