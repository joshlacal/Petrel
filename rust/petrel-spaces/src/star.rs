//! `SpaceSTAR` archive encoding, decoding, and authenticated XRPC response verification.

use std::collections::BTreeSet;

use petrel_core::{
    Bytes, Cid, DecodeError, Did, EncodeError, FromValue, Nsid, ObjectReader, ObjectWriter,
    RecordKey, SpaceRef, Tid, ToValue, Value,
    dagcbor::{Limits, decode_with, encode},
    from_dag_cbor,
};
use petrel_crypto::SpaceSetHash;

use crate::error::{Result, SpaceError, parse_space_ref};

/// Magic header prefix (`*l`) + LE version `1` (`[0x2a, 0x6c, 0x01, 0x00]`).
pub const STAR_MAGIC: [u8; 2] = *b"*l";
pub const STAR_VERSION: u16 = 1;
const TAG_END: u8 = 0x00;
const TAG_RECORD: u8 = 0x01;
const TAG_BLOB: u8 = 0x02;
const HEADER_TYPE_TAG: &str = "atproto-space-repo";

/// Default maximum archive byte limit (5 MiB, matching `SpaceCredentialManager.swift`).
pub const DEFAULT_MAX_ARCHIVE_BYTES: usize = 5 * 1024 * 1024;
/// JavaScript / ATProto DAG-CBOR safe integer minimum (`-(2^53 - 1)`).
pub const SAFE_INT_MIN: i64 = -9_007_199_254_740_991;
/// JavaScript / ATProto DAG-CBOR safe integer maximum (`2^53 - 1`).
pub const SAFE_INT_MAX: i64 = 9_007_199_254_740_991;

/// Metadata embedded in a STAR repository archive header.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StarRepoMetadata {
    pub ver: u64,
    pub space: SpaceRef,
    pub repo: Did,
    pub rev: Tid,
    pub data: [u8; 32],
}

/// Wire DAG-CBOR struct for the STAR header block.
struct StarRepoHeaderCbor {
    kind: String,
    ver: i64,
    space: String,
    repo: String,
    rev: String,
    data: Bytes,
}

impl ToValue for StarRepoHeaderCbor {
    fn to_value(&self) -> core::result::Result<Value, EncodeError> {
        let mut writer = ObjectWriter::with_type(&self.kind);
        writer.field("ver", &self.ver)?;
        writer.field("space", &self.space)?;
        writer.field("repo", &self.repo)?;
        writer.field("rev", &self.rev)?;
        writer.field("data", &self.data)?;
        Ok(writer.finish())
    }
}

impl FromValue for StarRepoHeaderCbor {
    fn from_value(value: Value) -> core::result::Result<Self, DecodeError> {
        let mut reader = ObjectReader::new_strict(value)?;
        Ok(Self {
            kind: reader.required("$type")?,
            ver: reader.required("ver")?,
            space: reader.required("space")?,
            repo: reader.required("repo")?,
            rev: reader.required("rev")?,
            data: reader.required("data")?,
        })
    }
}

/// A decoded STAR record entry containing path, DAG-CBOR bytes, decoded `Value`, and CID.
#[derive(Debug, Clone, PartialEq)]
pub struct StarRecordEntry {
    pub path: String,
    pub collection: Nsid,
    pub rkey: RecordKey,
    pub cid: Cid,
    pub cbor: Vec<u8>,
    pub value: Value,
}

/// Decoded contents of a verified STAR repository archive.
#[derive(Debug, Clone, PartialEq)]
pub struct StarRepo {
    pub metadata: StarRepoMetadata,
    pub records: Vec<StarRecordEntry>,
}

