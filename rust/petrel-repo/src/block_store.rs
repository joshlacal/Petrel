use std::collections::{BTreeMap, HashMap};
use std::fmt;
use std::sync::Arc;

use async_lock::RwLock;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::Cid;

use crate::error::BlockStoreError;

/// A verified repository block (`PublicRepositoryBlock`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepositoryBlock {
    pub cid: Cid,
    pub bytes: Vec<u8>,
}

impl RepositoryBlock {
    pub fn new(cid: Cid, bytes: Vec<u8>) -> Self {
        Self { cid, bytes }
    }
}

/// Ordered map of CID -> bytes for small collections (`PublicRepositoryBlockMap`).
pub type BlockMap = BTreeMap<Cid, Vec<u8>>;

/// Read-only block lookup interface (`PublicRepositoryBlockSource`).
pub trait BlockSource: MaybeSend + MaybeSync + fmt::Debug {
    fn get_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, BlockStoreError>>;

    fn contains_block<'a>(&'a self, cid: &'a Cid) -> BoxFuture<'a, Result<bool, BlockStoreError>> {
        Box::pin(async move { Ok(self.get_block(cid).await?.is_some()) })
    }
}

/// Mutable verified repository block store (`RepositoryBlockStore`).
pub trait BlockStore: BlockSource {
    /// Stores `bytes` for `cid`. Implementations should verify `cid` matches
    /// `bytes` (for SHA-256 CIDs) and enforce `max_block_count` /
    /// `max_single_block_bytes` ceilings when configured.
    fn put_block<'a>(
        &'a self,
        cid: &'a Cid,
        bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<(), BlockStoreError>>;

    /// Stores a batch of blocks atomically or sequentially.
    fn put_blocks<'a>(
        &'a self,
        blocks: &'a [RepositoryBlock],
    ) -> BoxFuture<'a, Result<(), BlockStoreError>> {
        Box::pin(async move {
            for block in blocks {
                self.put_block(&block.cid, &block.bytes).await?;
            }
            Ok(())
        })
    }

    /// Deletes a block by CID if present (used when pruning or testing).
    fn delete_block<'a>(&'a self, cid: &'a Cid) -> BoxFuture<'a, Result<bool, BlockStoreError>>;

    /// Number of distinct blocks currently stored.
    fn len(&self) -> BoxFuture<'_, Result<usize, BlockStoreError>>;

    /// Returns `true` when zero blocks are stored.
    fn is_empty(&self) -> BoxFuture<'_, Result<bool, BlockStoreError>> {
        Box::pin(async move { Ok(self.len().await? == 0) })
    }

    /// Total payload bytes stored across all blocks.
    fn total_bytes(&self) -> BoxFuture<'_, Result<usize, BlockStoreError>>;

    /// Lists all CIDs stored (in deterministic order where practical).
    fn all_cids(&self) -> BoxFuture<'_, Result<Vec<Cid>, BlockStoreError>>;
}

/// Thread-safe in-memory implementation of [`BlockStore`].
#[derive(Debug, Clone)]
pub struct InMemoryBlockStore {
    inner: Arc<RwLock<InMemoryState>>,
    max_block_count: Option<usize>,
    max_single_block_bytes: Option<usize>,
}

#[derive(Debug, Default)]
struct InMemoryState {
    blocks: HashMap<Cid, Vec<u8>>,
    total_bytes: usize,
}

impl InMemoryBlockStore {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(RwLock::new(InMemoryState::default())),
            max_block_count: None,
            max_single_block_bytes: None,
        }
    }

    pub fn with_limits(max_block_count: usize, max_single_block_bytes: usize) -> Self {
        Self {
            inner: Arc::new(RwLock::new(InMemoryState::default())),
            max_block_count: Some(max_block_count),
            max_single_block_bytes: Some(max_single_block_bytes),
        }
    }

    pub fn from_blocks<I>(blocks: I) -> Result<Self, BlockStoreError>
    where
        I: IntoIterator<Item = (Cid, Vec<u8>)>,
    {
        let mut state = InMemoryState::default();
        for (cid, bytes) in blocks {
            verify_cid_if_sha256(&cid, &bytes)?;
            if let Some(existing) = state.blocks.get(&cid) {
                if existing != &bytes {
                    return Err(BlockStoreError::ConflictingBlock(cid));
                }
                continue;
            }
            state.total_bytes = state.total_bytes.saturating_add(bytes.len());
            state.blocks.insert(cid, bytes);
        }
        Ok(Self {
            inner: Arc::new(RwLock::new(state)),
            max_block_count: None,
            max_single_block_bytes: None,
        })
    }

    /// Synchronous snapshot clone of all stored blocks for callers already holding
    /// an in-memory store.
    pub async fn snapshot(&self) -> BlockMap {
        let guard = self.inner.read().await;
        guard
            .blocks
            .iter()
            .map(|(cid, bytes)| (cid.clone(), bytes.clone()))
            .collect()
    }
}

