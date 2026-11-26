//! Pure-Rust zstd compression/decompression via `ruzstd` (works identically on native and `wasm32`).

use std::io::Read;

use ruzstd::decoding::{Dictionary, FrameDecoder};
use ruzstd::encoding::{CompressionLevel, FrameCompressor};

/// Little-endian zstd frame magic (`0xFD2FB528`).
pub(crate) const ZSTD_FRAME_MAGIC: [u8; 4] = [0x28, 0xB5, 0x2F, 0xFD];
/// Little-endian zstd dictionary magic (`0xEC30A437`).
const ZSTD_DICT_MAGIC: [u8; 4] = [0x37, 0xA4, 0x30, 0xEC];

/// Default maximum decompressed bytes for standalone zstd segment blocks (16 MiB).
pub const DEFAULT_MAX_STANDALONE_BYTES: usize = 16 * 1024 * 1024;
/// Default maximum decompressed bytes for dictionary-compressed WebSocket frames (8 MiB).
pub const DEFAULT_MAX_DICT_FRAME_BYTES: usize = 8 * 1024 * 1024;
/// Maximum allowed zstd dictionary blob size (4 MiB).
pub const DEFAULT_MAX_DICTIONARY_BYTES: usize = 4 * 1024 * 1024;

/// Errors produced by Jetstream zstd operations.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum JetstreamZstdError {
    #[error("zstd decompression failed: {0}")]
    DecompressionFailed(String),
    #[error("zstd compression failed: {0}")]
    CompressionFailed(String),
    #[error("invalid zstd frame")]
    InvalidFrame,
    #[error("zstd frame declared {declared} bytes, exceeding limit {limit}")]
    FrameTooLarge { declared: u64, limit: usize },
    #[error("failed to load zstd dictionary")]
    DictionaryLoadFailed,
}

/// Standalone zstd decompression and compression (no C dependencies, identical on native & `wasm32`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct JetstreamZstd;

impl JetstreamZstd {
    /// Decompresses one standalone zstd frame (bounded by `DEFAULT_MAX_STANDALONE_BYTES`).
    pub fn decompress(frame: &[u8]) -> Result<Vec<u8>, JetstreamZstdError> {
        Self::decompress_with_limit(frame, DEFAULT_MAX_STANDALONE_BYTES)
    }

    /// Decompresses one standalone zstd frame, bounding decompressed size to `max_decompressed_size`.
    pub fn decompress_with_limit(
        frame: &[u8],
        max_decompressed_size: usize,
    ) -> Result<Vec<u8>, JetstreamZstdError> {
        if frame.len() < 4 || frame[..4] != ZSTD_FRAME_MAGIC {
            return Err(JetstreamZstdError::InvalidFrame);
        }
        let declared_fcs = parse_frame_content_size(frame)?;
        if let Some(declared) = declared_fcs
            && declared > max_decompressed_size as u64
        {
            return Err(JetstreamZstdError::FrameTooLarge {
                declared,
                limit: max_decompressed_size,
            });
        }

        let mut decoder = FrameDecoder::new();
        let mut slice = frame;
        decoder
            .init(&mut slice)
            .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;

        let initial_cap = declared_fcs
            .and_then(|n| usize::try_from(n).ok())
            .unwrap_or(0)
            .min(max_decompressed_size)
            .min(64 * 1024);
        let mut out = Vec::with_capacity(initial_cap);
        let mut chunk = [0_u8; 16 * 1024];

        while !decoder.is_finished() {
            decoder
                .decode_blocks(
                    &mut slice,
                    ruzstd::decoding::BlockDecodingStrategy::UptoBytes(128 * 1024),
                )
                .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;
            loop {
                let n = decoder
                    .read(&mut chunk)
                    .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;
                if n == 0 {
                    break;
                }
                if out.len().saturating_add(n) > max_decompressed_size {
                    return Err(JetstreamZstdError::FrameTooLarge {
                        declared: (out.len().saturating_add(n)) as u64,
                        limit: max_decompressed_size,
                    });
                }
                out.extend_from_slice(&chunk[..n]);
            }
        }
        // Drain any remaining buffered bytes after `is_finished()` becomes true.
        loop {
            let n = decoder
                .read(&mut chunk)
                .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;
            if n == 0 {
                break;
            }
            if out.len().saturating_add(n) > max_decompressed_size {
                return Err(JetstreamZstdError::FrameTooLarge {
                    declared: (out.len().saturating_add(n)) as u64,
                    limit: max_decompressed_size,
                });
            }
            out.extend_from_slice(&chunk[..n]);
        }

        Ok(out)
    }

