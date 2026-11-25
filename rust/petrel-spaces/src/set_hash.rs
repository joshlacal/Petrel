//! BLAKE3-XOF `SpaceSetHash` (LtHash) commitments and DAG-CBOR CID calculation.

use petrel_core::{Cid, Value, to_dag_cbor};
pub use petrel_crypto::SpaceSetHash;
use petrel_crypto::{ATProtoCrypto, blake3};

use crate::error::{Result, SpaceError};

/// Size of an expanded LtHash element state in bytes (`1024 * u16` lanes).
pub const LTHASH_BYTES: usize = 2048;

/// Compute the 2048-byte BLAKE3-XOF mask for a record `"{path}/{cid}"`.
pub fn compute_record_element_hash(path: &str, cid: &str) -> [u8; LTHASH_BYTES] {
    let mut hasher = blake3::Hasher::new();
    hasher.update(path.as_bytes());
    hasher.update(b"/");
    hasher.update(cid.as_bytes());
    let mut out = [0u8; LTHASH_BYTES];
    hasher.finalize_xof().fill(&mut out);
    out
}

/// Compute the 2048-byte BLAKE3-XOF mask for an inventory commitment element.
pub fn compute_inventory_element_hash(domain: &str, key: &str, extra: &str) -> [u8; LTHASH_BYTES] {
    let mut hasher = blake3::Hasher::new();
    hasher.update(domain.as_bytes());
    hasher.update(b"\0");
    hasher.update(key.as_bytes());
    hasher.update(b"\0");
    hasher.update(extra.as_bytes());
    let mut out = [0u8; LTHASH_BYTES];
    hasher.finalize_xof().fill(&mut out);
    out
}

/// Compute a `SpaceSetHash` over an iterator of `(path, cid)` pairs.
pub fn compute_set_hash<'a, I>(records: I) -> SpaceSetHash
where
    I: IntoIterator<Item = (&'a str, &'a str)>,
{
    let mut acc = SpaceSetHash::new();
    for (path, cid) in records {
        acc.add(path, cid);
    }
    acc
}

/// Compute the DAG-CBOR SHA-256 CIDv1 of a `Value`.
pub fn compute_dagcbor_cid(value: &Value) -> Result<Cid> {
    let bytes = to_dag_cbor(value).map_err(|e| SpaceError::CborEncoding(e.to_string()))?;
    Ok(Cid::for_dag_cbor(&bytes))
}

/// General-purpose 1024-lane `u16` mod-`2^16` BLAKE3-XOF LtHash supporting both
/// record commitments (`"{path}/{cid}"`) and domain-separated inventory commitments.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LtHash {
    state: [u8; LTHASH_BYTES],
}

impl Default for LtHash {
    fn default() -> Self {
        Self::new()
    }
}

impl LtHash {
    /// Create a zero-initialized LtHash accumulator.
    pub const fn new() -> Self {
        Self {
            state: [0u8; LTHASH_BYTES],
        }
    }

    /// Reconstruct an accumulator from an existing 2048-byte state buffer.
    pub const fn from_state(state: [u8; LTHASH_BYTES]) -> Self {
        Self { state }
    }

    /// Borrow the raw 2048-byte little-endian lane state.
    pub const fn state(&self) -> &[u8; LTHASH_BYTES] {
        &self.state
    }

    /// Add a `(path, cid)` record commitment.
    pub fn add_entry(&mut self, path: &str, cid: &str) {
        let mask = compute_record_element_hash(path, cid);
        self.apply_mask(&mask, false);
    }

    /// Remove a `(path, cid)` record commitment.
    pub fn remove_entry(&mut self, path: &str, cid: &str) {
        let mask = compute_record_element_hash(path, cid);
        self.apply_mask(&mask, true);
    }

    /// Add a domain-separated inventory commitment.
    pub fn add_inventory_entry(&mut self, domain: &str, key: &str, extra: &str) {
        let mask = compute_inventory_element_hash(domain, key, extra);
        self.apply_mask(&mask, false);
    }

    /// Remove a domain-separated inventory commitment.
    pub fn remove_inventory_entry(&mut self, domain: &str, key: &str, extra: &str) {
        let mask = compute_inventory_element_hash(domain, key, extra);
        self.apply_mask(&mask, true);
    }

    /// Compute the SHA-256 digest of the 2048-byte state.
    pub fn digest(&self) -> [u8; 32] {
        ATProtoCrypto::sha256(&self.state)
    }

    /// Alias for [`Self::digest`].
    pub fn hash(&self) -> [u8; 32] {
        self.digest()
    }

    fn apply_mask(&mut self, mask: &[u8; LTHASH_BYTES], subtracting: bool) {
        for offset in (0..LTHASH_BYTES).step_by(2) {
            let cur = u16::from_le_bytes([self.state[offset], self.state[offset + 1]]);
            let delta = u16::from_le_bytes([mask[offset], mask[offset + 1]]);
            let next = if subtracting {
                cur.wrapping_sub(delta)
            } else {
                cur.wrapping_add(delta)
            };
            let bytes = next.to_le_bytes();
            self.state[offset] = bytes[0];
            self.state[offset + 1] = bytes[1];
        }
    }
}