impl Default for InMemoryBlockStore {
    fn default() -> Self {
        Self::new()
    }
}

impl BlockSource for InMemoryBlockStore {
    fn get_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, BlockStoreError>> {
        Box::pin(async move {
            let guard = self.inner.read().await;
            Ok(guard.blocks.get(cid).cloned())
        })
    }

    fn contains_block<'a>(&'a self, cid: &'a Cid) -> BoxFuture<'a, Result<bool, BlockStoreError>> {
        Box::pin(async move {
            let guard = self.inner.read().await;
            Ok(guard.blocks.contains_key(cid))
        })
    }
}

impl BlockStore for InMemoryBlockStore {
    fn put_block<'a>(
        &'a self,
        cid: &'a Cid,
        bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<(), BlockStoreError>> {
        Box::pin(async move {
            if let Some(max) = self.max_single_block_bytes
                && bytes.len() > max
            {
                return Err(BlockStoreError::BlockTooLarge {
                    len: bytes.len(),
                    max,
                });
            }
            verify_cid_if_sha256(cid, bytes)?;
            let mut guard = self.inner.write().await;
            if let Some(existing) = guard.blocks.get(cid) {
                if existing.as_slice() != bytes {
                    return Err(BlockStoreError::ConflictingBlock(cid.clone()));
                }
                return Ok(());
            }
            if let Some(max_count) = self.max_block_count
                && guard.blocks.len() >= max_count
            {
                return Err(BlockStoreError::TooManyBlocks {
                    count: guard.blocks.len() + 1,
                    limit: max_count,
                });
            }
            guard.total_bytes = guard.total_bytes.saturating_add(bytes.len());
            guard.blocks.insert(cid.clone(), bytes.to_vec());
            Ok(())
        })
    }

    fn delete_block<'a>(&'a self, cid: &'a Cid) -> BoxFuture<'a, Result<bool, BlockStoreError>> {
        Box::pin(async move {
            let mut guard = self.inner.write().await;
            if let Some(removed) = guard.blocks.remove(cid) {
                guard.total_bytes = guard.total_bytes.saturating_sub(removed.len());
                Ok(true)
            } else {
                Ok(false)
            }
        })
    }

    fn len(&self) -> BoxFuture<'_, Result<usize, BlockStoreError>> {
        Box::pin(async move {
            let guard = self.inner.read().await;
            Ok(guard.blocks.len())
        })
    }

    fn total_bytes(&self) -> BoxFuture<'_, Result<usize, BlockStoreError>> {
        Box::pin(async move {
            let guard = self.inner.read().await;
            Ok(guard.total_bytes)
        })
    }

    fn all_cids(&self) -> BoxFuture<'_, Result<Vec<Cid>, BlockStoreError>> {
        Box::pin(async move {
            let guard = self.inner.read().await;
            let mut cids: Vec<Cid> = guard.blocks.keys().cloned().collect();
            cids.sort();
            Ok(cids)
        })
    }
}

pub(crate) fn verify_cid_if_sha256(cid: &Cid, bytes: &[u8]) -> Result<(), BlockStoreError> {
    if cid.hash_code() == 0x12 && !cid.matches_content(bytes) {
        return Err(BlockStoreError::HashMismatch(cid.clone()));
    }
    Ok(())
}