/// Encode `(space, repo, rev, records)` into canonical STAR v1 archive bytes (`*l\x01\x00`).
///
/// Records are canonicalized to DAG-CBOR, hashed into `SpaceSetHash`, sorted deterministically by
/// path (checking for duplicate or invalid paths), and packed into a STAR v1 stream.
pub fn write_star_repo(
    space: &SpaceRef,
    repo: &Did,
    rev: &Tid,
    records: &[(&str, &Value)],
) -> Result<Vec<u8>> {
    let mut prepared: Vec<(String, Vec<u8>, Cid)> = Vec::with_capacity(records.len());
    let mut seen = BTreeSet::new();
    let mut set_hash = SpaceSetHash::new();

    for &(path, value) in records {
        let _ = parse_record_path(path)?;
        if !seen.insert(path.to_owned()) {
            return Err(SpaceError::InvalidArchive(format!(
                "duplicate record path in archive: {path}"
            )));
        }
        let cbor = encode(value);
        let cid = Cid::for_dag_cbor(&cbor);
        set_hash.add(path, &cid.to_string());
        prepared.push((path.to_owned(), cbor, cid));
    }

    prepared.sort_by(|a, b| a.0.cmp(&b.0));

    let data = set_hash.digest();
    let header = StarRepoHeaderCbor {
        kind: HEADER_TYPE_TAG.to_owned(),
        ver: 1,
        space: space.as_str().to_owned(),
        repo: repo.as_str().to_owned(),
        rev: rev.as_str().to_owned(),
        data: Bytes(data.to_vec()),
    };
    let header_value = header
        .to_value()
        .map_err(|e| SpaceError::CborEncoding(e.to_string()))?;
    let header_cbor = encode(&header_value);

    let mut out = Vec::with_capacity(4 + 8 + header_cbor.len() + prepared.len() * 64 + 1);
    out.extend_from_slice(&STAR_MAGIC);
    out.extend_from_slice(&STAR_VERSION.to_le_bytes());
    write_uvarint(header_cbor.len() as u64, &mut out);
    out.extend_from_slice(&header_cbor);

    for (path, cbor, _) in prepared {
        out.push(TAG_RECORD);
        write_uvarint(path.len() as u64, &mut out);
        out.extend_from_slice(path.as_bytes());
        write_uvarint(cbor.len() as u64, &mut out);
        out.extend_from_slice(&cbor);
    }
    out.push(TAG_END);
    Ok(out)
}

/// Read only the header metadata from a STAR archive without decoding all entries.
pub fn read_star_metadata(bytes: &[u8]) -> Result<StarRepoMetadata> {
    let (metadata, _) = decode_star_header(bytes)?;
    Ok(metadata)
}

/// Decode and cryptographically verify a STAR archive (validating paths, DAG-CBOR limits, and `SpaceSetHash`).
pub fn read_star_repo(bytes: &[u8], max_archive_bytes: usize) -> Result<StarRepo> {
    if bytes.len() > max_archive_bytes {
        return Err(SpaceError::ArchiveTooLarge {
            actual: bytes.len(),
            max: max_archive_bytes,
        });
    }
    let (metadata, mut cursor) = decode_star_header(bytes)?;
    let mut records = Vec::new();
    let mut seen = BTreeSet::new();
    let mut set_hash = SpaceSetHash::new();

    loop {
        let tag = *bytes
            .get(cursor)
            .ok_or_else(|| SpaceError::InvalidArchive("unexpected EOF before end tag".into()))?;
        cursor += 1;
        match tag {
            TAG_END => {
                if cursor != bytes.len() {
                    return Err(SpaceError::InvalidArchive(
                        "trailing bytes after STAR end marker".into(),
                    ));
                }
                break;
            }
            TAG_RECORD => {
                let path_len = read_uvarint_usize(bytes, &mut cursor)?;
                let path_bytes = take_slice(bytes, &mut cursor, path_len)?;
                let path = std::str::from_utf8(path_bytes)
                    .map_err(|_| SpaceError::InvalidArchive("non-utf8 record path".into()))?
                    .to_owned();
                let (collection, rkey) = parse_record_path(&path)?;
                if !seen.insert(path.clone()) {
                    return Err(SpaceError::InvalidArchive(format!(
                        "duplicate record path '{path}'"
                    )));
                }
                let cbor_len = read_uvarint_usize(bytes, &mut cursor)?;
                let cbor_bytes = take_slice(bytes, &mut cursor, cbor_len)?.to_vec();
                let value = decode_with(&cbor_bytes, Limits::REPOSITORY_BLOCK)
                    .map_err(|e| SpaceError::InvalidCbor(e.to_string()))?;
                let cid = Cid::for_dag_cbor(&cbor_bytes);
                set_hash.add(&path, &cid.to_string());
                records.push(StarRecordEntry {
                    path,
                    collection,
                    rkey,
                    cid,
                    cbor: cbor_bytes,
                    value,
                });
            }
            TAG_BLOB => {
                return Err(SpaceError::BlobNotSupported(
                    "STAR blob entries are not supported".into(),
                ));
            }
            other => {
                return Err(SpaceError::InvalidArchive(format!(
                    "unknown STAR entry tag 0x{other:02x}"
                )));
            }
        }
    }

    let computed = set_hash.digest();
    if computed != metadata.data {
        return Err(SpaceError::DataHashMismatch {
            expected: encode_hex(&metadata.data),
            actual: encode_hex(&computed),
        });
    }

    Ok(StarRepo { metadata, records })
}

