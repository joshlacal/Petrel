//! Content identifiers.
//!
//! Petrel owns its [`Cid`] type instead of re-exporting the `cid` crate (plan
//! decision 3): the public API must not be tied to `ipld-core`, and Petrel
//! parses only the canonical string form.
//!
//! Lane 0 implemented what the serialization spike needs: binary and string
//! parsing of CIDv1 with single-byte codec and hash codes, the canonical
//! base32 string form, and SHA-256 construction. Lane A (work package C4)
//! completes the port of `Sources/PetrelCore/CID.swift`: varint codecs, the
//! `blessed_kind` policy used at the link boundary, length caps, and the
//! `ipld-interop` conversions.

use std::fmt;
use std::str::FromStr;

use sha2::{Digest, Sha256};

use crate::error::CidError;

const BASE32_ALPHABET: &[u8; 32] = b"abcdefghijklmnopqrstuvwxyz234567";

/// A CIDv1, stored as its binary form.
#[derive(Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Cid {
    bytes: Vec<u8>,
}

impl Cid {
    /// Multicodec code for raw bytes (blobs).
    pub const CODEC_RAW: u8 = 0x55;
    /// Multicodec code for DAG-CBOR (records, commits, MST nodes).
    pub const CODEC_DAG_CBOR: u8 = 0x71;
    /// Multihash code for SHA-256.
    pub const HASH_SHA2_256: u8 = 0x12;

    /// Parses the binary form: `0x01, codec, hash code, digest length, digest`.
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, CidError> {
        let [version, codec, hash, len, digest @ ..] = bytes else {
            return Err(CidError::Invalid("shorter than a CIDv1 header".into()));
        };
        if *version != 1 {
            return Err(CidError::Invalid("only CIDv1 is supported".into()));
        }
        if *codec >= 0x80 || *hash >= 0x80 || *len >= 0x80 {
            return Err(CidError::Invalid(
                "multi-byte varint codes are not supported".into(),
            ));
        }
        if *len == 0 || digest.len() != usize::from(*len) {
            return Err(CidError::Invalid(
                "digest length does not match its header".into(),
            ));
        }
        Ok(Self {
            bytes: bytes.to_vec(),
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
        let bytes = base32_decode(body)
            .ok_or_else(|| CidError::Invalid("not lowercase unpadded base32".into()))?;
        let cid = Self::from_bytes(&bytes)?;
        if cid.to_string() != text {
            return Err(CidError::Invalid("not the canonical string form".into()));
        }
        Ok(cid)
    }

    /// The CID of a DAG-CBOR block: SHA-256 over its bytes.
    pub fn for_dag_cbor(block: &[u8]) -> Self {
        Self::sha256(Self::CODEC_DAG_CBOR, block)
    }

    /// The CID of a raw block (a blob): SHA-256 over its bytes.
    pub fn for_raw(block: &[u8]) -> Self {
        Self::sha256(Self::CODEC_RAW, block)
    }

    fn sha256(codec: u8, block: &[u8]) -> Self {
        let digest = Sha256::digest(block);
        let mut bytes = Vec::with_capacity(4 + digest.len());
        bytes.extend_from_slice(&[1, codec, Self::HASH_SHA2_256, 32]);
        bytes.extend_from_slice(&digest);
        Self { bytes }
    }

    /// The binary form.
    pub fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }

    /// The multicodec content code.
    pub fn codec(&self) -> u8 {
        self.bytes[1]
    }

    /// The multihash function code.
    pub fn hash_code(&self) -> u8 {
        self.bytes[2]
    }

    /// The digest bytes.
    pub fn digest(&self) -> &[u8] {
        &self.bytes[4..]
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