    /// Compresses `data` as a standalone zstd frame (used by tests/fixtures on both native & `wasm32`).
    pub fn compress(data: &[u8]) -> Result<Vec<u8>, JetstreamZstdError> {
        let mut out = Vec::new();
        let mut compressor = FrameCompressor::new(CompressionLevel::Fastest);
        compressor.set_source(data);
        compressor.set_drain(&mut out);
        compressor.compress();
        Ok(out)
    }

    /// Reads the little-endian dictionary ID embedded in a structured zstd dictionary blob (`None`
    /// for raw-content dictionaries or ID 0).
    pub fn dictionary_id(dictionary: &[u8]) -> Option<u32> {
        if dictionary.len() < 8 || dictionary[..4] != ZSTD_DICT_MAGIC {
            return None;
        }
        let id = u32::from_le_bytes([dictionary[4], dictionary[5], dictionary[6], dictionary[7]]);
        (id != 0).then_some(id)
    }
}

/// Parses a dictionary blob (either structured zstd dictionary or raw-content dictionary).
#[derive(Debug, Clone)]
pub struct JetstreamZstdDictionaryDecoder {
    dict_id: u32,
    normalized_dict_bytes: Vec<u8>,
    max_decompressed_size: usize,
}

impl JetstreamZstdDictionaryDecoder {
    /// Builds a dictionary decoder from either a structured zstd dictionary (`0xEC30A437` header)
    /// or a raw-content byte slice.
    pub fn new(dictionary: &[u8]) -> Result<Self, JetstreamZstdError> {
        Self::with_max_size(dictionary, DEFAULT_MAX_DICT_FRAME_BYTES)
    }

    /// Builds a dictionary decoder with an explicit decompressed frame byte limit.
    pub fn with_max_size(
        dictionary: &[u8],
        max_decompressed_size: usize,
    ) -> Result<Self, JetstreamZstdError> {
        if dictionary.is_empty() || dictionary.len() > DEFAULT_MAX_DICTIONARY_BYTES {
            return Err(JetstreamZstdError::DictionaryLoadFailed);
        }

        let (normalized_dict_bytes, dict_id) =
            if dictionary.len() >= 4 && dictionary[..4] == ZSTD_DICT_MAGIC {
                let parsed = Dictionary::decode_dict(dictionary)
                    .map_err(|_| JetstreamZstdError::DictionaryLoadFailed)?;
                (dictionary.to_vec(), parsed.id)
            } else {
                // Raw-content dictionary: wrap with minimal valid zstd dictionary header + content so
                // `ruzstd` loads `dict_content` cleanly on both native and wasm32.
                const RAW_FALLBACK_DICT_ID: u32 = 1;
                let mut wrapped = Vec::with_capacity(28 + dictionary.len());
                wrapped.extend_from_slice(&ZSTD_DICT_MAGIC);
                wrapped.extend_from_slice(&RAW_FALLBACK_DICT_ID.to_le_bytes());
                // Minimal valid 2-byte Huffman direct-weights table (2 symbols, weights [1, 1]):
                wrapped.extend_from_slice(&[128, 0x10]);
                // Minimal valid 2-byte FSE table (accuracy_log = 5, 1 symbol prob = 32) for OF, ML, LL:
                wrapped.extend_from_slice(&[0xf0, 0x03]);
                wrapped.extend_from_slice(&[0xf0, 0x03]);
                wrapped.extend_from_slice(&[0xf0, 0x03]);
                // Default zstd repeat offsets (1, 4, 8):
                wrapped.extend_from_slice(&1_u32.to_le_bytes());
                wrapped.extend_from_slice(&4_u32.to_le_bytes());
                wrapped.extend_from_slice(&8_u32.to_le_bytes());
                wrapped.extend_from_slice(dictionary);

                let _ = Dictionary::decode_dict(&wrapped)
                    .map_err(|_| JetstreamZstdError::DictionaryLoadFailed)?;
                (wrapped, RAW_FALLBACK_DICT_ID)
            };

        Ok(Self {
            dict_id,
            normalized_dict_bytes,
            max_decompressed_size,
        })
    }

