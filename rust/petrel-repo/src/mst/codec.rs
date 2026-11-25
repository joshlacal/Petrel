use std::collections::BTreeMap;

use petrel_core::{Cid, Value, dagcbor};
use sha2::{Digest as _, Sha256};

use crate::error::MstError;
use crate::mst::tree::MstKeySyntax;
use crate::types::{RepositoryPath, RepositoryReadPolicy};

/// Decoded entry within a raw MST node (`RepositoryMSTNodeEntry`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstNodeEntry {
    pub prefix_len: usize,
    pub key_suffix: Vec<u8>,
    pub value: Cid,
    pub tree: Option<Cid>,
}

/// Decoded MST node block (`RepositoryMSTNode`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstNode {
    pub left: Option<Cid>,
    pub entries: Vec<MstNodeEntry>,
}

/// Materialized entry with expanded full UTF-8 key.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstNodeEntryView {
    pub key: String,
    pub value: Cid,
    pub tree: Option<Cid>,
}

/// Materialized MST node with expanded keys.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstNodeView {
    pub left: Option<Cid>,
    pub entries: Vec<MstNodeEntryView>,
}

/// Canonical AT Protocol MST key height (`SHA-256(key)` leading 2-bit zero chunks).
pub fn key_depth(key: &[u8]) -> usize {
    let hash: [u8; 32] = Sha256::digest(key).into();
    let mut zeros_pairs = 0_usize;
    for byte in hash {
        if byte == 0 {
            zeros_pairs += 4;
        } else {
            zeros_pairs += (byte.leading_zeros() as usize) / 2;
            break;
        }
    }
    zeros_pairs
}

/// Shared byte prefix length of two keys.
pub fn common_prefix_len(a: &[u8], b: &[u8]) -> usize {
    a.iter().zip(b.iter()).take_while(|(x, y)| x == y).count()
}

/// Validates an MST key against `syntax`.
pub fn validate_mst_key(key: &str, syntax: MstKeySyntax) -> Result<(), MstError> {
    if key.is_empty() || key.len() > RepositoryPath::MAXIMUM_MST_KEY_BYTES {
        return Err(MstError::InvalidKey(format!(
            "MST key byte length {} out of bounds (1..={})",
            key.len(),
            RepositoryPath::MAXIMUM_MST_KEY_BYTES
        )));
    }
    match syntax {
        MstKeySyntax::StrictAtProto => {
            RepositoryPath::from_mst_key(key)?;
        }
        MstKeySyntax::TwoSegment => {
            let Some((collection, rkey)) = key.split_once('/') else {
                return Err(MstError::InvalidKey(format!(
                    "MST key must have two '/' segments: {key:?}"
                )));
            };
            if collection.is_empty() || rkey.is_empty() || rkey.contains('/') {
                return Err(MstError::InvalidKey(format!(
                    "MST key must have non-empty collection and rkey without extra '/': {key:?}"
                )));
            }
        }
        MstKeySyntax::PermissiveUtf8 => {}
    }
    Ok(())
}

/// Encodes expanded entries into a canonical AT Protocol MST node DAG-CBOR block
/// (`{"e": [...], "l": left_or_null}`).
pub fn encode_mst_node(view: &MstNodeView) -> Result<(Cid, Vec<u8>), MstError> {
    let mut encoded_entries = Vec::with_capacity(view.entries.len());
    let mut prev_bytes: Vec<u8> = Vec::new();
    for entry in &view.entries {
        let key_bytes = entry.key.as_bytes();
        if !prev_bytes.is_empty() && key_bytes <= prev_bytes.as_slice() {
            return Err(MstError::KeyOrderViolation {
                previous: String::from_utf8_lossy(&prev_bytes).into_owned(),
                next: entry.key.clone(),
            });
        }
        let prefix_len = common_prefix_len(&prev_bytes, key_bytes);
        let suffix = key_bytes[prefix_len..].to_vec();
        prev_bytes = key_bytes.to_vec();

        let prefix_len_i64 = i64::try_from(prefix_len)
            .map_err(|_| MstError::InvalidNode("MST prefix length exceeds i64::MAX".into()))?;
        let mut map = BTreeMap::new();
        map.insert("k".to_owned(), Value::Bytes(suffix));
        map.insert("p".to_owned(), Value::Integer(prefix_len_i64));
        map.insert(
            "t".to_owned(),
            match &entry.tree {
                Some(cid) => Value::Link(cid.clone()),
                None => Value::Null,
            },
        );
        map.insert("v".to_owned(), Value::Link(entry.value.clone()));
        encoded_entries.push(Value::Object(map));
    }

    let mut root_map = BTreeMap::new();
    root_map.insert("e".to_owned(), Value::Array(encoded_entries));
    root_map.insert(
        "l".to_owned(),
        match &view.left {
            Some(cid) => Value::Link(cid.clone()),
            None => Value::Null,
        },
    );
    let bytes = dagcbor::encode(&Value::Object(root_map));
    let cid = Cid::for_dag_cbor(&bytes);
    Ok((cid, bytes))
}

