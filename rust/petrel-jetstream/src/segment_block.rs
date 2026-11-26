//! Columnar Jetstream v2 segment blocks and `.jss0` archive segment reader.

#[cfg(not(target_arch = "wasm32"))]
use std::fs::File;
#[cfg(not(target_arch = "wasm32"))]
use std::io::{Read, Seek, SeekFrom};
#[cfg(not(target_arch = "wasm32"))]
use std::path::Path;

use petrel_api::generated::com::atproto::sync::subscribe_repos;
use petrel_core::{Value, dagcbor, to_json};
use petrel_firehose::RelayRepoAction;

use crate::event::{
    JetstreamAccountEvent, JetstreamCommitEvent, JetstreamEvent, JetstreamIdentityEvent,
    JetstreamSyncEvent,
};
use crate::zstd::{JetstreamZstd, JetstreamZstdError};

const MAX_EVENT_COUNT: usize = 262_144;
const JSS_MAGIC: [u8; 4] = *b"jss0";
const JSS_HEADER_LEN: usize = 256;

/// One decoded columnar row from a Jetstream v2 segment block.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SegmentEvent {
    pub seq: i64,
    pub witnessed_at_us: i64,
    pub indexed_at_us: i64,
    /// Kind byte `1..=7` (`1=Create`, `2=Update`, `3=Delete`, `4=Identity`, `5=Account`, `6=Sync`, `7=CreateResync`).
    pub kind: u8,
    pub collection: String,
    pub did: String,
    pub rkey: String,
    pub rev: String,
    /// Raw DAG-CBOR payload (empty when `event_len == 0`).
    pub payload: Vec<u8>,
}

impl SegmentEvent {
    /// Display timestamp in Unix microseconds (`indexed_at_us` if non-zero, else `witnessed_at_us`).
    pub const fn time_us(&self) -> i64 {
        if self.indexed_at_us != 0 {
            self.indexed_at_us
        } else {
            self.witnessed_at_us
        }
    }

    /// Converts this raw segment row into a [`JetstreamEvent`]. Returns `None` if `kind` is not `1..=7`.
    pub fn to_jetstream_event(&self) -> Option<JetstreamEvent> {
        let time_us = self.time_us();
        match self.kind {
            1 | 7 => Some(JetstreamEvent::Commit(JetstreamCommitEvent {
                seq: self.seq,
                did: self.did.clone(),
                time_us,
                rev: self.rev.clone(),
                operation: RelayRepoAction::Create,
                collection: self.collection.clone(),
                rkey: self.rkey.clone(),
                cid: None,
                record_json: decode_payload_json(&self.payload),
            })),
            2 => Some(JetstreamEvent::Commit(JetstreamCommitEvent {
                seq: self.seq,
                did: self.did.clone(),
                time_us,
                rev: self.rev.clone(),
                operation: RelayRepoAction::Update,
                collection: self.collection.clone(),
                rkey: self.rkey.clone(),
                cid: None,
                record_json: decode_payload_json(&self.payload),
            })),
            3 => Some(JetstreamEvent::Commit(JetstreamCommitEvent {
                seq: self.seq,
                did: self.did.clone(),
                time_us,
                rev: self.rev.clone(),
                operation: RelayRepoAction::Delete,
                collection: self.collection.clone(),
                rkey: self.rkey.clone(),
                cid: None,
                record_json: None,
            })),
            4 => Some(JetstreamEvent::Identity(JetstreamIdentityEvent {
                seq: self.seq,
                did: self.did.clone(),
                time_us,
                identity: decode_payload_detail::<subscribe_repos::Identity>(&self.payload),
            })),
            5 => Some(JetstreamEvent::Account(JetstreamAccountEvent {
                seq: self.seq,
                did: self.did.clone(),
                time_us,
                account: decode_payload_detail::<subscribe_repos::Account>(&self.payload),
            })),
            6 => Some(JetstreamEvent::Sync(JetstreamSyncEvent {
                seq: self.seq,
                did: self.did.clone(),
                time_us,
                sync: decode_payload_detail::<subscribe_repos::Sync>(&self.payload),
            })),
            _ => None,
        }
    }
}

fn decode_payload_json(data: &[u8]) -> Option<Vec<u8>> {
    if data.is_empty() {
        return None;
    }
    let value: Value = dagcbor::decode_with(data, dagcbor::Limits::REPOSITORY_BLOCK).ok()?;
    to_json(&value).ok()
}

fn decode_payload_detail<T: serde::de::DeserializeOwned>(data: &[u8]) -> Option<T> {
    let json = decode_payload_json(data)?;
    serde_json::from_slice(&json).ok()
}