#[cfg(not(target_arch = "wasm32"))]
mod file_store {
    use std::collections::{HashMap, HashSet};
    use std::fs::{File, OpenOptions};
    use std::io::{BufReader, Read, Seek, SeekFrom, Write};
    use std::path::{Path, PathBuf};
    use std::sync::Arc;

    use async_lock::RwLock;
    use petrel::rt::BoxFuture;
    use petrel_core::Cid;

    use crate::car::varint;
    use crate::error::BlockStoreError;

    use super::{BlockSource, BlockStore, verify_cid_if_sha256};

    const WRITE_BUFFER_THRESHOLD: usize = 1 << 20;

    #[derive(Debug, Clone, Copy)]
    struct DiskEntry {
        payload_offset: u64,
        payload_len: usize,
    }

    #[derive(Debug)]
    struct FileState {
        path: PathBuf,
        reader: File,
        writer: File,
        index: HashMap<Cid, DiskEntry>,
        disk_bytes: usize,
        pending_puts: HashMap<Cid, Vec<u8>>,
        pending_put_order: Vec<Cid>,
        pending_bytes: usize,
        pending_deletes: HashSet<Cid>,
        write_buffer: Vec<u8>,
        file_len: u64,
    }

    impl FileState {
        fn stage_frame_bytes(&self) -> usize {
            let delete_bytes: usize = self
                .pending_deletes
                .iter()
                .map(|c| 1 + 9 + c.as_bytes().len())
                .sum();
            self.pending_bytes
                .saturating_add(self.pending_puts.len() * 45)
                .saturating_add(delete_bytes)
        }

        fn flush(&mut self) -> Result<(), BlockStoreError> {
            if self.pending_deletes.is_empty() && self.pending_put_order.is_empty() {
                return Ok(());
            }
            self.write_buffer.clear();

            // Persist tombstones (`varint(0) || varint(cid_len) || cid_bytes`) first so any
            // subsequent put for the same CID supersedes the tombstone on replay.
            let mut deleted_cids: Vec<Cid> = self.pending_deletes.drain().collect();
            deleted_cids.sort();
            for cid in deleted_cids {
                let cid_bytes = cid.as_bytes();
                let mut header = [0_u8; 9];
                let hlen = varint::encode_into(cid_bytes.len() as u64, &mut header)
                    .map_err(|err| BlockStoreError::CorruptStore(err.to_string()))?;
                self.write_buffer.push(0x00);
                self.write_buffer.extend_from_slice(&header[..hlen]);
                self.write_buffer.extend_from_slice(cid_bytes);
            }

            let put_order = std::mem::take(&mut self.pending_put_order);
            let mut written_entries: Vec<(Cid, DiskEntry)> = Vec::with_capacity(put_order.len());
            for cid in put_order {
                let Some(bytes) = self.pending_puts.remove(&cid) else {
                    continue;
                };
                self.pending_bytes = self.pending_bytes.saturating_sub(bytes.len());
                let cid_bytes = cid.as_bytes();
                let frame_len = cid_bytes.len() + bytes.len();
                let mut header = [0_u8; 9];
                let header_len = varint::encode_into(frame_len as u64, &mut header)
                    .map_err(|err| BlockStoreError::CorruptStore(err.to_string()))?;

                let payload_offset = self
                    .file_len
                    .saturating_add(self.write_buffer.len() as u64)
                    .saturating_add(header_len as u64)
                    .saturating_add(cid_bytes.len() as u64);

                self.write_buffer.extend_from_slice(&header[..header_len]);
                self.write_buffer.extend_from_slice(cid_bytes);
                self.write_buffer.extend_from_slice(&bytes);
                written_entries.push((
                    cid,
                    DiskEntry {
                        payload_offset,
                        payload_len: bytes.len(),
                    },
                ));
            }

            if self.write_buffer.is_empty() {
                return Ok(());
            }

            self.writer
                .write_all(&self.write_buffer)
                .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            self.writer
                .flush()
                .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            self.file_len = self.file_len.saturating_add(self.write_buffer.len() as u64);
            self.write_buffer.clear();

            for (cid, entry) in written_entries {
                if self.index.insert(cid, entry).is_none() {
                    self.disk_bytes = self.disk_bytes.saturating_add(entry.payload_len);
                }
            }
            Ok(())
        }
    }