    /// Decompresses a single-shot zstd frame using this dictionary.
    pub fn decompress(&self, frame: &[u8]) -> Result<Vec<u8>, JetstreamZstdError> {
        if frame.len() < 5 || frame[..4] != ZSTD_FRAME_MAGIC {
            return Err(JetstreamZstdError::InvalidFrame);
        }
        let declared = parse_frame_content_size(frame)?.ok_or(JetstreamZstdError::InvalidFrame)?;
        if declared > self.max_decompressed_size as u64 {
            return Err(JetstreamZstdError::FrameTooLarge {
                declared,
                limit: self.max_decompressed_size,
            });
        }

        let dict = Dictionary::decode_dict(&self.normalized_dict_bytes)
            .map_err(|_| JetstreamZstdError::DictionaryLoadFailed)?;
        let mut decoder = FrameDecoder::new();
        decoder
            .add_dict(dict)
            .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;

        let mut slice = frame;
        decoder
            .init(&mut slice)
            .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;

        // Frames compressed with a raw-content dictionary omit Dictionary_ID_flag (`frame[4] & 3 == 0`).
        let dict_id_flag = frame[4] & 0x03;
        if dict_id_flag == 0 {
            decoder
                .force_dict(self.dict_id)
                .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;
        }

        let cap = usize::try_from(declared)
            .unwrap_or(0)
            .min(self.max_decompressed_size)
            .min(64 * 1024);
        let mut out = Vec::with_capacity(cap);
        let mut chunk = [0_u8; 16 * 1024];

        while !decoder.is_finished() {
            decoder
                .decode_blocks(
                    &mut slice,
                    ruzstd::decoding::BlockDecodingStrategy::UptoBytes(128 * 1024),
                )
                .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;
            loop {
                let n = decoder
                    .read(&mut chunk)
                    .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;
                if n == 0 {
                    break;
                }
                if out.len().saturating_add(n) > self.max_decompressed_size {
                    return Err(JetstreamZstdError::FrameTooLarge {
                        declared: (out.len().saturating_add(n)) as u64,
                        limit: self.max_decompressed_size,
                    });
                }
                out.extend_from_slice(&chunk[..n]);
            }
        }
        loop {
            let n = decoder
                .read(&mut chunk)
                .map_err(|e| JetstreamZstdError::DecompressionFailed(e.to_string()))?;
            if n == 0 {
                break;
            }
            if out.len().saturating_add(n) > self.max_decompressed_size {
                return Err(JetstreamZstdError::FrameTooLarge {
                    declared: (out.len().saturating_add(n)) as u64,
                    limit: self.max_decompressed_size,
                });
            }
            out.extend_from_slice(&chunk[..n]);
        }

        Ok(out)
    }
}

/// Checks zstd frame header to extract `Frame_Content_Size` if present (`None` when unknown).
fn parse_frame_content_size(frame: &[u8]) -> Result<Option<u64>, JetstreamZstdError> {
    if frame.len() < 5 || frame[..4] != ZSTD_FRAME_MAGIC {
        return Err(JetstreamZstdError::InvalidFrame);
    }
    let fhd = frame[4];
    // Reserved bit (bit 3) must be 0 per RFC 8878.
    if (fhd & 0x08) != 0 {
        return Err(JetstreamZstdError::InvalidFrame);
    }
    let fcs_flag = fhd >> 6;
    let single_segment = (fhd & 0x20) != 0;
    let dict_id_flag = fhd & 0x03;

    let fcs_len = match fcs_flag {
        0 => usize::from(single_segment),
        1 => 2,
        2 => 4,
        3 => 8,
        _ => return Err(JetstreamZstdError::InvalidFrame),
    };
    let dict_id_len = match dict_id_flag {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
        _ => return Err(JetstreamZstdError::InvalidFrame),
    };
    let window_len = usize::from(!single_segment);
    let offset = 5 + window_len + dict_id_len;
    if frame.len() < offset + fcs_len {
        return Err(JetstreamZstdError::InvalidFrame);
    }
    if fcs_len == 0 {
        return Ok(None);
    }
    let fcs_bytes = &frame[offset..offset + fcs_len];
    let mut val = 0_u64;
    for (i, &b) in fcs_bytes.iter().enumerate() {
        val |= u64::from(b) << (8 * i);
    }
    if fcs_len == 2 {
        val += 256;
    }
    Ok(Some(val))
}