/// Errors produced while decoding segment blocks or `.jss0` segment files.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum SegmentBlockError {
    #[error("segment data truncated")]
    Truncated,
    #[error("invalid segment header: {0}")]
    InvalidHeader(String),
    #[error("segment archive not sealed (zero checksum)")]
    NotSealed,
    #[error("unsupported segment version: {0}")]
    UnsupportedVersion(u16),
    #[error("bad segment magic bytes")]
    BadMagic,
    #[error(transparent)]
    Zstd(#[from] JetstreamZstdError),
    #[error("I/O error: {0}")]
    Io(String),
}

/// Decodes columnar Jetstream v2 segment blocks.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SegmentBlockDecoder;

impl SegmentBlockDecoder {
    /// Decompresses one standalone zstd frame and decodes its columnar events.
    pub fn decode_frame(frame: &[u8]) -> Result<Vec<SegmentEvent>, SegmentBlockError> {
        let uncompressed = JetstreamZstd::decompress(frame)?;
        Self::decode_uncompressed(&uncompressed)
    }

    /// Decompresses one standalone zstd frame with an explicit decompressed byte limit and
    /// decodes its columnar events.
    pub fn decode_frame_with_limit(
        frame: &[u8],
        max_decompressed_bytes: usize,
    ) -> Result<Vec<SegmentEvent>, SegmentBlockError> {
        let uncompressed = JetstreamZstd::decompress_with_limit(frame, max_decompressed_bytes)?;
        Self::decode_uncompressed(&uncompressed)
    }

    /// Decodes uncompressed columnar block bytes.
    #[allow(clippy::too_many_lines)]
    pub fn decode_uncompressed(data: &[u8]) -> Result<Vec<SegmentEvent>, SegmentBlockError> {
        if data.len() < 4 {
            return Err(SegmentBlockError::Truncated);
        }
        let event_count = u32::from_le_bytes([data[0], data[1], data[2], data[3]]) as usize;
        if event_count > MAX_EVENT_COUNT {
            return Err(SegmentBlockError::InvalidHeader(format!(
                "event_count {event_count} exceeds maximum {MAX_EVENT_COUNT}"
            )));
        }
        if event_count == 0 {
            if data.len() != 4 {
                return Err(SegmentBlockError::InvalidHeader(
                    "trailing bytes after zero-event block".to_owned(),
                ));
            }
            return Ok(Vec::new());
        }

        let n = event_count;
        let fixed_total = 4 + 34 * n;
        if data.len() < fixed_total {
            return Err(SegmentBlockError::Truncated);
        }

        let seq_off = 4;
        let witnessed_off = seq_off + 8 * n;
        let indexed_off = witnessed_off + 8 * n;
        let kind_off = indexed_off + 8 * n;
        let col_len_off = kind_off + n;
        let did_len_off = col_len_off + n;
        let rkey_len_off = did_len_off + 2 * n;
        let rev_len_off = rkey_len_off + n;
        let event_len_off = rev_len_off + n;

        let mut total_col = 0usize;
        let mut total_did = 0usize;
        let mut total_rkey = 0usize;
        let mut total_rev = 0usize;
        let mut total_payload = 0usize;

        for i in 0..n {
            let kind = data[kind_off + i];
            if !(1..=7).contains(&kind) {
                return Err(SegmentBlockError::InvalidHeader(format!(
                    "invalid event kind: {kind}"
                )));
            }
            total_col = total_col
                .checked_add(usize::from(data[col_len_off + i]))
                .ok_or(SegmentBlockError::Truncated)?;
            total_did = total_did
                .checked_add(usize::from(u16::from_le_bytes([
                    data[did_len_off + 2 * i],
                    data[did_len_off + 2 * i + 1],
                ])))
                .ok_or(SegmentBlockError::Truncated)?;
            total_rkey = total_rkey
                .checked_add(usize::from(data[rkey_len_off + i]))
                .ok_or(SegmentBlockError::Truncated)?;
            total_rev = total_rev
                .checked_add(usize::from(data[rev_len_off + i]))
                .ok_or(SegmentBlockError::Truncated)?;
            let plen = usize::try_from(u32::from_le_bytes([
                data[event_len_off + 4 * i],
                data[event_len_off + 4 * i + 1],
                data[event_len_off + 4 * i + 2],
                data[event_len_off + 4 * i + 3],
            ]))
            .map_err(|_| SegmentBlockError::Truncated)?;
            total_payload = total_payload
                .checked_add(plen)
                .ok_or(SegmentBlockError::Truncated)?;
        }

        let expected_total = [total_col, total_did, total_rkey, total_rev, total_payload]
            .into_iter()
            .try_fold(fixed_total, usize::checked_add)
            .ok_or(SegmentBlockError::Truncated)?;
        if data.len() < expected_total {
            return Err(SegmentBlockError::Truncated);
        }
        if data.len() != expected_total {
            return Err(SegmentBlockError::InvalidHeader(format!(
                "trailing bytes after var region: expected {expected_total}, got {}",
                data.len()
            )));
        }

        let mut cur_col = fixed_total;
        let mut cur_did = cur_col + total_col;
        let mut cur_rkey = cur_did + total_did;
        let mut cur_rev = cur_rkey + total_rkey;
        let mut cur_payload = cur_rev + total_rev;

        let mut events = Vec::with_capacity(n);
        for i in 0..n {
            let seq = read_i64_le(data, seq_off + 8 * i);
            let witnessed_at_us = read_i64_le(data, witnessed_off + 8 * i);
            let indexed_at_us = read_i64_le(data, indexed_off + 8 * i);
            let kind = data[kind_off + i];

            let col_len = usize::from(data[col_len_off + i]);
            let did_len = usize::from(u16::from_le_bytes([
                data[did_len_off + 2 * i],
                data[did_len_off + 2 * i + 1],
            ]));
            let rkey_len = usize::from(data[rkey_len_off + i]);
            let rev_len = usize::from(data[rev_len_off + i]);
            let event_len = u32::from_le_bytes([
                data[event_len_off + 4 * i],
                data[event_len_off + 4 * i + 1],
                data[event_len_off + 4 * i + 2],
                data[event_len_off + 4 * i + 3],
            ]) as usize;

            let collection =
                String::from_utf8_lossy(&data[cur_col..cur_col + col_len]).into_owned();
            cur_col += col_len;

            let did = String::from_utf8_lossy(&data[cur_did..cur_did + did_len]).into_owned();
            cur_did += did_len;

            let rkey = String::from_utf8_lossy(&data[cur_rkey..cur_rkey + rkey_len]).into_owned();
            cur_rkey += rkey_len;

            let rev = String::from_utf8_lossy(&data[cur_rev..cur_rev + rev_len]).into_owned();
            cur_rev += rev_len;

            let payload = if event_len > 0 {
                let slice = data[cur_payload..cur_payload + event_len].to_vec();
                cur_payload += event_len;
                slice
            } else {
                Vec::new()
            };

            events.push(SegmentEvent {
                seq,
                witnessed_at_us,
                indexed_at_us,
                kind,
                collection,
                did,
                rkey,
                rev,
                payload,
            });
        }

        Ok(events)
    }
}