/// Decode and verify a STAR archive against MAC-authenticated commit expectations.
pub fn read_star_repo_authenticated(
    bytes: &[u8],
    expected_space: &SpaceRef,
    expected_repo: Option<&Did>,
    expected_rev: Option<&Tid>,
    expected_data: Option<&[u8; 32]>,
    max_archive_bytes: usize,
) -> Result<StarRepo> {
    let repo = read_star_repo(bytes, max_archive_bytes)?;
    if &repo.metadata.space != expected_space {
        return Err(SpaceError::InvalidArchive(format!(
            "STAR space mismatch: expected {expected_space}, got {}",
            repo.metadata.space
        )));
    }
    if let Some(exp_repo) = expected_repo
        && &repo.metadata.repo != exp_repo
    {
        return Err(SpaceError::InvalidArchive(format!(
            "STAR repo mismatch: expected {exp_repo}, got {}",
            repo.metadata.repo
        )));
    }
    if let Some(exp_rev) = expected_rev
        && &repo.metadata.rev != exp_rev
    {
        return Err(SpaceError::InvalidArchive(format!(
            "STAR rev mismatch: expected {exp_rev}, got {}",
            repo.metadata.rev
        )));
    }
    if let Some(exp_data) = expected_data
        && &repo.metadata.data != exp_data
    {
        return Err(SpaceError::DataHashMismatch {
            expected: encode_hex(exp_data),
            actual: encode_hex(&repo.metadata.data),
        });
    }
    Ok(repo)
}

/// Convert JSON data model bytes into canonical DAG-CBOR `Value`, enforcing JS safe integers.
pub fn verify_json_value_for_dag_cbor(json: &serde_json::Value) -> Result<Value> {
    check_safe_json_numbers(json)?;
    let bytes =
        serde_json::to_vec(json).map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;
    Value::from_json_data_model(&bytes).map_err(|e| SpaceError::InvalidCbor(e.to_string()))
}

/// Verify a `getRecord` JSON payload's CID against its canonical DAG-CBOR encoding.
pub fn verify_record_cid(record_json: &serde_json::Value, expected_cid: &Cid) -> Result<Vec<u8>> {
    let value = verify_json_value_for_dag_cbor(record_json)?;
    let cbor = encode(&value);
    let actual_cid = Cid::for_dag_cbor(&cbor);
    if &actual_cid != expected_cid {
        return Err(SpaceError::DataHashMismatch {
            expected: expected_cid.to_string(),
            actual: actual_cid.to_string(),
        });
    }
    Ok(cbor)
}

fn check_safe_json_numbers(val: &serde_json::Value) -> Result<()> {
    match val {
        serde_json::Value::Number(num) => {
            if let Some(i) = num.as_i64() {
                if !(SAFE_INT_MIN..=SAFE_INT_MAX).contains(&i) {
                    return Err(SpaceError::UnsafeInteger(i.to_string()));
                }
            } else if let Some(u) = num.as_u64() {
                if u > SAFE_INT_MAX as u64 {
                    return Err(SpaceError::UnsafeInteger(u.to_string()));
                }
            } else {
                return Err(SpaceError::UnsafeInteger(num.to_string()));
            }
            Ok(())
        }
        serde_json::Value::Array(arr) => {
            for item in arr {
                check_safe_json_numbers(item)?;
            }
            Ok(())
        }
        serde_json::Value::Object(map) => {
            for v in map.values() {
                check_safe_json_numbers(v)?;
            }
            Ok(())
        }
        _ => Ok(()),
    }
}