    /// Disk-backed append-only CAR-frame block store matching
    /// `FileRepositoryBlockStore` in Swift.
    ///
    /// Live frames are stored as `varint(cid_len + block_len) || cid_bytes || block_bytes`;
    /// persisted deletions are appended as `0x00 || varint(cid_len) || cid_bytes` tombstones.
    #[derive(Debug, Clone)]
    pub struct FileBlockStore {
        state: Arc<RwLock<FileState>>,
        max_block_count: Option<usize>,
        max_single_block_bytes: Option<usize>,
    }

    impl FileBlockStore {
        /// Opens or creates a disk-backed block store at `path`, scanning and
        /// hash-verifying any existing frames.
        pub fn open(path: impl AsRef<Path>) -> Result<Self, BlockStoreError> {
            Self::open_with_limits(path, None, None)
        }

        pub fn open_with_limits(
            path: impl AsRef<Path>,
            max_block_count: Option<usize>,
            max_single_block_bytes: Option<usize>,
        ) -> Result<Self, BlockStoreError> {
            let path = path.as_ref().to_path_buf();
            if let Some(parent) = path.parent()
                && !parent.as_os_str().is_empty()
            {
                std::fs::create_dir_all(parent)
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            }
            // Touch/open append handle and read handle.
            let writer = OpenOptions::new()
                .create(true)
                .append(true)
                .open(&path)
                .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            let mut reader =
                File::open(&path).map_err(|err| BlockStoreError::Io(err.to_string()))?;
            let file_len = reader
                .metadata()
                .map_err(|err| BlockStoreError::Io(err.to_string()))?
                .len();

            let (index, disk_bytes) = scan_existing_frames(
                &mut reader,
                file_len,
                max_block_count,
                max_single_block_bytes,
            )?;

            Ok(Self {
                state: Arc::new(RwLock::new(FileState {
                    path,
                    reader,
                    writer,
                    index,
                    disk_bytes,
                    pending_puts: HashMap::new(),
                    pending_put_order: Vec::new(),
                    pending_bytes: 0,
                    pending_deletes: HashSet::new(),
                    write_buffer: Vec::new(),
                    file_len,
                })),
                max_block_count,
                max_single_block_bytes,
            })
        }

        /// Flushes any buffered appends and tombstones to disk and syncs the file descriptor.
        pub async fn synchronize(&self) -> Result<(), BlockStoreError> {
            let mut guard = self.state.write().await;
            guard.flush()?;
            guard
                .writer
                .sync_all()
                .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            Ok(())
        }

        pub async fn path(&self) -> PathBuf {
            self.state.read().await.path.clone()
        }
    }

