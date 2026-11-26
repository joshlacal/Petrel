//! Strict CARv1 reader/writer, `DiffCarBlockReader` trait seam, and `PublicFirehoseDiffCAR`.

use std::collections::BTreeMap;

use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::{Cid, Value, cid::BlessedKind, dagcbor};

use crate::types::RelayVerifierError;

/// Default maximum CAR payload size (128 MiB) when no tighter frame cap applies.
pub const DEFAULT_MAX_CAR_BYTES: usize = 128 * 1024 * 1024;
/// Default maximum blocks per CAR archive.
pub const DEFAULT_MAX_CAR_BLOCKS: usize = 1_000_000;
/// Default maximum single record block size (1 MiB).
pub const DEFAULT_MAX_RECORD_BLOCK_BYTES: usize = 1024 * 1024;

/// One content-addressed repository block.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CarBlock {
    pub cid: Cid,
    pub bytes: Vec<u8>,
}

/// Errors returned by [`PublicFirehoseDiffCAR`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum PublicFirehoseDiffCarError {
    #[error("missing block for CID {0}")]
    MissingBlock(Cid),
    #[error("invalid block CID or hash mismatch: {0}")]
    InvalidBlock(String),
    #[error("CAR encoding failed: {0}")]
    Encode(String),
}

/// Clean trait seam for reading blocks from a diff or snapshot CAR.
///
/// Mirrors `PublicRepositoryBlockSource` / `CARReader` from `petrel-repo` so
/// post-merge rebase can plug `petrel-repo`'s CAR reader in directly.
pub trait DiffCarBlockReader: MaybeSend + MaybeSync {
    /// Returns the CAR header roots.
    fn roots(&self) -> &[Cid];

    /// Returns the raw bytes for `cid`, if present.
    fn block_bytes(&self, cid: &Cid) -> Option<&[u8]>;

    /// Iterates over all parsed blocks in archive order.
    fn blocks(&self) -> &[CarBlock];

    /// Async lookup matching `petrel-repo`'s `PublicRepositoryBlockSource` seam.
    fn read_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, RelayVerifierError>> {
        Box::pin(async move { Ok(self.block_bytes(cid).map(<[u8]>::to_vec)) })
    }
}

/// In-memory map of validated content-addressed blocks.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CarBlockMap {
    blocks: BTreeMap<Cid, Vec<u8>>,
}

impl CarBlockMap {
    pub fn new() -> Self {
        Self::default()
    }

    /// Inserts a block after checking that `cid` is a blessed DAG-CBOR SHA-256 CID
    /// whose digest matches `bytes`.
    pub fn insert(&mut self, cid: Cid, bytes: Vec<u8>) -> Result<(), PublicFirehoseDiffCarError> {
        validate_blessed_block(&cid, &bytes)?;
        if let Some(existing) = self.blocks.get(&cid)
            && existing != &bytes
        {
            return Err(PublicFirehoseDiffCarError::InvalidBlock(
                "conflicting block bytes for CID".to_owned(),
            ));
        }
        self.blocks.insert(cid, bytes);
        Ok(())
    }

    pub fn from_blocks(
        blocks: impl IntoIterator<Item = CarBlock>,
    ) -> Result<Self, PublicFirehoseDiffCarError> {
        let mut map = Self::new();
        for block in blocks {
            map.insert(block.cid, block.bytes)?;
        }
        Ok(map)
    }

    pub fn cids(&self) -> impl Iterator<Item = &Cid> {
        self.blocks.keys()
    }

    pub fn get(&self, cid: &Cid) -> Option<&[u8]> {
        self.blocks.get(cid).map(Vec::as_slice)
    }

    pub fn len(&self) -> usize {
        self.blocks.len()
    }

    pub fn is_empty(&self) -> bool {
        self.blocks.is_empty()
    }

    pub fn into_inner(self) -> BTreeMap<Cid, Vec<u8>> {
        self.blocks
    }
}

/// Parsed CARv1 archive in memory with strict canonical varints, canonical header,
/// and per-block SHA-256 digest verification.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedCarArchive {
    roots: Vec<Cid>,
    blocks: Vec<CarBlock>,
    index: BTreeMap<Cid, usize>,
    ignored_frames: usize,
}