fn read_i64_le(data: &[u8], off: usize) -> i64 {
    i64::from_le_bytes([
        data[off],
        data[off + 1],
        data[off + 2],
        data[off + 3],
        data[off + 4],
        data[off + 5],
        data[off + 6],
        data[off + 7],
    ])
}

fn parse_jss_header(header: &[u8]) -> Result<(usize, usize), SegmentBlockError> {
    if header.len() != JSS_HEADER_LEN {
        return Err(SegmentBlockError::Truncated);
    }
    if header[0..4] != JSS_MAGIC {
        return Err(SegmentBlockError::BadMagic);
    }
    let checksum = u64::from_le_bytes(header[4..12].try_into().unwrap_or([0; 8]));
    if checksum == 0 {
        return Err(SegmentBlockError::NotSealed);
    }
    let version = u16::from_le_bytes([header[12], header[13]]);
    if version != 1 {
        return Err(SegmentBlockError::UnsupportedVersion(version));
    }
    let block_count = u32::from_le_bytes([header[14], header[15], header[16], header[17]]) as usize;
    let footer_offset = u64::from_le_bytes(header[58..66].try_into().unwrap_or([0; 8]));
    if footer_offset < JSS_HEADER_LEN as u64 {
        return Err(SegmentBlockError::InvalidHeader(format!(
            "footer_offset {footer_offset} < {JSS_HEADER_LEN}"
        )));
    }
    let footer_offset = usize::try_from(footer_offset).map_err(|_| SegmentBlockError::Truncated)?;
    Ok((block_count, footer_offset))
}

/// Sequential `.jss0` archive reader over an in-memory byte slice (native and `wasm32`).
#[derive(Debug, Clone)]
pub struct SegmentBytesReader<'a> {
    pub block_count: usize,
    data: &'a [u8],
    footer_offset: usize,
    offset: usize,
}