    fn scan_existing_frames(
        file: &mut File,
        file_len: u64,
        max_block_count: Option<usize>,
        max_single_block_bytes: Option<usize>,
    ) -> Result<(HashMap<Cid, DiskEntry>, usize), BlockStoreError> {
        file.seek(SeekFrom::Start(0))
            .map_err(|err| BlockStoreError::Io(err.to_string()))?;
        let mut reader = BufReader::new(file);
        let mut offset: u64 = 0;
        let mut index: HashMap<Cid, DiskEntry> = HashMap::new();
        let mut total_bytes: usize = 0;

        while offset < file_len {
            let (frame_len_u64, varint_bytes) = read_varint_from_reader(&mut reader)?;
            offset = offset.saturating_add(varint_bytes as u64);

            if frame_len_u64 == 0 {
                // Deletion tombstone: `0x00 || varint(cid_len) || cid_bytes`
                let (tombstone_bytes_u64, cid_varint_bytes) = read_varint_from_reader(&mut reader)?;
                offset = offset.saturating_add(cid_varint_bytes as u64);
                let tombstone_cid_len = usize::try_from(tombstone_bytes_u64).map_err(|_| {
                    BlockStoreError::CorruptStore("tombstone CID length overflow".into())
                })?;
                if tombstone_cid_len == 0
                    || offset.saturating_add(tombstone_cid_len as u64) > file_len
                {
                    return Err(BlockStoreError::CorruptStore(
                        "truncated deletion tombstone in block store".into(),
                    ));
                }
                let mut cid_buf = vec![0_u8; tombstone_cid_len];
                reader
                    .read_exact(&mut cid_buf)
                    .map_err(|err| BlockStoreError::CorruptStore(err.to_string()))?;
                let cid = Cid::from_bytes(&cid_buf).map_err(|err| {
                    BlockStoreError::CorruptStore(format!("invalid tombstone CID: {err}"))
                })?;
                if let Some(removed) = index.remove(&cid) {
                    total_bytes = total_bytes.saturating_sub(removed.payload_len);
                }
                offset = offset.saturating_add(tombstone_cid_len as u64);
                continue;
            }

            let frame_len = usize::try_from(frame_len_u64)
                .map_err(|_| BlockStoreError::CorruptStore("frame length overflow".into()))?;
            if offset.saturating_add(frame_len as u64) > file_len {
                return Err(BlockStoreError::CorruptStore(
                    "truncated frame in block store".into(),
                ));
            }

            let mut frame = vec![0_u8; frame_len];
            reader
                .read_exact(&mut frame)
                .map_err(|err| BlockStoreError::Io(err.to_string()))?;

            let cid_len = crate::car::reader::cid_prefix_len(&frame)
                .map_err(|err| BlockStoreError::CorruptStore(format!("invalid CID: {err}")))?;
            let cid = Cid::from_bytes(&frame[..cid_len])
                .map_err(|err| BlockStoreError::CorruptStore(format!("invalid CID: {err}")))?;
            let payload = &frame[cid_len..];
            if let Some(max) = max_single_block_bytes
                && payload.len() > max
            {
                return Err(BlockStoreError::BlockTooLarge {
                    len: payload.len(),
                    max,
                });
            }
            verify_cid_if_sha256(&cid, payload)?;

            if let Some(existing) = index.get(&cid).copied() {
                let mut existing_bytes = vec![0_u8; existing.payload_len];
                let inner = reader.get_mut();
                let saved = inner
                    .stream_position()
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                inner
                    .seek(SeekFrom::Start(existing.payload_offset))
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                inner
                    .read_exact(&mut existing_bytes)
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                inner
                    .seek(SeekFrom::Start(saved))
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                if existing_bytes.as_slice() != payload {
                    return Err(BlockStoreError::ConflictingBlock(cid));
                }
            } else {
                if let Some(limit) = max_block_count
                    && index.len() >= limit
                {
                    return Err(BlockStoreError::TooManyBlocks {
                        count: index.len() + 1,
                        limit,
                    });
                }
                index.insert(
                    cid,
                    DiskEntry {
                        payload_offset: offset.saturating_add(cid_len as u64),
                        payload_len: payload.len(),
                    },
                );
                total_bytes = total_bytes.saturating_add(payload.len());
            }

            offset = offset.saturating_add(frame_len as u64);
        }

        Ok((index, total_bytes))
    }

    fn read_varint_from_reader<R: Read>(reader: &mut R) -> Result<(u64, usize), BlockStoreError> {
        let mut buf = [0_u8; 9];
        for idx in 0..9 {
            let mut b = [0_u8; 1];
            reader
                .read_exact(&mut b)
                .map_err(|err| BlockStoreError::CorruptStore(err.to_string()))?;
            buf[idx] = b[0];
            if b[0] & 0x80 == 0 {
                let (val, consumed) = varint::decode(&buf[..=idx])
                    .map_err(|err| BlockStoreError::CorruptStore(err.to_string()))?;
                return Ok((val, consumed));
            }
        }
        Err(BlockStoreError::CorruptStore(
            "varint exceeds 9 bytes".into(),
        ))
    }