impl ParsedCarArchive {
    /// Parses CARv1 bytes strictly. When `reject_foreign_blocks` is false (the ATProto
    /// data-model default), extra roots and non-blessed/foreign CID blocks are ignored
    /// while still requiring valid CAR framing.
    pub fn parse(
        bytes: &[u8],
        max_car_bytes: usize,
        reject_foreign_blocks: bool,
    ) -> Result<Self, RelayVerifierError> {
        if bytes.len() > max_car_bytes {
            return Err(RelayVerifierError::RepositoryCarTooLarge);
        }
        if reject_foreign_blocks {
            return Self::parse_strict_via_repo(bytes, max_car_bytes);
        }
        let mut pos = 0usize;
        let header_len = read_canonical_varint(bytes, &mut pos)?
            .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
        let header_len =
            usize::try_from(header_len).map_err(|_| RelayVerifierError::InvalidRepositoryCar)?;
        let header_end = pos
            .checked_add(header_len)
            .filter(|&end| header_len > 0 && header_len <= 1024 && end <= bytes.len())
            .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
        let header_bytes = &bytes[pos..header_end];
        pos = header_end;

        let roots = parse_car_header(header_bytes, reject_foreign_blocks)?;

        let mut blocks = Vec::new();
        let mut index = BTreeMap::new();
        let mut ignored_frames = 0usize;

        while pos < bytes.len() {
            if blocks.len() + ignored_frames >= DEFAULT_MAX_CAR_BLOCKS {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }
            let frame_len = read_canonical_varint(bytes, &mut pos)?
                .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
            let frame_len =
                usize::try_from(frame_len).map_err(|_| RelayVerifierError::InvalidRepositoryCar)?;
            let frame_end = pos
                .checked_add(frame_len)
                .filter(|&end| frame_len >= 2 && end <= bytes.len())
                .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
            let frame = &bytes[pos..frame_end];
            pos = frame_end;

            let is_blessed_dag_cbor = frame.len() > 36 && frame[..4] == [0x01, 0x71, 0x12, 0x20];
            if !is_blessed_dag_cbor {
                if reject_foreign_blocks {
                    return Err(RelayVerifierError::InvalidRepositoryCar);
                }
                if cid_prefix_len(frame).is_none() {
                    return Err(RelayVerifierError::InvalidRepositoryCar);
                }
                ignored_frames += 1;
                continue;
            }

            let cid = Cid::from_bytes(&frame[..36])
                .map_err(|_| RelayVerifierError::InvalidRepositoryCar)?;
            if cid.blessed_kind() != Some(BlessedKind::DagCbor) || cid.as_bytes() != &frame[..36] {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }
            let body = &frame[36..];
            if body.len() > DEFAULT_MAX_RECORD_BLOCK_BYTES || !cid.matches_content(body) {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }

            if let Some(&existing_idx) = index.get(&cid) {
                let existing: &CarBlock = &blocks[existing_idx];
                if existing.bytes != body {
                    return Err(RelayVerifierError::InvalidRepositoryCar);
                }
            } else {
                index.insert(cid.clone(), blocks.len());
                blocks.push(CarBlock {
                    cid,
                    bytes: body.to_vec(),
                });
            }
        }

        Ok(Self {
            roots,
            blocks,
            index,
            ignored_frames,
        })
    }

