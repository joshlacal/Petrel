//! Content identifiers.
//!
//! Petrel owns its [`Cid`] type instead of re-exporting the `cid` crate (plan
//! decision 3): the public API must not be tied to `ipld-core`, and Petrel
//! parses only the canonical string form.
//!
//! The generic value codec preserves any well-formed CIDv1 with a supported
//! digest length. Use `parse_blessed` when a link requires the AT Protocol
//! SHA-256 profile.

use std::fmt;
use std::str::FromStr;

use sha2::{Digest, Sha256};

use crate::error::{CidError, DecodeError, EncodeError};
use crate::serde_bridge::{FromValue, ToValue};
use crate::value::{Value, serde_via_value};

const BASE32_ALPHABET: &[u8; 32] = b"abcdefghijklmnopqrstuvwxyz234567";
const MAX_DIGEST_LEN: usize = 64;
const MAX_BINARY_LEN: usize = 1 + 10 + 10 + 1 + MAX_DIGEST_LEN;
const MAX_STRING_LEN: usize = 1 + (MAX_BINARY_LEN * 8).div_ceil(5);
const RAW_CODE: u8 = 0x55;
const DAG_CBOR_CODE: u8 = 0x71;
const SHA2_256_CODE: u8 = 0x12;

/// The two content codecs blessed for SHA-256 CIDs in AT Protocol.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BlessedKind {
    /// Raw bytes, used for blobs.
    Raw,
    /// DAG-CBOR blocks, used for records, commits and MST nodes.
    DagCbor,
}

/// A CIDv1, stored as its binary form.
///
/// Bare CIDs accept their string or link form on decode and serialize as
/// strings. Use [`CidLink`](crate::CidLink) for a typed CBOR link.
#[derive(Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Cid {
    bytes: Vec<u8>,
    codec: u64,
    hash_code: u64,
    digest_start: usize,
}

impl Cid {
    /// Multicodec code for raw bytes (blobs).
    pub const CODEC_RAW: u64 = RAW_CODE as u64;
    /// Multicodec code for DAG-CBOR (records, commits, MST nodes).
    pub const CODEC_DAG_CBOR: u64 = DAG_CBOR_CODE as u64;
    /// Multihash code for SHA-256.
    pub const HASH_SHA2_256: u64 = SHA2_256_CODE as u64;

    /// Parses CIDv1 with canonical unsigned-varint codec and multihash codes
    /// and a 1–64 byte digest. The resulting CID keeps the binary form.
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, CidError> {
        let Some((&1, mut header)) = bytes.split_first() else {
            return Err(CidError::Invalid("only CIDv1 is supported".into()));
        };
        let codec = take_varint(&mut header)?;
        let hash_code = take_varint(&mut header)?;
        let digest_len = take_varint(&mut header)?;
        if header.is_empty() || header.len() > MAX_DIGEST_LEN || header.len() as u64 != digest_len {
            return Err(CidError::Invalid(
                "digest length must match its header and be in 1..=64".into(),
            ));
        }
        Ok(Self {
            bytes: bytes.to_vec(),
            codec,
            hash_code,
            digest_start: bytes.len() - header.len(),
        })
    }

    /// Parses the canonical string form: multibase `b`, lowercase unpadded
    /// base32. Any other spelling of the same CID is refused.
    pub fn parse(text: &str) -> Result<Self, CidError> {
        let Some(body) = text.strip_prefix('b') else {
            return Err(CidError::Invalid(
                "only multibase base32 (`b` prefix) is accepted".into(),
            ));
        };
        if !(9..=MAX_STRING_LEN).contains(&text.len()) {
            return Err(CidError::Invalid("CID string length out of range".into()));
        }
        let bytes = base32_decode(body)
            .ok_or_else(|| CidError::Invalid("not lowercase unpadded base32".into()))?;
        let cid = Self::from_bytes(&bytes)?;
        if cid.to_string() != text {
            return Err(CidError::Invalid("not the canonical string form".into()));
        }
        Ok(cid)
    }

    /// Parses a canonical CID in either blessed content codec.
    pub fn parse_blessed(text: &str) -> Result<Self, CidError> {
        let cid = Self::parse(text)?;
        if cid.is_blessed() {
            Ok(cid)
        } else {
            Err(CidError::NotBlessed)
        }
    }

    /// Identifies a DAG-CBOR or raw CID using SHA-256 and a 32-byte digest.
    pub fn blessed_kind(&self) -> Option<BlessedKind> {
        if self.hash_code != Self::HASH_SHA2_256 || self.digest().len() != 32 {
            return None;
        }
        match self.codec {
            Self::CODEC_RAW => Some(BlessedKind::Raw),
            Self::CODEC_DAG_CBOR => Some(BlessedKind::DagCbor),
            _ => None,
        }
    }

    /// Whether the CID uses a blessed codec and hash.
    pub fn is_blessed(&self) -> bool {
        self.blessed_kind().is_some()
    }

    /// Checks the SHA-256 digest of the given content. Returns false for a
    /// non-blessed CID since Petrel cannot verify its format.
    pub fn matches_content(&self, content: &[u8]) -> bool {
        self.is_blessed() && self.digest() == &Sha256::digest(content)[..]
    }