impl<'a> SegmentBytesReader<'a> {
    /// Parses a `.jss0` segment header and prepares sequential block iteration.
    pub fn new(data: &'a [u8]) -> Result<Self, SegmentBlockError> {
        if data.len() < JSS_HEADER_LEN {
            return Err(SegmentBlockError::Truncated);
        }
        let (block_count, footer_offset) = parse_jss_header(&data[..JSS_HEADER_LEN])?;
        if footer_offset > data.len() {
            return Err(SegmentBlockError::Truncated);
        }
        Ok(Self {
            block_count,
            data,
            footer_offset,
            offset: JSS_HEADER_LEN,
        })
    }

    /// Reads and decodes the next zstd-compressed block (`None` at `footer_offset`).
    pub fn next_block(&mut self) -> Result<Option<Vec<SegmentEvent>>, SegmentBlockError> {
        if self.offset >= self.footer_offset {
            return Ok(None);
        }
        if self.offset + 8 > self.footer_offset {
            return Err(SegmentBlockError::Truncated);
        }
        let len_u64 = u64::from_le_bytes(
            self.data[self.offset..self.offset + 8]
                .try_into()
                .unwrap_or([0; 8]),
        );
        let compressed_len = usize::try_from(len_u64).map_err(|_| SegmentBlockError::Truncated)?;
        let end = self
            .offset
            .checked_add(8)
            .and_then(|s| s.checked_add(compressed_len))
            .ok_or(SegmentBlockError::Truncated)?;
        if end > self.footer_offset {
            return Err(SegmentBlockError::Truncated);
        }
        let frame = &self.data[self.offset + 8..end];
        self.offset = end;
        SegmentBlockDecoder::decode_frame(frame).map(Some)
    }
}

/// Sequential `.jss0` archive segment file reader (native targets).
#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug)]
pub struct SegmentFileReader {
    pub block_count: usize,
    file: File,
    footer_offset: u64,
    offset: u64,
}

#[cfg(not(target_arch = "wasm32"))]
impl SegmentFileReader {
    /// Opens a `.jss0` file and validates its 256-byte header.
    pub fn open(path: impl AsRef<Path>) -> Result<Self, SegmentBlockError> {
        let mut file = File::open(path).map_err(|e| SegmentBlockError::Io(e.to_string()))?;
        let file_len = file
            .metadata()
            .map_err(|e| SegmentBlockError::Io(e.to_string()))?
            .len();
        let mut header = [0_u8; JSS_HEADER_LEN];
        file.read_exact(&mut header)
            .map_err(|_| SegmentBlockError::Truncated)?;
        let (block_count, footer_offset) = parse_jss_header(&header)?;
        if (footer_offset as u64) > file_len {
            return Err(SegmentBlockError::Truncated);
        }
        Ok(Self {
            block_count,
            file,
            footer_offset: footer_offset as u64,
            offset: JSS_HEADER_LEN as u64,
        })
    }

    /// Reads and decodes the next zstd-compressed block (`None` at `footer_offset`).
    pub fn next_block(&mut self) -> Result<Option<Vec<SegmentEvent>>, SegmentBlockError> {
        if self.offset >= self.footer_offset {
            return Ok(None);
        }
        if self.offset + 8 > self.footer_offset {
            return Err(SegmentBlockError::Truncated);
        }
        let file_len = self
            .file
            .metadata()
            .map_err(|e| SegmentBlockError::Io(e.to_string()))?
            .len();
        self.file
            .seek(SeekFrom::Start(self.offset))
            .map_err(|e| SegmentBlockError::Io(e.to_string()))?;
        let mut len_buf = [0_u8; 8];
        self.file
            .read_exact(&mut len_buf)
            .map_err(|_| SegmentBlockError::Truncated)?;
        let compressed_len = u64::from_le_bytes(len_buf);
        let end = self
            .offset
            .checked_add(8)
            .and_then(|s| s.checked_add(compressed_len))
            .ok_or(SegmentBlockError::Truncated)?;
        if end > self.footer_offset || end > file_len {
            return Err(SegmentBlockError::Truncated);
        }
        let len_usize =
            usize::try_from(compressed_len).map_err(|_| SegmentBlockError::Truncated)?;
        let mut frame = Vec::with_capacity(len_usize.min(64 * 1024));
        let read_bytes = self
            .file
            .by_ref()
            .take(compressed_len)
            .read_to_end(&mut frame)
            .map_err(|_| SegmentBlockError::Truncated)?;
        if u64::try_from(read_bytes).ok() != Some(compressed_len) {
            return Err(SegmentBlockError::Truncated);
        }
        self.offset = end;
        SegmentBlockDecoder::decode_frame(&frame).map(Some)
    }
}