    fn parse_strict_via_repo(
        bytes: &[u8],
        max_car_bytes: usize,
    ) -> Result<Self, RelayVerifierError> {
        let mut limits = petrel_repo::RepositoryLimits::network_scale();
        limits.max_import_car_bytes =
            max_car_bytes.min(petrel_repo::RepositoryLimits::MAXIMUM_PERMITTED_IMPORT_CAR_BYTES);
        limits.max_block_count = DEFAULT_MAX_CAR_BLOCKS
            .min(petrel_repo::RepositoryLimits::MAXIMUM_PERMITTED_BLOCK_COUNT);
        limits.max_single_block_bytes = DEFAULT_MAX_RECORD_BLOCK_BYTES;
        limits.max_record_count = limits.max_block_count;
        limits.max_mst_node_count = limits.max_block_count;

        let reader = petrel_repo::car::CARReader::parse_with_limits(bytes, &limits)
            .map_err(|_| RelayVerifierError::InvalidRepositoryCar)?;
        if reader.roots.len() != 1 || reader.roots[0].blessed_kind() != Some(BlessedKind::DagCbor) {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        }
        // Reject CIDv0 or non-blessed DAG-CBOR frames in strict firehose mode.
        if reader.raw_blocks.len() != reader.blocks.len() {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        }
        let mut blocks = Vec::with_capacity(reader.blocks.len());
        let mut index = BTreeMap::new();
        for (cid, body) in reader.blocks {
            if cid.blessed_kind() != Some(BlessedKind::DagCbor) {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }
            index.insert(cid.clone(), blocks.len());
            blocks.push(CarBlock { cid, bytes: body });
        }
        Ok(Self {
            roots: reader.roots,
            blocks,
            index,
            ignored_frames: 0,
        })
    }

    pub fn root_cid(&self) -> &Cid {
        &self.roots[0]
    }

    pub fn ignored_frames(&self) -> usize {
        self.ignored_frames
    }

    pub fn into_block_map(self) -> BTreeMap<Cid, Vec<u8>> {
        self.blocks.into_iter().map(|b| (b.cid, b.bytes)).collect()
    }
}

impl DiffCarBlockReader for ParsedCarArchive {
    fn roots(&self) -> &[Cid] {
        &self.roots
    }

    fn block_bytes(&self, cid: &Cid) -> Option<&[u8]> {
        self.index
            .get(cid)
            .map(|&i| self.blocks[i].bytes.as_slice())
    }

    fn blocks(&self) -> &[CarBlock] {
        &self.blocks
    }
}

/// Deterministic CAR construction for firehose `blocks` payloads.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PublicFirehoseDiffCAR;

impl PublicFirehoseDiffCAR {
    /// Emits the commit block first, then every remaining new block in ascending
    /// CID-string order, rooted at `commit_cid`.
    pub fn build(
        commit_cid: &Cid,
        commit_bytes: &[u8],
        new_blocks: &CarBlockMap,
    ) -> Result<Vec<u8>, PublicFirehoseDiffCarError> {
        let mut remaining: Vec<(&Cid, String)> = new_blocks
            .cids()
            .filter(|cid| *cid != commit_cid)
            .map(|cid| (cid, cid.to_string()))
            .collect();
        remaining.sort_by(|a, b| a.1.cmp(&b.1));

        let mut ordered = Vec::with_capacity(1 + remaining.len());
        ordered.push((commit_cid, commit_bytes));
        for (cid, _) in remaining {
            let bytes = new_blocks
                .get(cid)
                .ok_or_else(|| PublicFirehoseDiffCarError::MissingBlock(cid.clone()))?;
            ordered.push((cid, bytes));
        }

        encode_car(commit_cid, ordered)
    }

    /// Emits a CAR containing only the commit block (used for `#sync`).
    pub fn commit_only(
        commit_cid: &Cid,
        commit_bytes: &[u8],
    ) -> Result<Vec<u8>, PublicFirehoseDiffCarError> {
        encode_car(commit_cid, [(commit_cid, commit_bytes)])
    }

    /// Encodes a CARv1 archive from an explicit root and ordered blocks.
    pub fn encode<'a>(
        root_cid: &Cid,
        blocks: impl IntoIterator<Item = (&'a Cid, &'a [u8])>,
    ) -> Result<Vec<u8>, PublicFirehoseDiffCarError> {
        encode_car(root_cid, blocks)
    }
}

fn encode_car<'a>(
    root_cid: &Cid,
    blocks: impl IntoIterator<Item = (&'a Cid, &'a [u8])>,
) -> Result<Vec<u8>, PublicFirehoseDiffCarError> {
    if root_cid.blessed_kind() != Some(BlessedKind::DagCbor) {
        return Err(PublicFirehoseDiffCarError::InvalidBlock(
            "root CID must be blessed dag-cbor".to_owned(),
        ));
    }

    let mut repo_blocks = Vec::new();
    for (cid, bytes) in blocks {
        validate_blessed_block(cid, bytes)?;
        repo_blocks.push(petrel_repo::block_store::RepositoryBlock::new(
            cid.clone(),
            bytes.to_vec(),
        ));
    }
    petrel_repo::car::PublicRepositoryCAR::write(std::slice::from_ref(root_cid), &repo_blocks)
        .map_err(|e| PublicFirehoseDiffCarError::Encode(e.to_string()))
}