    /// The CID of a DAG-CBOR block: SHA-256 over its bytes.
    pub fn for_dag_cbor(block: &[u8]) -> Self {
        Self::sha256(DAG_CBOR_CODE, block)
    }

    /// The CID of a raw block (a blob): SHA-256 over its bytes.
    pub fn for_raw(block: &[u8]) -> Self {
        Self::sha256(RAW_CODE, block)
    }

    fn sha256(codec: u8, block: &[u8]) -> Self {
        let digest = Sha256::digest(block);
        let mut bytes = Vec::with_capacity(4 + digest.len());
        bytes.extend_from_slice(&[1, codec, SHA2_256_CODE, 32]);
        bytes.extend_from_slice(&digest);
        Self {
            bytes,
            codec: u64::from(codec),
            hash_code: Self::HASH_SHA2_256,
            digest_start: 4,
        }
    }

    /// The binary form.
    pub fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }

    /// The multicodec content code.
    pub fn codec(&self) -> u64 {
        self.codec
    }

    /// The multihash function code.
    pub fn hash_code(&self) -> u64 {
        self.hash_code
    }

    /// The digest bytes.
    pub fn digest(&self) -> &[u8] {
        &self.bytes[self.digest_start..]
    }
}

impl fmt::Display for Cid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("b")?;
        f.write_str(&base32_encode(&self.bytes))
    }
}

impl fmt::Debug for Cid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Cid({self})")
    }
}

impl FromStr for Cid {
    type Err = CidError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::parse(s)
    }
}

impl ToValue for Cid {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::String(self.to_string()))
    }
}

impl FromValue for Cid {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        match value {
            Value::String(text) => Ok(Self::parse(&text)?),
            Value::Link(cid) => Ok(cid),
            Value::Object(mut fields) => {
                let link = fields
                    .remove("$link")
                    .ok_or_else(|| DecodeError::MissingField("$link".into()))?;
                if !fields.is_empty() {
                    return Err(DecodeError::Custom(
                        "a `$link` object must have no other fields".into(),
                    ));
                }
                let text = String::from_value(link).map_err(|error| error.in_field("$link"))?;
                Ok(Self::parse(&text)?)
            }
            other => Err(DecodeError::TypeMismatch {
                expected: "CID string or link",
                found: other.kind(),
            }),
        }
    }
}

serde_via_value!(Cid);

#[cfg(feature = "ipld-interop")]
impl TryFrom<::cid::Cid> for Cid {
    type Error = CidError;

    fn try_from(value: ::cid::Cid) -> Result<Self, Self::Error> {
        Self::from_bytes(&value.to_bytes())
    }
}

#[cfg(feature = "ipld-interop")]
impl From<Cid> for ::cid::Cid {
    fn from(value: Cid) -> Self {
        // Construction of Cid always bounds the digest at 64 bytes.
        let hash = ::cid::multihash::Multihash::<64>::wrap(value.hash_code(), value.digest())
            .expect("Petrel CID digest always fits in a 64-byte multihash");
        Self::new_v1(value.codec(), hash)
    }
}

/// Reads one shortest-form LEB128 u64.
fn take_varint(input: &mut &[u8]) -> Result<u64, CidError> {
    let mut value = 0;
    for (index, &byte) in input.iter().take(10).enumerate() {
        let payload = u64::from(byte & 0x7f);
        if index == 9 && payload > 1 {
            break;
        }
        value |= payload << (index * 7);
        if byte < 0x80 {
            if index != 0 && payload == 0 {
                return Err(CidError::Invalid("non-minimal varint".into()));
            }
            *input = &input[index + 1..];
            return Ok(value);
        }
    }
    Err(CidError::Invalid("truncated or overflowing varint".into()))
}

fn base32_encode(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len().div_ceil(5) * 8);
    let mut buffer: u32 = 0;
    let mut bits = 0;
    for &byte in bytes {
        buffer = (buffer << 8) | u32::from(byte);
        bits += 8;
        while bits >= 5 {
            bits -= 5;
            out.push(char::from(
                BASE32_ALPHABET[((buffer >> bits) & 31) as usize],
            ));
        }
    }
    if bits > 0 {
        out.push(char::from(
            BASE32_ALPHABET[((buffer << (5 - bits)) & 31) as usize],
        ));
    }
    out
}

fn base32_decode(text: &str) -> Option<Vec<u8>> {
    let mut out = Vec::with_capacity(text.len() * 5 / 8);
    let mut buffer: u32 = 0;
    let mut bits = 0;
    for ch in text.bytes() {
        let value = match ch {
            b'a'..=b'z' => ch - b'a',
            b'2'..=b'7' => ch - b'2' + 26,
            _ => return None,
        };
        buffer = (buffer << 5) | u32::from(value);
        bits += 5;
        if bits >= 8 {
            bits -= 8;
            out.push(u8::try_from((buffer >> bits) & 0xff).ok()?);
        }
    }
    Some(out)
}