/// Decodes and structurally validates an MST node block under `syntax` and `policy`.
#[allow(clippy::too_many_lines)]
pub fn decode_mst_node(
    bytes: &[u8],
    syntax: MstKeySyntax,
    policy: &RepositoryReadPolicy,
    require_canonical_prefix: bool,
) -> Result<MstNodeView, MstError> {
    let val = dagcbor::decode_with(bytes, dagcbor::Limits::REPOSITORY_BLOCK)
        .map_err(|err| MstError::InvalidNode(err.to_string()))?;
    let Value::Object(map) = val else {
        return Err(MstError::InvalidNode("MST node must be a map".into()));
    };
    if map.len() != 2 || !map.contains_key("e") || !map.contains_key("l") {
        return Err(MstError::InvalidNode(
            "MST node map must contain exact keys 'e' and 'l'".into(),
        ));
    }

    let left = match map.get("l") {
        Some(Value::Null) => None,
        Some(Value::Link(cid)) => {
            if policy.requires_blessed_record_links_in_mst && !cid.is_blessed() {
                return Err(MstError::UnblessedLink(cid.to_string()));
            }
            Some(cid.clone())
        }
        _ => {
            return Err(MstError::InvalidNode(
                "MST node 'l' must be link or null".into(),
            ));
        }
    };

    let Some(Value::Array(raw_entries)) = map.get("e") else {
        return Err(MstError::InvalidNode(
            "MST node 'e' must be an array".into(),
        ));
    };

    let mut entries = Vec::with_capacity(raw_entries.len());
    let mut prev_bytes: Vec<u8> = Vec::new();
    let mut prev_key: Option<String> = None;

    for raw_entry in raw_entries {
        let Value::Object(entry_map) = raw_entry else {
            return Err(MstError::InvalidNode("MST entry must be a map".into()));
        };
        if entry_map.len() != 4
            || !entry_map.contains_key("k")
            || !entry_map.contains_key("p")
            || !entry_map.contains_key("t")
            || !entry_map.contains_key("v")
        {
            return Err(MstError::InvalidNode(
                "MST entry must contain exact keys 'k', 'p', 't', 'v'".into(),
            ));
        }

        let prefix_len = match entry_map.get("p") {
            Some(Value::Integer(p)) if *p >= 0 => usize::try_from(*p)
                .map_err(|_| MstError::InvalidNode("MST 'p' integer overflow".into()))?,
            _ => {
                return Err(MstError::InvalidNode(
                    "MST entry 'p' must be a non-negative integer".into(),
                ));
            }
        };
        if prefix_len > prev_bytes.len() {
            return Err(MstError::InvalidNode(format!(
                "MST prefix length {prefix_len} exceeds previous key length {}",
                prev_bytes.len()
            )));
        }

        let Some(Value::Bytes(suffix)) = entry_map.get("k") else {
            return Err(MstError::InvalidNode(
                "MST entry 'k' must be a byte string".into(),
            ));
        };
        let mut full_bytes = Vec::with_capacity(prefix_len + suffix.len());
        full_bytes.extend_from_slice(&prev_bytes[..prefix_len]);
        full_bytes.extend_from_slice(suffix);

        if require_canonical_prefix && prefix_len != common_prefix_len(&prev_bytes, &full_bytes) {
            return Err(MstError::NonCanonical(format!(
                "non-canonical MST prefix length {prefix_len} (expected {})",
                common_prefix_len(&prev_bytes, &full_bytes)
            )));
        }

        let key = String::from_utf8(full_bytes.clone())
            .map_err(|_| MstError::InvalidKey("MST key is not valid UTF-8".into()))?;
        validate_mst_key(&key, syntax)?;

        if let Some(prev) = &prev_key
            && &key <= prev
        {
            return Err(MstError::KeyOrderViolation {
                previous: prev.clone(),
                next: key,
            });
        }

        let value = match entry_map.get("v") {
            Some(Value::Link(cid)) => {
                if policy.requires_blessed_record_links_in_mst && !cid.is_blessed() {
                    return Err(MstError::UnblessedLink(cid.to_string()));
                }
                cid.clone()
            }
            _ => {
                return Err(MstError::InvalidNode(
                    "MST entry 'v' must be a CID link".into(),
                ));
            }
        };

        let tree = match entry_map.get("t") {
            Some(Value::Null) => None,
            Some(Value::Link(cid)) => {
                if policy.requires_blessed_record_links_in_mst && !cid.is_blessed() {
                    return Err(MstError::UnblessedLink(cid.to_string()));
                }
                Some(cid.clone())
            }
            _ => {
                return Err(MstError::InvalidNode(
                    "MST entry 't' must be link or null".into(),
                ));
            }
        };

        prev_bytes = full_bytes;
        prev_key = Some(key.clone());
        entries.push(MstNodeEntryView { key, value, tree });
    }

    Ok(MstNodeView { left, entries })
}
