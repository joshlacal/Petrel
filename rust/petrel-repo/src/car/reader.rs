use std::collections::{BTreeMap, HashMap, HashSet};
use std::fmt;

use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::{Cid, Value, dagcbor};
use sha2::{Digest as _, Sha256};

use crate::block_store::{BlockStore, InMemoryBlockStore, RepositoryBlock};
use crate::car::varint;
use crate::car::writer;
use crate::error::{CARError, CARReaderError, LimitError, LimitKind};
use crate::limits::RepositoryLimits;
use crate::types::RepositoryReadPolicy;

const MAXIMUM_HEADER_BYTES: usize = 1024;
const STREAM_CHUNK_BYTES: usize = 64 * 1024;
const MAXIMUM_MST_TRAVERSAL_DEPTH: usize = 128;

/// Decoded CAR v1 header (`roots` + `version == 1`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CARHeader {
    pub version: i64,
    pub roots: Vec<Cid>,
}

/// Result of loading a CAR v1 archive into a [`BlockStore`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedCAR {
    pub root_cid: Cid,
    pub roots: Vec<Cid>,
    pub block_count: usize,
    pub total_block_bytes: usize,
    pub archive_bytes: usize,
}

/// Streaming byte source for incremental CAR v1 parsing (`CARByteSource`).
pub trait CARByteSource: MaybeSend + MaybeSync + fmt::Debug {
    fn next_chunk(&mut self) -> BoxFuture<'_, Result<Option<Vec<u8>>, CARError>>;
}

/// Slice/vector-backed [`CARByteSource`] (`DataCARByteSource`).
#[derive(Debug, Clone)]
pub struct DataCARByteSource {
    data: Vec<u8>,
    offset: usize,
    chunk_size: usize,
}

impl DataCARByteSource {
    pub fn new(data: Vec<u8>) -> Self {
        Self {
            data,
            offset: 0,
            chunk_size: STREAM_CHUNK_BYTES,
        }
    }

    pub fn with_chunk_size(data: Vec<u8>, chunk_size: usize) -> Self {
        Self {
            data,
            offset: 0,
            chunk_size: chunk_size.max(1),
        }
    }
}

impl CARByteSource for DataCARByteSource {
    fn next_chunk(&mut self) -> BoxFuture<'_, Result<Option<Vec<u8>>, CARError>> {
        Box::pin(async move {
            if self.offset >= self.data.len() {
                return Ok(None);
            }
            let end = (self.offset + self.chunk_size).min(self.data.len());
            let chunk = self.data[self.offset..end].to_vec();
            self.offset = end;
            Ok(Some(chunk))
        })
    }
}

#[cfg(not(target_arch = "wasm32"))]
mod file_source {
    use std::fs::File;
    use std::io::Read;
    use std::path::Path;

    use petrel::rt::BoxFuture;

    use crate::error::CARError;

    use super::{CARByteSource, STREAM_CHUNK_BYTES};

    /// File-backed [`CARByteSource`] (`FileCARByteSource`).
    #[derive(Debug)]
    pub struct FileCARByteSource {
        file: File,
        buf: Vec<u8>,
    }

    impl FileCARByteSource {
        pub fn open(path: impl AsRef<Path>) -> Result<Self, CARError> {
            let file = File::open(path).map_err(|err| CARError::Io(err.to_string()))?;
            Ok(Self {
                file,
                buf: vec![0_u8; STREAM_CHUNK_BYTES],
            })
        }
    }

    impl CARByteSource for FileCARByteSource {
        fn next_chunk(&mut self) -> BoxFuture<'_, Result<Option<Vec<u8>>, CARError>> {
            Box::pin(async move {
                let n = self
                    .file
                    .read(&mut self.buf)
                    .map_err(|err| CARError::Io(err.to_string()))?;
                if n == 0 {
                    Ok(None)
                } else {
                    Ok(Some(self.buf[..n].to_vec()))
                }
            })
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub use file_source::FileCARByteSource;

/// Strict AT Protocol CAR v1 reader, writer, and exporter (`PublicRepositoryCAR`).
#[derive(Debug, Clone, Copy, Default)]
pub struct PublicRepositoryCAR;

impl PublicRepositoryCAR {
    /// Writes a canonical CAR v1 archive into bytes.
    pub fn write(roots: &[Cid], blocks: &[RepositoryBlock]) -> Result<Vec<u8>, CARError> {
        writer::write_car_to_vec(roots, blocks)
    }

    /// Streams a canonical CAR v1 archive into `sink`.
    pub async fn write_to_sink<S: writer::CARByteSink + ?Sized>(
        roots: &[Cid],
        blocks: &[RepositoryBlock],
        sink: &S,
    ) -> Result<(), CARError> {
        writer::write_car_to_sink(roots, blocks, sink).await
    }

