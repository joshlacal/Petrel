//! Spaces LtHash: 1,024 little-endian 16-bit lanes added modulo 2^16 using BLAKE3 XOF.

use sha2::{Digest, Sha256};

/// Homomorphic set-hash commitment for ATProto Spaces (`SpaceSetHash`).
///
/// Uses BLAKE3 XOF (2,048 bytes = 1,024 `u16` little-endian lanes) over
/// `"{path}/{cid}"`, added or subtracted lane-wise modulo `2^16`, and finalized
/// with SHA-256 over the 2,048-byte state.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SpaceSetHash {
    state: [u8; 2048],
}

impl Default for SpaceSetHash {
    fn default() -> Self {
        Self::new()
    }
}

impl SpaceSetHash {
    /// Creates an empty zero-initialized `SpaceSetHash`.
    pub const fn new() -> Self {
        Self {
            state: [0_u8; 2048],
        }
    }

    /// Adds a `(path, cid)` record commitment into the set hash.
    pub fn add(&mut self, path: &str, cid: &str) {
        self.apply(path, cid, false);
    }

    /// Removes a `(path, cid)` record commitment from the set hash.
    pub fn remove(&mut self, path: &str, cid: &str) {
        self.apply(path, cid, true);
    }

    /// Returns the 32-byte SHA-256 digest of the current LtHash state.
    pub fn digest(&self) -> [u8; 32] {
        Sha256::digest(self.state).into()
    }

    fn apply(&mut self, path: &str, cid: &str, subtracting: bool) {
        let mut hasher = blake3::Hasher::new();
        hasher.update(path.as_bytes());
        hasher.update(b"/");
        hasher.update(cid.as_bytes());
        let mut expanded = [0_u8; 2048];
        hasher.finalize_xof().fill(&mut expanded);

        for offset in (0..2048).step_by(2) {
            let existing = u16::from_le_bytes([self.state[offset], self.state[offset + 1]]);
            let delta = u16::from_le_bytes([expanded[offset], expanded[offset + 1]]);
            let result = if subtracting {
                existing.wrapping_sub(delta)
            } else {
                existing.wrapping_add(delta)
            };
            let bytes = result.to_le_bytes();
            self.state[offset] = bytes[0];
            self.state[offset + 1] = bytes[1];
        }
    }
}