fn validate_blessed_block(cid: &Cid, bytes: &[u8]) -> Result<(), PublicFirehoseDiffCarError> {
    if cid.blessed_kind() != Some(BlessedKind::DagCbor) {
        return Err(PublicFirehoseDiffCarError::InvalidBlock(format!(
            "unblessed block CID {cid}"
        )));
    }
    if !cid.matches_content(bytes) {
        return Err(PublicFirehoseDiffCarError::InvalidBlock(format!(
            "block digest mismatch for {cid}"
        )));
    }
    Ok(())
}

fn read_canonical_varint(bytes: &[u8], pos: &mut usize) -> Result<Option<u64>, RelayVerifierError> {
    if *pos >= bytes.len() {
        return Ok(None);
    }
    let mut value = 0u64;
    for shift_idx in 0..10 {
        let &byte = bytes
            .get(*pos)
            .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
        *pos += 1;
        let payload = u64::from(byte & 0x7f);
        if shift_idx == 9 && payload > 1 {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        }
        value |= payload << (shift_idx * 7);
        if byte & 0x80 == 0 {
            if shift_idx != 0 && payload == 0 {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }
            return Ok(Some(value));
        }
    }
    Err(RelayVerifierError::InvalidRepositoryCar)
}

fn parse_car_header(
    header_bytes: &[u8],
    reject_extra_roots: bool,
) -> Result<Vec<Cid>, RelayVerifierError> {
    let val =
        dagcbor::decode(header_bytes).map_err(|_| RelayVerifierError::InvalidRepositoryCar)?;
    let Value::Object(mut map) = val else {
        return Err(RelayVerifierError::InvalidRepositoryCar);
    };
    if map.len() != 2 {
        return Err(RelayVerifierError::InvalidRepositoryCar);
    }
    if map.remove("version") != Some(Value::Integer(1)) {
        return Err(RelayVerifierError::InvalidRepositoryCar);
    }
    let Some(Value::Array(root_vals)) = map.remove("roots") else {
        return Err(RelayVerifierError::InvalidRepositoryCar);
    };
    if root_vals.is_empty() || (reject_extra_roots && root_vals.len() != 1) {
        return Err(RelayVerifierError::InvalidRepositoryCar);
    }
    let mut roots = Vec::with_capacity(root_vals.len());
    for (idx, rv) in root_vals.into_iter().enumerate() {
        let Value::Link(cid) = rv else {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        };
        if idx == 0 && cid.blessed_kind() != Some(BlessedKind::DagCbor) {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        }
        roots.push(cid);
    }
    Ok(roots)
}

fn cid_prefix_len(frame: &[u8]) -> Option<usize> {
    if frame.len() >= 34 && frame[0] == 0x12 && frame[1] == 0x20 {
        return Some(34);
    }
    let mut pos = 0usize;
    let take_varint = |p: &mut usize| -> Option<u64> {
        let mut val = 0u64;
        let mut shift = 0u32;
        while *p < frame.len() && shift < 63 {
            let b = frame[*p];
            *p += 1;
            val |= u64::from(b & 0x7f) << shift;
            if b & 0x80 == 0 {
                return Some(val);
            }
            shift += 7;
        }
        None
    };
    if take_varint(&mut pos)? != 1 {
        return None;
    }
    let _codec = take_varint(&mut pos)?;
    let _hash = take_varint(&mut pos)?;
    let digest_len = take_varint(&mut pos)?;
    if digest_len == 0 || digest_len > 1024 {
        return None;
    }
    let digest_len = usize::try_from(digest_len).ok()?;
    if frame.len() - pos < digest_len {
        return None;
    }
    Some(pos + digest_len)
}