    /// Loads an entire CAR byte buffer into `store` with `limits` and `policy`.
    pub async fn load<S: BlockStore + ?Sized>(
        bytes: &[u8],
        store: &S,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<ParsedCAR, CARError> {
        let mut source = DataCARByteSource::new(bytes.to_vec());
        Self::load_from_source(&mut source, store, limits, policy).await
    }

    /// Parses a CAR byte buffer into a fresh [`InMemoryBlockStore`].
    pub async fn import_bytes(
        bytes: &[u8],
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<(ParsedCAR, InMemoryBlockStore), CARError> {
        let store =
            InMemoryBlockStore::with_limits(limits.max_block_count, limits.max_single_block_bytes);
        let parsed = Self::load(bytes, &store, limits, policy).await?;
        Ok((parsed, store))
    }

    /// Parses a CAR archive incrementally from `source` into `store`,
    /// enforcing header limits, canonical varint encoding, CID content hashes,
    /// duplicate block consistency, and `limits` / `policy`.
    #[allow(clippy::too_many_lines)]
    pub async fn load_from_source<Src: CARByteSource + ?Sized, Store: BlockStore + ?Sized>(
        source: &mut Src,
        store: &Store,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<ParsedCAR, CARError> {
        limits.validate()?;
        let mut stream = StreamingReader::new(source, limits.max_import_car_bytes);

        let header = Self::read_header_from_stream(&mut stream, limits, policy).await?;
        let root_cid = header
            .roots
            .first()
            .cloned()
            .ok_or(CARError::MissingRoots)?;

        let mut seen_foreign: HashMap<Vec<u8>, [u8; 32]> = HashMap::new();
        let mut seen_cids: HashSet<Cid> = HashSet::new();
        let mut block_count: usize = 0;
        let mut total_block_bytes: usize = 0;

        while let Some(frame_len_u64) = stream.try_read_varint().await? {
            let frame_len = usize::try_from(frame_len_u64).map_err(|_| CARError::VarintOverflow)?;
            if frame_len == 0 {
                return Err(CARError::ZeroLengthBlock);
            }
            if frame_len > limits.max_single_block_bytes.saturating_add(1024) {
                return Err(CARError::BlockTooLarge {
                    len: frame_len,
                    limit: limits.max_single_block_bytes,
                });
            }

            let frame = stream.read_exact(frame_len).await?;
            match parse_frame_cid(&frame)? {
                FrameCid::V1 { cid, cid_len } => {
                    let payload = &frame[cid_len..];
                    if payload.len() > limits.max_single_block_bytes {
                        return Err(CARError::BlockTooLarge {
                            len: payload.len(),
                            limit: limits.max_single_block_bytes,
                        });
                    }
                    let is_blessed_dag_cbor =
                        cid.blessed_kind() == Some(petrel_core::cid::BlessedKind::DagCbor);
                    if !is_blessed_dag_cbor {
                        if policy.rejects_foreign_car_blocks {
                            return Err(CARError::ForeignBlockRejected(cid.to_string()));
                        }
                        if cid.hash_code() == 0x12 {
                            verify_v1_cid_hash(&cid, payload)?;
                        }
                        record_foreign_block(
                            &mut seen_foreign,
                            &frame[..cid_len],
                            payload,
                            block_count,
                            limits.max_block_count,
                            &cid.to_string(),
                        )?;
                        continue;
                    }
                    verify_v1_cid_hash(&cid, payload)?;
                    if !seen_cids.contains(&cid) {
                        let total_seen = block_count.saturating_add(seen_foreign.len());
                        if total_seen >= limits.max_block_count {
                            return Err(CARError::Limit(crate::error::LimitError::Exceeded {
                                kind: crate::error::LimitKind::BlockCount,
                                observed: total_seen + 1,
                                limit: limits.max_block_count,
                            }));
                        }
                    }
                    if let Some(existing) = store.get_block(&cid).await? {
                        if existing.as_slice() != payload {
                            return Err(CARError::ConflictingDuplicateBlock(cid.to_string()));
                        }
                    } else {
                        store.put_block(&cid, payload).await?;
                    }
                    if seen_cids.insert(cid) {
                        block_count += 1;
                        total_block_bytes = total_block_bytes.saturating_add(payload.len());
                    }
                }
                FrameCid::V0 { raw_cid, cid_len } => {
                    let payload = &frame[cid_len..];
                    if payload.len() > limits.max_single_block_bytes {
                        return Err(CARError::BlockTooLarge {
                            len: payload.len(),
                            limit: limits.max_single_block_bytes,
                        });
                    }
                    if policy.rejects_foreign_car_blocks {
                        return Err(CARError::ForeignBlockRejected("CIDv0 dag-pb block".into()));
                    }
                    let digest: [u8; 32] = Sha256::digest(payload).into();
                    if digest.as_slice() != &raw_cid[2..34] {
                        return Err(CARError::HashMismatch("CIDv0".into()));
                    }
                    record_foreign_block(
                        &mut seen_foreign,
                        &raw_cid,
                        payload,
                        block_count,
                        limits.max_block_count,
                        "CIDv0",
                    )?;
                }
                FrameCid::ForeignNonBlessed { cid_len } => {
                    let payload = &frame[cid_len..];
                    if payload.len() > limits.max_single_block_bytes {
                        return Err(CARError::BlockTooLarge {
                            len: payload.len(),
                            limit: limits.max_single_block_bytes,
                        });
                    }
                    if policy.rejects_foreign_car_blocks {
                        return Err(CARError::ForeignBlockRejected("foreign CIDv1 block".into()));
                    }
                    record_foreign_block(
                        &mut seen_foreign,
                        &frame[..cid_len],
                        payload,
                        block_count,
                        limits.max_block_count,
                        "foreign CIDv1",
                    )?;
                }
            }
        }

        Ok(ParsedCAR {
            root_cid,
            roots: header.roots,
            block_count,
            total_block_bytes,
            archive_bytes: stream.bytes_consumed(),
        })
    }

    async fn read_header_from_stream<Src: CARByteSource + ?Sized>(
        stream: &mut StreamingReader<'_, Src>,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<CARHeader, CARError> {
        let Some(header_len_u64) = stream.try_read_varint().await? else {
            return Err(CARError::Truncated);
        };
        let header_len = usize::try_from(header_len_u64).map_err(|_| CARError::VarintOverflow)?;
        if header_len == 0 {
            return Err(CARError::InvalidHeader("zero-length CAR header".into()));
        }
        if header_len > MAXIMUM_HEADER_BYTES {
            return Err(CARError::InvalidHeader(format!(
                "CAR header length {header_len} exceeds limit {MAXIMUM_HEADER_BYTES}"
            )));
        }
        let header_bytes = stream.read_exact(header_len).await?;
        parse_header_cbor(&header_bytes, limits, *policy)
    }
}

pub(crate) fn parse_header_cbor(
    bytes: &[u8],
    limits: &RepositoryLimits,
    policy: RepositoryReadPolicy,
) -> Result<CARHeader, CARError> {
    let val = dagcbor::decode(bytes).map_err(|err| CARError::InvalidHeader(err.to_string()))?;
    let Value::Object(map) = val else {
        return Err(CARError::InvalidHeader(
            "CAR header must be a CBOR map".into(),
        ));
    };
    for key in map.keys() {
        if key != "version" && key != "roots" {
            return Err(CARError::InvalidHeader(format!(
                "unexpected key {key:?} in CAR header"
            )));
        }
    }
    let version = match map.get("version") {
        Some(Value::Integer(1)) => 1,
        Some(Value::Integer(other)) => return Err(CARError::UnsupportedVersion(*other)),
        _ => {
            return Err(CARError::InvalidHeader(
                "CAR header missing integer version".into(),
            ));
        }
    };
    let Some(Value::Array(roots_arr)) = map.get("roots") else {
        return Err(CARError::InvalidHeader(
            "CAR header missing roots array".into(),
        ));
    };
    if roots_arr.is_empty() {
        return Err(CARError::MissingRoots);
    }
    if policy.requires_single_car_root && roots_arr.len() > 1 {
        return Err(CARError::MultipleRoots {
            count: roots_arr.len(),
        });
    }
    if roots_arr.len() > limits.max_car_roots {
        return Err(CARError::TooManyRoots {
            count: roots_arr.len(),
            limit: limits.max_car_roots,
        });
    }
    let mut roots = Vec::with_capacity(roots_arr.len());
    for item in roots_arr {
        let Value::Link(cid) = item else {
            return Err(CARError::InvalidHeader(
                "CAR root entry must be a CID link".into(),
            ));
        };
        roots.push(cid.clone());
    }
    Ok(CARHeader { version, roots })
}

enum FrameCid {
    V1 { cid: Cid, cid_len: usize },
    V0 { raw_cid: Vec<u8>, cid_len: usize },
    ForeignNonBlessed { cid_len: usize },
}

pub(crate) fn cid_prefix_len(frame: &[u8]) -> Result<usize, CARError> {
    if frame.len() >= 34 && frame[0] == 0x12 && frame[1] == 0x20 {
        return Ok(34);
    }
    let mut off = 0;
    let (version, vlen) = varint::decode(&frame[off..])?;
    off += vlen;
    if version != 1 {
        return Err(CARError::InvalidCid(format!(
            "unsupported CID version {version}"
        )));
    }
    let (_codec, clen) = varint::decode(&frame[off..])?;
    off += clen;
    let (_hash_code, hlen) = varint::decode(&frame[off..])?;
    off += hlen;
    let (digest_len_u64, dlen) = varint::decode(&frame[off..])?;
    off += dlen;
    let digest_len = usize::try_from(digest_len_u64)
        .map_err(|_| CARError::InvalidCid("CID digest length overflow".into()))?;
    if digest_len == 0 || digest_len > 1024 {
        return Err(CARError::InvalidCid(format!(
            "CID digest length {digest_len} out of bounds"
        )));
    }
    let total = off.saturating_add(digest_len);
    if total > frame.len() {
        return Err(CARError::CidOverrunsBlock);
    }
    Ok(total)
}

fn parse_frame_cid(frame: &[u8]) -> Result<FrameCid, CARError> {
    if frame.len() >= 34 && frame[0] == 0x12 && frame[1] == 0x20 {
        return Ok(FrameCid::V0 {
            raw_cid: frame[..34].to_vec(),
            cid_len: 34,
        });
    }
    let cid_len = cid_prefix_len(frame)?;
    match Cid::from_bytes(&frame[..cid_len]) {
        Ok(cid) => Ok(FrameCid::V1 { cid, cid_len }),
        Err(_) => Ok(FrameCid::ForeignNonBlessed { cid_len }),
    }
}

fn verify_v1_cid_hash(cid: &Cid, payload: &[u8]) -> Result<(), CARError> {
    if cid.hash_code() != 0x12 {
        return Err(CARError::InvalidCid(format!(
            "unsupported multihash 0x{:x} in {cid}",
            cid.hash_code()
        )));
    }
    if !cid.matches_content(payload) {
        return Err(CARError::HashMismatch(cid.to_string()));
    }
    Ok(())
}

fn record_foreign_block(
    seen_foreign: &mut HashMap<Vec<u8>, [u8; 32]>,
    raw_cid: &[u8],
    payload: &[u8],
    block_count: usize,
    max_block_count: usize,
    label: &str,
) -> Result<(), CARError> {
    let digest: [u8; 32] = Sha256::digest(payload).into();
    if let Some(prev) = seen_foreign.get(raw_cid) {
        if prev != &digest {
            return Err(CARError::ConflictingDuplicateBlock(label.to_owned()));
        }
        return Ok(());
    }
    let total_seen = block_count.saturating_add(seen_foreign.len());
    if total_seen >= max_block_count {
        return Err(CARError::Limit(crate::error::LimitError::Exceeded {
            kind: crate::error::LimitKind::BlockCount,
            observed: total_seen + 1,
            limit: max_block_count,
        }));
    }
    seen_foreign.insert(raw_cid.to_vec(), digest);
    Ok(())
}

struct StreamingReader<'a, S: CARByteSource + ?Sized> {
    source: &'a mut S,
    buf: Vec<u8>,
    pos: usize,
    eof: bool,
    bytes_consumed: usize,
    max_total_bytes: usize,
}

impl<'a, S: CARByteSource + ?Sized> StreamingReader<'a, S> {
    fn new(source: &'a mut S, max_total_bytes: usize) -> Self {
        Self {
            source,
            buf: Vec::new(),
            pos: 0,
            eof: false,
            bytes_consumed: 0,
            max_total_bytes,
        }
    }

    fn bytes_consumed(&self) -> usize {
        self.bytes_consumed
    }

    fn available(&self) -> usize {
        self.buf.len().saturating_sub(self.pos)
    }

    async fn fill(&mut self) -> Result<bool, CARError> {
        if self.eof {
            return Ok(false);
        }
        if self.pos > 0 {
            self.buf.drain(..self.pos);
            self.pos = 0;
        }
        loop {
            match self.source.next_chunk().await? {
                Some(chunk) if chunk.is_empty() => {}
                Some(chunk) => {
                    let new_total = self
                        .bytes_consumed
                        .saturating_add(self.buf.len())
                        .saturating_add(chunk.len());
                    if new_total > self.max_total_bytes {
                        return Err(CARError::Limit(crate::error::LimitError::Exceeded {
                            kind: crate::error::LimitKind::ImportCarBytes,
                            observed: new_total,
                            limit: self.max_total_bytes,
                        }));
                    }
                    self.buf.extend_from_slice(&chunk);
                    return Ok(true);
                }
                None => {
                    self.eof = true;
                    return Ok(false);
                }
            }
        }
    }

    async fn ensure(&mut self, needed: usize) -> Result<bool, CARError> {
        while self.available() < needed {
            if !self.fill().await? {
                return Ok(false);
            }
        }
        Ok(true)
    }

    async fn try_read_varint(&mut self) -> Result<Option<u64>, CARError> {
        if !self.ensure(1).await? {
            return Ok(None);
        }
        let mut idx = 0;
        loop {
            if idx >= 9 {
                return Err(CARError::VarintOverflow);
            }
            if !self.ensure(idx + 1).await? {
                return Err(CARError::Truncated);
            }
            let byte = self.buf[self.pos + idx];
            if (byte & 0x80) == 0 {
                let (val, consumed) = varint::decode(&self.buf[self.pos..=self.pos + idx])?;
                self.pos += consumed;
                self.bytes_consumed = self.bytes_consumed.saturating_add(consumed);
                return Ok(Some(val));
            }
            idx += 1;
        }
    }

    async fn read_exact(&mut self, len: usize) -> Result<Vec<u8>, CARError> {
        if self.bytes_consumed.saturating_add(len) > self.max_total_bytes {
            return Err(CARError::Limit(crate::error::LimitError::Exceeded {
                kind: crate::error::LimitKind::ImportCarBytes,
                observed: self.bytes_consumed.saturating_add(len),
                limit: self.max_total_bytes,
            }));
        }
        if !self.ensure(len).await? {
            return Err(CARError::Truncated);
        }
        let slice = self.buf[self.pos..self.pos + len].to_vec();
        self.pos += len;
        self.bytes_consumed = self.bytes_consumed.saturating_add(len);
        Ok(slice)
    }
}

/// Low-level CAR v1 reader mirroring `Sources/PetrelCore/CARReader.swift`
/// (`CARReader` + `CARStrictnessTests`), supporting both CIDv0 and CIDv1 frames
/// with strict bounds, hash verification, and duplicate checking.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CARReader {
    pub version: i64,
    pub roots: Vec<Cid>,
    pub raw_roots: Vec<Vec<u8>>,
    /// Blocks keyed by CIDv1 where representable.
    pub blocks: BTreeMap<Cid, Vec<u8>>,
    /// Raw block index keyed by exact raw CID bytes (supports both CIDv0 and CIDv1).
    pub raw_blocks: BTreeMap<Vec<u8>, Vec<u8>>,
}

impl CARReader {
    /// Parses a complete CAR v1 archive from bytes following `CARReader.swift`
    /// under [`RepositoryLimits::network_scale`].
    pub fn parse(data: &[u8]) -> Result<Self, CARReaderError> {
        Self::parse_with_limits(data, &RepositoryLimits::network_scale())
    }

