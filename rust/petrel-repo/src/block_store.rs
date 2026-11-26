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

    /// Flushes any buffered block writes or deletions to durable storage (no-op for in-memory stores).
    fn flush(&self) -> BoxFuture<'_, Result<(), BlockStoreError>> {
        Box::pin(async { Ok(()) })
    }

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
            verify_cid_matches_content(&cid, &bytes)?;
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
            verify_cid_matches_content(cid, bytes)?;
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

pub(crate) fn verify_cid_matches_content(cid: &Cid, bytes: &[u8]) -> Result<(), BlockStoreError> {
    if !cid.matches_content(bytes) {
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

    use super::{BlockSource, BlockStore, verify_cid_matches_content};

    const WRITE_BUFFER_THRESHOLD: usize = 1 << 20;

    trait FileStoreWriter: Write + Send + Sync + std::fmt::Debug {
        fn sync_all_data(&self) -> std::io::Result<()>;
        fn current_len(&self) -> std::io::Result<u64>;
        fn set_file_len(&self, len: u64) -> std::io::Result<()>;
    }

    impl FileStoreWriter for File {
        fn sync_all_data(&self) -> std::io::Result<()> {
            self.sync_all()
        }

        fn current_len(&self) -> std::io::Result<u64> {
            Ok(self.metadata()?.len())
        }

        fn set_file_len(&self, len: u64) -> std::io::Result<()> {
            self.set_len(len)
        }
    }

    #[derive(Debug, Clone, Copy)]
    struct DiskEntry {
        payload_offset: u64,
        payload_len: usize,
    }

    #[derive(Debug)]
    struct FileState {
        path: PathBuf,
        reader: File,
        writer: Box<dyn FileStoreWriter>,
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
            let mut deleted_cids: Vec<&Cid> = self.pending_deletes.iter().collect();
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

            let mut written_entries: Vec<(Cid, DiskEntry)> =
                Vec::with_capacity(self.pending_put_order.len());
            let mut staged_put_bytes = 0_usize;
            for cid in &self.pending_put_order {
                let Some(bytes) = self.pending_puts.get(cid) else {
                    continue;
                };
                staged_put_bytes = staged_put_bytes.saturating_add(bytes.len());
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
                self.write_buffer.extend_from_slice(bytes);
                written_entries.push((
                    cid.clone(),
                    DiskEntry {
                        payload_offset,
                        payload_len: bytes.len(),
                    },
                ));
            }

            if self.write_buffer.is_empty() {
                self.pending_put_order.clear();
                return Ok(());
            }

            let disk_len = self
                .writer
                .current_len()
                .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            if disk_len != self.file_len {
                self.writer
                    .set_file_len(self.file_len)
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            }

            if let Err(err) = self
                .writer
                .write_all(&self.write_buffer)
                .and_then(|()| self.writer.flush())
                .and_then(|()| self.writer.sync_all_data())
            {
                // Roll back any partially appended frame bytes so retry and reopen stay clean.
                let _ = self.writer.set_file_len(self.file_len);
                self.write_buffer.clear();
                return Err(BlockStoreError::Io(err.to_string()));
            }

            self.file_len = self.file_len.saturating_add(self.write_buffer.len() as u64);
            self.write_buffer.clear();
            self.pending_deletes.clear();
            self.pending_put_order.clear();
            self.pending_puts.clear();
            self.pending_bytes = self.pending_bytes.saturating_sub(staged_put_bytes);

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

            let (index, disk_bytes, valid_file_len) = scan_existing_frames(
                &mut reader,
                file_len,
                max_block_count,
                max_single_block_bytes,
            )?;
            if valid_file_len < file_len {
                writer
                    .set_len(valid_file_len)
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
                writer
                    .sync_all()
                    .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            }

            Ok(Self {
                state: Arc::new(RwLock::new(FileState {
                    path,
                    reader,
                    writer: Box::new(writer),
                    index,
                    disk_bytes,
                    pending_puts: HashMap::new(),
                    pending_put_order: Vec::new(),
                    pending_bytes: 0,
                    pending_deletes: HashSet::new(),
                    write_buffer: Vec::new(),
                    file_len: valid_file_len,
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
                .sync_all_data()
                .map_err(|err| BlockStoreError::Io(err.to_string()))?;
            Ok(())
        }

        pub async fn path(&self) -> PathBuf {
            self.state.read().await.path.clone()
        }
    }

    #[allow(clippy::too_many_lines)]
    fn scan_existing_frames(
        file: &mut File,
        file_len: u64,
        max_block_count: Option<usize>,
        max_single_block_bytes: Option<usize>,
    ) -> Result<(HashMap<Cid, DiskEntry>, usize, u64), BlockStoreError> {
        file.seek(SeekFrom::Start(0))
            .map_err(|err| BlockStoreError::Io(err.to_string()))?;
        let mut reader = BufReader::new(file);
        let mut offset: u64 = 0;
        let mut index: HashMap<Cid, DiskEntry> = HashMap::new();
        let mut total_bytes: usize = 0;

        while offset < file_len {
            let frame_start = offset;
            let Some((frame_len_u64, varint_bytes)) = try_read_varint_from_reader(&mut reader)?
            else {
                // Torn trailing varint at EOF; truncate back to the last complete frame.
                return Ok((index, total_bytes, frame_start));
            };
            offset = offset.saturating_add(varint_bytes as u64);

            if frame_len_u64 == 0 {
                // Deletion tombstone: `0x00 || varint(cid_len) || cid_bytes`
                let Some((tombstone_bytes_u64, cid_varint_bytes)) =
                    try_read_varint_from_reader(&mut reader)?
                else {
                    return Ok((index, total_bytes, frame_start));
                };
                offset = offset.saturating_add(cid_varint_bytes as u64);
                let tombstone_cid_len = usize::try_from(tombstone_bytes_u64).map_err(|_| {
                    BlockStoreError::CorruptStore("tombstone CID length overflow".into())
                })?;
                if tombstone_cid_len == 0 {
                    return Err(BlockStoreError::CorruptStore(
                        "zero-length deletion tombstone CID in block store".into(),
                    ));
                }
                if offset.saturating_add(tombstone_cid_len as u64) > file_len {
                    // Torn trailing tombstone frame at EOF.
                    return Ok((index, total_bytes, frame_start));
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
                // Torn trailing block frame at EOF.
                return Ok((index, total_bytes, frame_start));
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
            verify_cid_matches_content(&cid, payload)?;

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

        Ok((index, total_bytes, offset))
    }

    fn try_read_varint_from_reader<R: Read>(
        reader: &mut R,
    ) -> Result<Option<(u64, usize)>, BlockStoreError> {
        let mut buf = [0_u8; 9];
        for idx in 0..9 {
            let mut b = [0_u8; 1];
            match reader.read_exact(&mut b) {
                Ok(()) => {}
                Err(err) if err.kind() == std::io::ErrorKind::UnexpectedEof => {
                    return Ok(None);
                }
                Err(err) => return Err(BlockStoreError::Io(err.to_string())),
            }
            buf[idx] = b[0];
            if b[0] & 0x80 == 0 {
                let (val, consumed) = varint::decode(&buf[..=idx])
                    .map_err(|err| BlockStoreError::CorruptStore(err.to_string()))?;
                return Ok(Some((val, consumed)));
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
                verify_cid_matches_content(cid, bytes)?;
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

        fn flush(&self) -> BoxFuture<'_, Result<(), BlockStoreError>> {
            Box::pin(async move { self.synchronize().await })
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

    #[cfg(test)]
    mod tests {
        use std::sync::atomic::{AtomicBool, Ordering};

        use super::*;

        #[derive(Debug)]
        struct PartialFailWriter {
            inner: File,
            fail_next: Arc<AtomicBool>,
        }

        impl Write for PartialFailWriter {
            fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
                if self.fail_next.load(Ordering::SeqCst) {
                    let partial = (buf.len() / 2).max(1).min(buf.len());
                    self.inner.write_all(&buf[..partial])?;
                    return Err(std::io::Error::other(
                        "simulated disk full after partial write",
                    ));
                }
                self.inner.write(buf)
            }

            fn flush(&mut self) -> std::io::Result<()> {
                if self.fail_next.load(Ordering::SeqCst) {
                    return Err(std::io::Error::other("simulated flush failure"));
                }
                self.inner.flush()
            }
        }

        impl FileStoreWriter for PartialFailWriter {
            fn sync_all_data(&self) -> std::io::Result<()> {
                self.inner.sync_all()
            }

            fn current_len(&self) -> std::io::Result<u64> {
                Ok(self.inner.metadata()?.len())
            }

            fn set_file_len(&self, len: u64) -> std::io::Result<()> {
                self.inner.set_len(len)
            }
        }

        #[tokio::test]
        async fn flush_failure_retains_pending_ops_truncates_partial_tail_and_retries() {
            let dir = tempfile::tempdir().unwrap();
            let store_path = dir.path().join("blocks.carframes");
            let store = FileBlockStore::open(&store_path).unwrap();

            let blk_a = b"\xa1\x61a\x01".to_vec();
            let cid_a = Cid::for_dag_cbor(&blk_a);
            let blk_b = b"\xa1\x61b\x02".to_vec();
            let cid_b = Cid::for_dag_cbor(&blk_b);

            store.put_block(&cid_a, &blk_a).await.unwrap();
            store.synchronize().await.unwrap();
            let baseline_len = std::fs::metadata(&store_path).unwrap().len();

            // Inject partial-write failure, then delete A and put B.
            let fail_flag = Arc::new(AtomicBool::new(true));
            {
                let mut guard = store.state.write().await;
                let writer_file = OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(&store_path)
                    .unwrap();
                guard.writer = Box::new(PartialFailWriter {
                    inner: writer_file,
                    fail_next: Arc::clone(&fail_flag),
                });
            }

            assert!(store.delete_block(&cid_a).await.unwrap());
            store.put_block(&cid_b, &blk_b).await.unwrap();
            let err = store.synchronize().await.unwrap_err();
            assert!(matches!(err, BlockStoreError::Io(_)));

            // Partial write must have been truncated back to `baseline_len`, and in-memory pending
            // state must retain both the deletion of A and buffered put of B.
            assert_eq!(std::fs::metadata(&store_path).unwrap().len(), baseline_len);
            assert_eq!(store.get_block(&cid_a).await.unwrap(), None);
            assert_eq!(store.get_block(&cid_b).await.unwrap(), Some(blk_b.clone()));
            assert_eq!(store.len().await.unwrap(), 1);
            assert_eq!(store.total_bytes().await.unwrap(), blk_b.len());

            // Clear failure and retry synchronize: pending tombstone + put persist cleanly.
            fail_flag.store(false, Ordering::SeqCst);
            store.synchronize().await.unwrap();
            drop(store);

            let reopened = FileBlockStore::open(&store_path).unwrap();
            assert_eq!(reopened.get_block(&cid_a).await.unwrap(), None);
            assert_eq!(
                reopened.get_block(&cid_b).await.unwrap(),
                Some(blk_b.clone())
            );
            assert_eq!(reopened.len().await.unwrap(), 1);
            assert_eq!(reopened.total_bytes().await.unwrap(), blk_b.len());
        }

        #[tokio::test]
        async fn file_store_recovers_torn_trailing_frames_and_rejects_unblessed_cids() {
            let dir = tempfile::tempdir().unwrap();
            let store_path = dir.path().join("torn.carframes");
            let store = FileBlockStore::open(&store_path).unwrap();

            let blk_a = b"\xa1\x61a\x01".to_vec();
            let cid_a = Cid::for_dag_cbor(&blk_a);
            let blk_b = b"\xa1\x61b\x02".to_vec();
            let cid_b = Cid::for_dag_cbor(&blk_b);

            // Non-SHA-256 and unblessed (dag-pb 0x70) CIDs fail closed in both InMemory and File stores.
            let sha512_cid = Cid::from_bytes(&{
                let mut raw = vec![0x01, 0x71, 0x13, 0x20];
                raw.extend_from_slice(&[0xaa; 32]);
                raw
            })
            .unwrap();
            let dag_pb_cid = Cid::from_bytes(&{
                let mut raw = vec![0x01, 0x70, 0x12, 0x20];
                raw.extend_from_slice(&[0xbb; 32]);
                raw
            })
            .unwrap();
            let mem = crate::block_store::InMemoryBlockStore::new();
            for bad in [&sha512_cid, &dag_pb_cid] {
                assert!(matches!(
                    mem.put_block(bad, &blk_a).await,
                    Err(BlockStoreError::HashMismatch(_))
                ));
                assert!(matches!(
                    store.put_block(bad, &blk_a).await,
                    Err(BlockStoreError::HashMismatch(_))
                ));
            }

            store.put_block(&cid_a, &blk_a).await.unwrap();
            store.put_block(&cid_b, &blk_b).await.unwrap();
            store.synchronize().await.unwrap();
            assert!(store.delete_block(&cid_a).await.unwrap());
            store.synchronize().await.unwrap();
            drop(store);

            let baseline_len = std::fs::metadata(&store_path).unwrap().len();

            // 1. Append torn partial live frame (varint length + partial bytes).
            {
                let mut f = OpenOptions::new().append(true).open(&store_path).unwrap();
                f.write_all(&[0x30, 0x01, 0x71, 0x12, 0x20]).unwrap();
                f.flush().unwrap();
            }
            let recovered = FileBlockStore::open(&store_path).unwrap();
            assert_eq!(std::fs::metadata(&store_path).unwrap().len(), baseline_len);
            assert_eq!(recovered.get_block(&cid_a).await.unwrap(), None);
            assert_eq!(
                recovered.get_block(&cid_b).await.unwrap(),
                Some(blk_b.clone())
            );
            drop(recovered);

            // 2. Append torn deletion tombstone (`0x00 || 0x24 || partial cid`).
            {
                let mut f = OpenOptions::new().append(true).open(&store_path).unwrap();
                f.write_all(&[0x00, 0x24, 0x01, 0x71, 0x12]).unwrap();
                f.flush().unwrap();
            }
            let recovered = FileBlockStore::open(&store_path).unwrap();
            assert_eq!(std::fs::metadata(&store_path).unwrap().len(), baseline_len);
            assert_eq!(
                recovered.get_block(&cid_b).await.unwrap(),
                Some(blk_b.clone())
            );
            drop(recovered);

            // 3. Append incomplete multi-byte varint at EOF.
            {
                let mut f = OpenOptions::new().append(true).open(&store_path).unwrap();
                f.write_all(&[0x80]).unwrap();
                f.flush().unwrap();
            }
            let recovered = FileBlockStore::open(&store_path).unwrap();
            assert_eq!(std::fs::metadata(&store_path).unwrap().len(), baseline_len);
            assert_eq!(recovered.get_block(&cid_b).await.unwrap(), Some(blk_b));
            drop(recovered);

            // 4. Mid-stream payload corruption still fails hard on reopen.
            let mut bytes = std::fs::read(&store_path).unwrap();
            let mid = bytes.len() / 2;
            bytes[mid] ^= 0xff;
            std::fs::write(&store_path, bytes).unwrap();
            assert!(FileBlockStore::open(&store_path).is_err());
        }

        #[tokio::test]
        async fn open_car_source_rolls_back_buffered_block_when_threshold_flush_fails() {
            use std::collections::BTreeMap;

            use petrel_core::{Did, Value};

            use crate::car::DataCARByteSource;
            use crate::crypto::P256Keypair;
            use crate::limits::RepositoryLimits;
            use crate::repository::{OpenVerification, Repository, create_op};
            use crate::types::{RepositoryReadPolicy, WriteBatch};

            let did = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
            let signer = P256Keypair::generate().unwrap();
            let limits = RepositoryLimits::standard();
            let policy = RepositoryReadPolicy::strict();

            // Create a >1 MiB signed CAR so `FileBlockStore::put_block` hits
            // `WRITE_BUFFER_THRESHOLD` mid-import and triggers `flush()`.
            let base = Repository::create(did.clone(), &signer).await.unwrap();
            let large_ops = (0..3_usize)
                .map(|idx| {
                    let mut map = BTreeMap::new();
                    map.insert(
                        "$type".to_owned(),
                        Value::String("app.bsky.feed.post".into()),
                    );
                    map.insert(
                        "text".to_owned(),
                        Value::String(format!("{idx}-{}", "a".repeat(400_000))),
                    );
                    create_op(
                        "app.bsky.feed.post",
                        &format!("big{idx}"),
                        &Value::Object(map),
                    )
                    .unwrap()
                })
                .collect();
            let big_repo = base
                .commit_writes(WriteBatch::new(large_ops).unwrap(), &signer)
                .await
                .unwrap();
            let big_car = big_repo.repository.export_car().await.unwrap();

            // Pre-populate destination FileBlockStore with one synced block, then inject flush failure.
            let dir = tempfile::tempdir().unwrap();
            let store_path = dir.path().join("rollback_threshold.carframes");
            let store = Arc::new(FileBlockStore::open(&store_path).unwrap());

            let pre_bytes = b"\xa1\x63pre\x01".to_vec();
            let pre_cid = Cid::for_dag_cbor(&pre_bytes);
            store.put_block(&pre_cid, &pre_bytes).await.unwrap();
            store.synchronize().await.unwrap();

            let fail_flag = Arc::new(AtomicBool::new(true));
            {
                let mut guard = store.state.write().await;
                let writer_file = OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(&store_path)
                    .unwrap();
                guard.writer = Box::new(PartialFailWriter {
                    inner: writer_file,
                    fail_next: Arc::clone(&fail_flag),
                });
            }

            let mut source = DataCARByteSource::new(big_car);
            let err = Repository::open_car_source(
                &mut source,
                Arc::clone(&store),
                OpenVerification::SigningKey(signer.public_key().clone()),
                Some(&did),
                limits,
                policy,
                true,
            )
            .await
            .unwrap_err();
            assert!(matches!(
                err,
                crate::error::RepositoryError::Car(crate::error::CARError::BlockStore(
                    BlockStoreError::Io(_)
                ))
            ));

            // Every imported block—including the threshold block whose `flush()` failed—must
            // have been rolled back from `pending_puts` so later syncs persist zero orphans.
            assert_eq!(store.all_cids().await.unwrap(), vec![pre_cid.clone()]);
            assert_eq!(store.len().await.unwrap(), 1);
            assert_eq!(store.total_bytes().await.unwrap(), pre_bytes.len());

            fail_flag.store(false, Ordering::SeqCst);
            store.synchronize().await.unwrap();
            drop(store);

            let reopened = FileBlockStore::open(&store_path).unwrap();
            assert_eq!(reopened.all_cids().await.unwrap(), vec![pre_cid]);
            assert_eq!(reopened.total_bytes().await.unwrap(), pre_bytes.len());
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub use file_store::FileBlockStore;