fn decode_star_header(bytes: &[u8]) -> Result<(StarRepoMetadata, usize)> {
    if bytes.len() < 4 {
        return Err(SpaceError::InvalidArchive(
            "archive shorter than 4-byte STAR magic+version header".into(),
        ));
    }
    if bytes[0..2] != STAR_MAGIC {
        return Err(SpaceError::InvalidArchive(
            "invalid STAR magic bytes".into(),
        ));
    }
    let version = u16::from_le_bytes([bytes[2], bytes[3]]);
    if version != STAR_VERSION {
        return Err(SpaceError::InvalidArchive(format!(
            "unsupported STAR version {version}"
        )));
    }
    let mut cursor = 4usize;
    let header_len = read_uvarint_usize(bytes, &mut cursor)?;
    let header_bytes = take_slice(bytes, &mut cursor, header_len)?;
    let header: StarRepoHeaderCbor =
        from_dag_cbor(header_bytes).map_err(|e| SpaceError::InvalidCbor(e.to_string()))?;
    if header.kind != HEADER_TYPE_TAG {
        return Err(SpaceError::InvalidArchive(format!(
            "unexpected STAR header $type '{}'",
            header.kind
        )));
    }
    if header.ver != 1 {
        return Err(SpaceError::InvalidArchive(format!(
            "unsupported STAR header ver={}",
            header.ver
        )));
    }
    let space = parse_space_ref(&header.space)?;
    let repo = Did::parse(&header.repo).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;
    let rev = Tid::parse(&header.rev).map_err(|e| SpaceError::InvalidTid(e.to_string()))?;
    let data: [u8; 32] = header
        .data
        .0
        .as_slice()
        .try_into()
        .map_err(|_| SpaceError::InvalidArchive("STAR header data must be 32 bytes".into()))?;

    Ok((
        StarRepoMetadata {
            ver: 1,
            space,
            repo,
            rev,
            data,
        },
        cursor,
    ))
}

fn parse_record_path(path: &str) -> Result<(Nsid, RecordKey)> {
    let mut parts = path.split('/');
    let col_str = parts
        .next()
        .ok_or_else(|| SpaceError::InvalidArchive(format!("empty record path '{path}'")))?;
    let rkey_str = parts
        .next()
        .ok_or_else(|| SpaceError::InvalidArchive(format!("missing rkey in '{path}'")))?;
    if parts.next().is_some() {
        return Err(SpaceError::InvalidArchive(format!(
            "record path '{path}' has extra segments"
        )));
    }
    let col = Nsid::parse(col_str).map_err(|e| SpaceError::InvalidNsid(e.to_string()))?;
    let rkey =
        RecordKey::parse(rkey_str).map_err(|e| SpaceError::InvalidRecordKey(e.to_string()))?;
    Ok((col, rkey))
}

fn write_uvarint(mut n: u64, out: &mut Vec<u8>) {
    while n >= 0x80 {
        let low = u8::try_from(n & 0x7f).unwrap_or(0);
        out.push(low | 0x80);
        n >>= 7;
    }
    out.push(u8::try_from(n & 0x7f).unwrap_or(0));
}

fn read_uvarint_usize(bytes: &[u8], cursor: &mut usize) -> Result<usize> {
    let mut value: u64 = 0;
    let mut shift = 0u32;
    for idx in 0..10 {
        let byte = *bytes
            .get(*cursor)
            .ok_or_else(|| SpaceError::InvalidArchive("truncated uvarint".into()))?;
        *cursor += 1;
        if idx == 9 && byte > 1 {
            return Err(SpaceError::InvalidArchive("uvarint overflow".into()));
        }
        value |= u64::from(byte & 0x7f) << shift;
        if (byte & 0x80) == 0 {
            return usize::try_from(value)
                .map_err(|_| SpaceError::InvalidArchive("uvarint exceeds usize".into()));
        }
        shift += 7;
    }
    Err(SpaceError::InvalidArchive("uvarint too long".into()))
}

fn take_slice<'a>(bytes: &'a [u8], cursor: &mut usize, len: usize) -> Result<&'a [u8]> {
    let end = cursor
        .checked_add(len)
        .ok_or_else(|| SpaceError::InvalidArchive("length overflow".into()))?;
    let slice = bytes
        .get(*cursor..end)
        .ok_or_else(|| SpaceError::InvalidArchive("unexpected EOF in STAR section".into()))?;
    *cursor = end;
    Ok(slice)
}

fn encode_hex(bytes: &[u8]) -> String {
    petrel_crypto::Hex::encode(bytes)
}