    impl BlockSource for FileBlockStore {
        fn get_block<'a>(
            &'a self,
            cid: &'a Cid,
        ) -> BoxFuture<'a, Result<Option<Vec<u8>>, BlockStoreError>> {
            Box::pin(async move {
                let mut guard = self.state.write().await;
                if let Some(pending) = guard.pending_puts.get(cid) {
                    return Ok(Some(pending.clone()));
                }
                let Some(entry) = guard.index.get(cid).copied() else {
                    return Ok(None);
                };
                guard
                    .reader
                    .seek(SeekFrom::Start(entry.payload_offset))
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                let mut buf = vec![0_u8; entry.payload_len];
                guard
                    .reader
                    .read_exact(&mut buf)
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                Ok(Some(buf))
            })
        }

        fn contains_block<'a>(
            &'a self,
            cid: &'a Cid,
        ) -> BoxFuture<'a, Result<bool, BlockStoreError>> {
            Box::pin(async move {
                let guard = self.state.read().await;
                Ok(guard.pending_puts.contains_key(cid) || guard.index.contains_key(cid))
            })
        }
    }

    impl BlockStore for FileBlockStore {
        fn put_block<'a>(
            &'a self,
            cid: &'a Cid,
            bytes: &'a [u8],
        ) -> BoxFuture<'a, Result<(), BlockStoreError>> {
            Box::pin(async move {
                if let Some(max) = self.max_single_block_bytes
                    && bytes.len() > max
                {
                    return Err(BlockStoreError::BlockTooLarge {
                        len: bytes.len(),
                        max,
                    });
                }
                verify_cid_if_sha256(cid, bytes)?;
                let mut guard = self.state.write().await;
                if let Some(pending) = guard.pending_puts.get(cid) {
                    if pending.as_slice() != bytes {
                        return Err(BlockStoreError::ConflictingBlock(cid.clone()));
                    }
                    return Ok(());
                }
                if let Some(existing) = guard.index.get(cid).copied() {
                    let mut existing_bytes = vec![0_u8; existing.payload_len];
                    guard
                        .reader
                        .seek(SeekFrom::Start(existing.payload_offset))
                        .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                    guard
                        .reader
                        .read_exact(&mut existing_bytes)
                        .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                    if existing_bytes.as_slice() != bytes {
                        return Err(BlockStoreError::ConflictingBlock(cid.clone()));
                    }
                    return Ok(());
                }

                let live_count = guard.index.len() + guard.pending_puts.len();
                if let Some(max_count) = self.max_block_count
                    && live_count >= max_count
                {
                    return Err(BlockStoreError::TooManyBlocks {
                        count: live_count + 1,
                        limit: max_count,
                    });
                }

                guard.pending_bytes = guard.pending_bytes.saturating_add(bytes.len());
                guard.pending_puts.insert(cid.clone(), bytes.to_vec());
                guard.pending_put_order.push(cid.clone());

                if guard.stage_frame_bytes() >= WRITE_BUFFER_THRESHOLD {
                    guard.flush()?;
                }
                Ok(())
            })
        }

        fn delete_block<'a>(
            &'a self,
            cid: &'a Cid,
        ) -> BoxFuture<'a, Result<bool, BlockStoreError>> {
            Box::pin(async move {
                let mut guard = self.state.write().await;
                if let Some(pending) = guard.pending_puts.remove(cid) {
                    guard.pending_bytes = guard.pending_bytes.saturating_sub(pending.len());
                    return Ok(true);
                }
                if let Some(removed) = guard.index.remove(cid) {
                    guard.disk_bytes = guard.disk_bytes.saturating_sub(removed.payload_len);
                    guard.pending_deletes.insert(cid.clone());
                    Ok(true)
                } else {
                    Ok(false)
                }
            })
        }

        fn len(&self) -> BoxFuture<'_, Result<usize, BlockStoreError>> {
            Box::pin(async move {
                let guard = self.state.read().await;
                Ok(guard.index.len() + guard.pending_puts.len())
            })
        }

        fn total_bytes(&self) -> BoxFuture<'_, Result<usize, BlockStoreError>> {
            Box::pin(async move {
                let guard = self.state.read().await;
                Ok(guard.disk_bytes.saturating_add(guard.pending_bytes))
            })
        }

        fn all_cids(&self) -> BoxFuture<'_, Result<Vec<Cid>, BlockStoreError>> {
            Box::pin(async move {
                let guard = self.state.read().await;
                let mut cids: Vec<Cid> = guard
                    .index
                    .keys()
                    .chain(guard.pending_puts.keys())
                    .cloned()
                    .collect();
                cids.sort();
                cids.dedup();
                Ok(cids)
            })
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub use file_store::FileBlockStore;