    /// Parses a complete CAR v1 archive enforcing explicit [`RepositoryLimits`]
    /// (`max_import_car_bytes`, header cap, `max_single_block_bytes`, `max_block_count`).
    #[allow(clippy::too_many_lines)]
    pub fn parse_with_limits(
        data: &[u8],
        limits: &RepositoryLimits,
    ) -> Result<Self, CARReaderError> {
        parse_car_reader_internal(data, limits, true)
    }
}

#[allow(clippy::too_many_lines)]
fn parse_car_reader_internal(
    data: &[u8],
    limits: &RepositoryLimits,
    collect_raw_blocks: bool,
) -> Result<CARReader, CARReaderError> {
    limits
        .validate()
        .map_err(|err| CARReaderError::InvalidHeader(err.to_string()))?;
    if data.len() > limits.max_import_car_bytes {
        return Err(CARReaderError::Limit(LimitError::Exceeded {
            kind: LimitKind::ImportCarBytes,
            observed: data.len(),
            limit: limits.max_import_car_bytes,
        }));
    }

    let mut cursor: usize = 0;

    let header_len_u64 = read_car_reader_varint(data, &mut cursor)?;
    let header_len = usize::try_from(header_len_u64).map_err(|_| CARReaderError::InvalidVarint)?;
    if header_len > MAXIMUM_HEADER_BYTES {
        return Err(CARReaderError::InvalidHeader(format!(
            "CAR header size {header_len} exceeds limit {MAXIMUM_HEADER_BYTES}"
        )));
    }
    if header_len == 0 || cursor.saturating_add(header_len) > data.len() {
        return Err(CARReaderError::Truncated);
    }
    let header_bytes = &data[cursor..cursor + header_len];
    cursor += header_len;

    let header_val = dagcbor::decode(header_bytes)
        .map_err(|err| CARReaderError::InvalidHeader(err.to_string()))?;
    let Value::Object(map) = header_val else {
        return Err(CARReaderError::InvalidHeader(
            "header must be a CBOR map".into(),
        ));
    };
    for key in map.keys() {
        if key != "version" && key != "roots" {
            return Err(CARReaderError::InvalidHeader(format!(
                "unexpected key {key:?} in header"
            )));
        }
    }
    let version = match map.get("version") {
        Some(Value::Integer(1)) => 1,
        Some(Value::Integer(other)) => return Err(CARReaderError::UnsupportedVersion(*other)),
        _ => {
            return Err(CARReaderError::InvalidHeader(
                "missing integer version".into(),
            ));
        }
    };
    let Some(Value::Array(roots_arr)) = map.get("roots") else {
        return Err(CARReaderError::InvalidHeader("missing roots array".into()));
    };
    if roots_arr.is_empty() {
        return Err(CARReaderError::MissingRoots);
    }

    let mut roots = Vec::with_capacity(roots_arr.len());
    let mut raw_roots = Vec::with_capacity(if collect_raw_blocks {
        roots_arr.len()
    } else {
        0
    });
    for item in roots_arr {
        let Value::Link(cid) = item else {
            return Err(CARReaderError::InvalidHeader(
                "root entry must be a CID link".into(),
            ));
        };
        if collect_raw_blocks {
            raw_roots.push(cid.as_bytes().to_vec());
        }
        roots.push(cid.clone());
    }

    let mut blocks: BTreeMap<Cid, Vec<u8>> = BTreeMap::new();
    let mut raw_blocks: BTreeMap<Vec<u8>, Vec<u8>> = BTreeMap::new();
    let mut seen_v0_digests: HashMap<[u8; 34], [u8; 32]> = HashMap::new();

    while cursor < data.len() {
        let block_len_u64 = read_car_reader_varint(data, &mut cursor)?;
        let block_len =
            usize::try_from(block_len_u64).map_err(|_| CARReaderError::InvalidVarint)?;
        if block_len == 0 {
            return Err(CARReaderError::InvalidCid("zero-length block frame".into()));
        }
        if cursor.saturating_add(block_len) > data.len() {
            return Err(CARReaderError::Truncated);
        }
        let frame = &data[cursor..cursor + block_len];
        cursor += block_len;

        if frame.len() >= 34 && frame[0] == 0x12 && frame[1] == 0x20 {
            // CIDv0: sha2-256 multihash (34 bytes).
            let raw_cid: [u8; 34] = frame[..34].try_into().expect("slice len checked >= 34");
            let payload = &frame[34..];
            if payload.len() > limits.max_single_block_bytes {
                return Err(CARReaderError::Limit(LimitError::Exceeded {
                    kind: LimitKind::SingleBlockBytes,
                    observed: payload.len(),
                    limit: limits.max_single_block_bytes,
                }));
            }
            let digest: [u8; 32] = Sha256::digest(payload).into();
            if digest.as_slice() != &raw_cid[2..34] {
                return Err(CARReaderError::HashMismatch("CIDv0".into()));
            }
            if let Some(prev_digest) = seen_v0_digests.get(&raw_cid) {
                if prev_digest != &digest {
                    return Err(CARReaderError::ConflictingDuplicateBlock("CIDv0".into()));
                }
            } else {
                let total_seen = blocks.len().saturating_add(seen_v0_digests.len());
                if total_seen >= limits.max_block_count {
                    return Err(CARReaderError::Limit(LimitError::Exceeded {
                        kind: LimitKind::BlockCount,
                        observed: total_seen + 1,
                        limit: limits.max_block_count,
                    }));
                }
                seen_v0_digests.insert(raw_cid, digest);
                if collect_raw_blocks {
                    raw_blocks.insert(raw_cid.to_vec(), payload.to_vec());
                }
            }
            continue;
        }

        let (cid, cid_len) = parse_cid_for_car_reader(frame)?;
        if cid_len > frame.len() {
            return Err(CARReaderError::Truncated);
        }
        let payload = &frame[cid_len..];
        if payload.len() > limits.max_single_block_bytes {
            return Err(CARReaderError::Limit(LimitError::Exceeded {
                kind: LimitKind::SingleBlockBytes,
                observed: payload.len(),
                limit: limits.max_single_block_bytes,
            }));
        }
        if cid.hash_code() != 0x12 {
            return Err(CARReaderError::UnsupportedMultihash(cid.hash_code()));
        }
        if !cid.matches_content(payload) {
            return Err(CARReaderError::HashMismatch(cid.to_string()));
        }
        if let Some(existing) = blocks.get(&cid) {
            if existing.as_slice() != payload {
                return Err(CARReaderError::ConflictingDuplicateBlock(cid.to_string()));
            }
        } else {
            let total_seen = blocks.len().saturating_add(seen_v0_digests.len());
            if total_seen >= limits.max_block_count {
                return Err(CARReaderError::Limit(LimitError::Exceeded {
                    kind: LimitKind::BlockCount,
                    observed: total_seen + 1,
                    limit: limits.max_block_count,
                }));
            }
            if collect_raw_blocks {
                raw_blocks.insert(cid.as_bytes().to_vec(), payload.to_vec());
            }
            blocks.insert(cid, payload.to_vec());
        }
    }

    Ok(CARReader {
        version,
        roots,
        raw_roots,
        blocks,
        raw_blocks,
    })
}

fn read_car_reader_varint(data: &[u8], cursor: &mut usize) -> Result<u64, CARReaderError> {
    let slice = &data[*cursor..];
    match varint::decode(slice) {
        Ok((val, len)) => {
            *cursor += len;
            Ok(val)
        }
        Err(CARError::Truncated) => Err(CARReaderError::Truncated),
        Err(CARError::NonCanonicalVarint | CARError::VarintOverflow) => {
            Err(CARReaderError::InvalidVarint)
        }
        Err(other) => Err(CARReaderError::InvalidHeader(other.to_string())),
    }
}

fn parse_cid_for_car_reader(frame: &[u8]) -> Result<(Cid, usize), CARReaderError> {
    // Inspect varint fields and slice exact CID bytes (`&frame[..total]`) before
    // constructing `Cid`.
    let mut off = 0;
    let version = read_u64_varint_prefix(frame, &mut off)?;
    if version != 1 {
        return Err(CARReaderError::InvalidCid(format!(
            "unsupported CID version {version}"
        )));
    }
    let _codec = read_u64_varint_prefix(frame, &mut off)?;
    let hash_code = read_u64_varint_prefix(frame, &mut off)?;
    if hash_code != 0x12 {
        return Err(CARReaderError::UnsupportedMultihash(hash_code));
    }
    let digest_len_u64 = read_u64_varint_prefix(frame, &mut off)?;
    let digest_len = usize::try_from(digest_len_u64)
        .map_err(|_| CARReaderError::InvalidCid("digest length overflow".into()))?;
    let total = off.saturating_add(digest_len);
    if total > frame.len() {
        return Err(CARReaderError::Truncated);
    }
    let cid = Cid::from_bytes(&frame[..total])
        .map_err(|err| CARReaderError::InvalidCid(err.to_string()))?;
    Ok((cid, total))
}

fn read_u64_varint_prefix(data: &[u8], cursor: &mut usize) -> Result<u64, CARReaderError> {
    let (val, len) = varint::decode(&data[*cursor..]).map_err(|err| match err {
        CARError::Truncated => CARReaderError::Truncated,
        _ => CARReaderError::InvalidVarint,
    })?;
    *cursor += len;
    Ok(val)
}

/// Convenience parsed repository archive mirroring `Sources/Petrel/Core/CAR/CARRepository.swift`
/// and `MSTTraverser.swift` (cycle detection, max depth 128, key ordering).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CARRepository {
    pub did: String,
    pub version: i64,
    pub rev: Option<String>,
    pub data_cid: Cid,
    pub prev_cid: Option<Cid>,
    pub sig: Option<Vec<u8>>,
    pub collections: BTreeMap<String, BTreeMap<String, Cid>>,
    pub records: BTreeMap<String, Vec<u8>>,
}

/// Alias preserving legacy naming in tests.
pub type CARArchive = CARRepository;

impl CARRepository {
    /// Parses a repository CAR v1 archive without cryptographic signature verification,
    /// validating commit structure and traversing the MST with cycle detection,
    /// max depth 128, prefix bounds, strictly increasing `collection/rkey` keys, and
    /// [`RepositoryLimits::network_scale`].
    pub fn parse(data: &[u8]) -> Result<Self, CARReaderError> {
        Self::parse_with_limits(data, &RepositoryLimits::network_scale())
    }

    /// Parses a repository CAR v1 archive enforcing explicit [`RepositoryLimits`].
    #[allow(clippy::too_many_lines)]
    pub fn parse_with_limits(
        data: &[u8],
        limits: &RepositoryLimits,
    ) -> Result<Self, CARReaderError> {
        let mut reader = parse_car_reader_internal(data, limits, false)?;
        if reader.roots.len() > limits.max_car_roots {
            return Err(CARReaderError::InvalidHeader(format!(
                "CAR root count {} exceeds limit {}",
                reader.roots.len(),
                limits.max_car_roots
            )));
        }
        let root = reader
            .roots
            .first()
            .ok_or(CARReaderError::MissingRoots)?
            .clone();
        let commit_bytes = reader
            .blocks
            .get(&root)
            .ok_or_else(|| CARReaderError::MissingBlock(root.to_string()))?;
        let commit_val = dagcbor::decode(commit_bytes)
            .map_err(|err| CARReaderError::InvalidHeader(err.to_string()))?;
        let Value::Object(commit_map) = commit_val else {
            return Err(CARReaderError::InvalidHeader(
                "commit must be a CBOR map".into(),
            ));
        };
        let did = match commit_map.get("did") {
            Some(Value::String(s)) => s.clone(),
            _ => return Err(CARReaderError::InvalidHeader("commit missing did".into())),
        };
        let version = match commit_map.get("version") {
            Some(Value::Integer(v)) => *v,
            _ => {
                return Err(CARReaderError::InvalidHeader(
                    "commit missing version".into(),
                ));
            }
        };
        let rev = match commit_map.get("rev") {
            Some(Value::String(s)) => Some(s.clone()),
            None => None,
            _ => {
                return Err(CARReaderError::InvalidHeader(
                    "commit rev must be string".into(),
                ));
            }
        };
        let data_cid = match commit_map.get("data") {
            Some(Value::Link(cid)) => cid.clone(),
            _ => {
                return Err(CARReaderError::InvalidHeader(
                    "commit missing data link".into(),
                ));
            }
        };
        let prev_cid = match commit_map.get("prev") {
            Some(Value::Link(cid)) => Some(cid.clone()),
            Some(Value::Null) | None => None,
            _ => {
                return Err(CARReaderError::InvalidHeader(
                    "commit prev must be link or null".into(),
                ));
            }
        };
        let sig = match commit_map.get("sig") {
            Some(Value::Bytes(b)) => Some(b.clone()),
            None => None,
            _ => {
                return Err(CARReaderError::InvalidHeader(
                    "commit sig must be bytes".into(),
                ));
            }
        };

        let mut state = MstTraverseState {
            visited: HashSet::new(),
            mst_node_count: 0,
            visited_record_count: 0,
            max_mst_depth: limits.max_mst_depth.min(MAXIMUM_MST_TRAVERSAL_DEPTH),
            max_mst_node_count: limits.max_mst_node_count,
            max_record_count: limits.max_record_count,
            last_key: None,
            collections: BTreeMap::new(),
            record_cids: Vec::new(),
            cid_refcounts: HashMap::new(),
        };

        traverse_mst_node(&data_cid, &reader.blocks, 0, &mut state)?;

        let mut records: BTreeMap<String, Vec<u8>> = BTreeMap::new();
        for (full_key, value_cid) in state.record_cids {
            if let Some(remaining) = state.cid_refcounts.get_mut(&value_cid) {
                let bytes_opt = if *remaining <= 1 {
                    reader.blocks.remove(&value_cid)
                } else {
                    *remaining -= 1;
                    reader.blocks.get(&value_cid).cloned()
                };
                if let Some(record_bytes) = bytes_opt {
                    records.insert(full_key, record_bytes);
                }
            }
        }

        Ok(Self {
            did,
            version,
            rev,
            data_cid,
            prev_cid,
            sig,
            collections: state.collections,
            records,
        })
    }
}

struct MstTraverseState {
    visited: HashSet<Cid>,
    mst_node_count: usize,
    visited_record_count: usize,
    max_mst_depth: usize,
    max_mst_node_count: usize,
    max_record_count: usize,
    last_key: Option<String>,
    collections: BTreeMap<String, BTreeMap<String, Cid>>,
    record_cids: Vec<(String, Cid)>,
    cid_refcounts: HashMap<Cid, usize>,
}

#[allow(clippy::too_many_lines)]
fn traverse_mst_node(
    node_cid: &Cid,
    blocks: &BTreeMap<Cid, Vec<u8>>,
    depth: usize,
    state: &mut MstTraverseState,
) -> Result<(), CARReaderError> {
    if depth > state.max_mst_depth {
        return Err(CARReaderError::MstDepthLimitExceeded);
    }
    if !state.visited.insert(node_cid.clone()) {
        return Err(CARReaderError::MstCycle(node_cid.to_string()));
    }
    state.mst_node_count = state.mst_node_count.saturating_add(1);
    if state.mst_node_count > state.max_mst_node_count {
        return Err(CARReaderError::Limit(LimitError::Exceeded {
            kind: LimitKind::MstNodeCount,
            observed: state.mst_node_count,
            limit: state.max_mst_node_count,
        }));
    }
    let node_bytes = blocks
        .get(node_cid)
        .ok_or_else(|| CARReaderError::MissingBlock(node_cid.to_string()))?;
    let node_val = dagcbor::decode(node_bytes)
        .map_err(|err| CARReaderError::InvalidMstNode(err.to_string()))?;
    let Value::Object(map) = node_val else {
        return Err(CARReaderError::InvalidMstNode(
            "MST node must be a map".into(),
        ));
    };

    if let Some(left_val) = map.get("l") {
        match left_val {
            Value::Link(left_cid) => traverse_mst_node(left_cid, blocks, depth + 1, state)?,
            Value::Null => {}
            _ => {
                return Err(CARReaderError::InvalidMstNode(
                    "MST 'l' must be link or null".into(),
                ));
            }
        }
    }

    let Some(Value::Array(entries)) = map.get("e") else {
        return Err(CARReaderError::InvalidMstNode(
            "MST node missing 'e' entries array".into(),
        ));
    };

    let mut current_prefix = Vec::<u8>::new();
    for entry_val in entries {
        let Value::Object(entry) = entry_val else {
            return Err(CARReaderError::InvalidMstNode(
                "MST entry must be a map".into(),
            ));
        };
        let prefix_len = match entry.get("p") {
            Some(Value::Integer(p)) if *p >= 0 => usize::try_from(*p).map_err(|_| {
                CARReaderError::InvalidMstNode("negative or oversized prefix".into())
            })?,
            _ => {
                return Err(CARReaderError::InvalidMstNode(
                    "MST entry missing non-negative 'p'".into(),
                ));
            }
        };
        if prefix_len > current_prefix.len() {
            return Err(CARReaderError::InvalidMstNode(format!(
                "MST prefix length {prefix_len} exceeds previous key len {}",
                current_prefix.len()
            )));
        }
        let Some(Value::Bytes(suffix)) = entry.get("k") else {
            return Err(CARReaderError::InvalidMstNode(
                "MST entry missing bytes 'k'".into(),
            ));
        };
        let mut key_bytes = Vec::with_capacity(prefix_len + suffix.len());
        key_bytes.extend_from_slice(&current_prefix[..prefix_len]);
        key_bytes.extend_from_slice(suffix);
        let full_key = String::from_utf8(key_bytes.clone())
            .map_err(|_| CARReaderError::InvalidMstNode("non-UTF-8 MST key".into()))?;
        current_prefix = key_bytes;

        if let Some(prev) = state.last_key.as_ref()
            && &full_key <= prev
        {
            return Err(CARReaderError::InvalidMstOrder(format!(
                "{full_key:?} is not strictly greater than {prev:?}"
            )));
        }
        state.last_key = Some(full_key.clone());

        let (collection, rkey) = full_key.split_once('/').ok_or_else(|| {
            CARReaderError::InvalidMstNode(format!("key missing collection/rkey '/': {full_key}"))
        })?;
        if collection.is_empty() || rkey.is_empty() || rkey.contains('/') {
            return Err(CARReaderError::InvalidMstNode(format!(
                "invalid collection/rkey key: {full_key}"
            )));
        }

        let Some(Value::Link(value_cid)) = entry.get("v") else {
            return Err(CARReaderError::InvalidMstNode(
                "MST entry missing value link 'v'".into(),
            ));
        };
        if state.visited_record_count >= state.max_record_count {
            return Err(CARReaderError::Limit(LimitError::Exceeded {
                kind: LimitKind::RecordCount,
                observed: state.visited_record_count + 1,
                limit: state.max_record_count,
            }));
        }
        state.visited_record_count = state.visited_record_count.saturating_add(1);
        if blocks.contains_key(value_cid) {
            *state.cid_refcounts.entry(value_cid.clone()).or_insert(0) += 1;
            state
                .record_cids
                .push((full_key.clone(), value_cid.clone()));
        }
        state
            .collections
            .entry(collection.to_owned())
            .or_default()
            .insert(rkey.to_owned(), value_cid.clone());

        if let Some(tree_val) = entry.get("t") {
            match tree_val {
                Value::Link(right_cid) => traverse_mst_node(right_cid, blocks, depth + 1, state)?,
                Value::Null => {}
                _ => {
                    return Err(CARReaderError::InvalidMstNode(
                        "MST 't' must be link or null".into(),
                    ));
                }
            }
        }
    }

    state.visited.remove(node_cid);
    Ok(())
}
