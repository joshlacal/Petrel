//! Portable lossless container metadata surgery for JPEG, PNG, WebP, and GIF.

use std::sync::LazyLock;

use super::ImageMetadataStrippingError;

/// Image container formats supported by lossless container rewriting.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Container {
    Jpeg,
    Png,
    WebP,
    Gif,
}

const PNG_SIGNATURE: [u8; 8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
const EXIF_HEADER: [u8; 6] = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];

const PNG_RENDERING_CHUNKS: &[&str] = &[
    "tRNS", "gAMA", "cHRM", "sRGB", "iCCP", "sBIT", "bKGD", "pHYs", "sPLT", "hIST", "cICP", "mDCV",
    "cLLI", "acTL", "fcTL", "fdAT",
];

const WEBP_RENDERING_CHUNKS: &[&str] = &["VP8X", "VP8 ", "VP8L", "ALPH", "ICCP", "ANIM", "ANMF"];

const GIF_RENDERING_APPLICATIONS: &[&[u8; 11]] = &[b"NETSCAPE2.0", b"ANIMEXTS1.0", b"ICCRGBG1012"];

static CRC_TABLE: LazyLock<[u32; 256]> = LazyLock::new(|| {
    let mut table = [0_u32; 256];
    for (idx, slot) in table.iter_mut().enumerate() {
        let mut crc = u32::try_from(idx).unwrap_or(0);
        for _ in 0..8 {
            crc = if crc & 1 == 1 {
                0xEDB8_8320 ^ (crc >> 1)
            } else {
                crc >> 1
            };
        }
        *slot = crc;
    }
    table
});

/// Portable lossless metadata surgery across JPEG, PNG, WebP, and GIF containers.
#[derive(Debug, Clone, Copy, Default)]
pub struct ImageContainerSurgery;

impl ImageContainerSurgery {
    /// Recognizes a supported container from leading magic bytes.
    #[must_use]
    pub fn sniff(bytes: &[u8]) -> Option<Container> {
        if bytes.len() >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return Some(Container::Jpeg);
        }
        if bytes.len() >= 8 && bytes[..8] == PNG_SIGNATURE {
            return Some(Container::Png);
        }
        if bytes.len() >= 12 && &bytes[..4] == b"RIFF" && &bytes[8..12] == b"WEBP" {
            return Some(Container::WebP);
        }
        if bytes.len() >= 6 && (&bytes[..6] == b"GIF87a" || &bytes[..6] == b"GIF89a") {
            return Some(Container::Gif);
        }
        None
    }

    /// Rewrites `bytes` as `container`, removing metadata while preserving pixels,
    /// color profiles, transparency, animation, and display orientation (`2..=8`).
    pub fn strip(
        bytes: &[u8],
        container: Container,
    ) -> Result<Vec<u8>, ImageMetadataStrippingError> {
        match container {
            Container::Jpeg => Self::strip_jpeg(bytes),
            Container::Png => Self::strip_png(bytes),
            Container::WebP => Self::strip_webp(bytes),
            Container::Gif => Self::strip_gif(bytes),
        }
    }

    /// Extracts EXIF display orientation (`2..=8`) from a raw TIFF header/IFD0 block.
    #[must_use]
    pub fn display_orientation(tiff: &[u8]) -> Option<u16> {
        if tiff.len() < 8 {
            return None;
        }
        let little_endian = match &tiff[..2] {
            b"II" => true,
            b"MM" => false,
            _ => return None,
        };
        let u16_at = |offset: usize| -> Option<u16> {
            let slice = tiff.get(offset..offset + 2)?;
            let arr = [slice[0], slice[1]];
            Some(if little_endian {
                u16::from_le_bytes(arr)
            } else {
                u16::from_be_bytes(arr)
            })
        };
        let u32_at = |offset: usize| -> Option<usize> {
            let slice = tiff.get(offset..offset + 4)?;
            let arr = [slice[0], slice[1], slice[2], slice[3]];
            let val = if little_endian {
                u32::from_le_bytes(arr)
            } else {
                u32::from_be_bytes(arr)
            };
            usize::try_from(val).ok()
        };

        if u16_at(2)? != 42 {
            return None;
        }
        let directory = u32_at(4)?;
        let entry_count = usize::from(u16_at(directory)?);
        for entry in 0..entry_count {
            let offset = directory
                .checked_add(2)?
                .checked_add(entry.checked_mul(12)?)?;
            let tag = u16_at(offset)?;
            if tag != 0x0112 {
                continue;
            }
            if u16_at(offset + 2) != Some(3) || u32_at(offset + 4) != Some(1) {
                return None;
            }
            let value = u16_at(offset + 8)?;
            if (2..=8).contains(&value) {
                return Some(value);
            }
            return None;
        }
        None
    }

    /// Builds a 26-byte big-endian TIFF block containing only EXIF Orientation `orientation`.
    #[must_use]
    pub fn orientation_only_tiff(orientation: u16) -> Vec<u8> {
        let [high, low] = orientation.to_be_bytes();
        vec![
            0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // MM, 42, IFD0 @ 8
            0x00, 0x01, // 1 entry
            0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, high, low, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, // no next IFD
        ]
    }

    /// Computes ISO 3309 CRC-32 as used by PNG chunks.
    #[must_use]
    pub fn crc32(bytes: &[u8]) -> u32 {
        let table = &*CRC_TABLE;
        let mut crc = 0xFFFF_FFFF_u32;
        for &byte in bytes {
            let idx = u8::try_from((crc ^ u32::from(byte)) & 0xFF).unwrap_or(0);
            crc = table[usize::from(idx)] ^ (crc >> 8);
        }
        crc ^ 0xFFFF_FFFF
    }

    /// Losslessly strips metadata segments from a JPEG stream.
    pub fn strip_jpeg(bytes: &[u8]) -> Result<Vec<u8>, ImageMetadataStrippingError> {
        let malformed = ImageMetadataStrippingError::MalformedImage;
        if bytes.len() < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8 {
            return Err(malformed);
        }
        let mut output = Vec::with_capacity(bytes.len());
        output.extend_from_slice(&[0xFF, 0xD8]);
        let mut index = 2_usize;
        let mut saw_scan = false;
        let mut kept_orientation = false;

        loop {
            if index >= bytes.len() || bytes[index] != 0xFF {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            while index < bytes.len() && bytes[index] == 0xFF {
                index += 1;
            }
            if index >= bytes.len() {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let marker = bytes[index];
            index += 1;

            match marker {
                0xD9 => {
                    if !saw_scan {
                        return Err(ImageMetadataStrippingError::MalformedImage);
                    }
                    output.extend_from_slice(&[0xFF, 0xD9]);
                    return Ok(output);
                }
                0x00 | 0xD8 => return Err(ImageMetadataStrippingError::MalformedImage),
                0x01 | 0xD0..=0xD7 => {
                    output.extend_from_slice(&[0xFF, marker]);
                    continue;
                }
                _ => {}
            }

            if index + 2 > bytes.len() {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let length = (usize::from(bytes[index]) << 8) | usize::from(bytes[index + 1]);
            if length < 2 || index + length > bytes.len() {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let payload = &bytes[index + 2..index + length];
            index += length;

            if let Some(kept) = kept_jpeg_segment(marker, payload, &mut kept_orientation) {
                let seg_len = u16::try_from(kept.len() + 2)
                    .map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
                output.push(0xFF);
                output.push(marker);
                output.extend_from_slice(&seg_len.to_be_bytes());
                output.extend_from_slice(&kept);
            }

            if marker != 0xDA {
                continue;
            }
            saw_scan = true;
            let scan_start = index;
            loop {
                if index >= bytes.len() {
                    return Err(ImageMetadataStrippingError::MalformedImage);
                }
                if bytes[index] != 0xFF {
                    index += 1;
                    continue;
                }
                if index + 1 >= bytes.len() {
                    return Err(ImageMetadataStrippingError::MalformedImage);
                }
                let next = bytes[index + 1];
                if next == 0x00 || (0xD0..=0xD7).contains(&next) {
                    index += 2;
                } else if next == 0xFF {
                    index += 1;
                } else {
                    break;
                }
            }
            output.extend_from_slice(&bytes[scan_start..index]);
        }
    }

    /// Losslessly strips metadata chunks from a PNG stream.
    pub fn strip_png(bytes: &[u8]) -> Result<Vec<u8>, ImageMetadataStrippingError> {
        if bytes.len() < 8 || bytes[..8] != PNG_SIGNATURE {
            return Err(ImageMetadataStrippingError::MalformedImage);
        }
        let mut output = Vec::with_capacity(bytes.len());
        output.extend_from_slice(&PNG_SIGNATURE);
        let mut index = 8_usize;
        let mut is_first = true;
        let mut kept_orientation = false;

        loop {
            if index + 12 > bytes.len() {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let len_u32 = u32::from_be_bytes([
                bytes[index],
                bytes[index + 1],
                bytes[index + 2],
                bytes[index + 3],
            ]);
            let length = usize::try_from(len_u32)
                .map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
            if length > bytes.len() - index - 12 {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let type_bytes = &bytes[index + 4..index + 8];
            if !type_bytes.iter().all(u8::is_ascii_alphabetic) {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let chunk_type = std::str::from_utf8(type_bytes)
                .map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
            let data_range = (index + 8)..(index + 8 + length);
            let chunk_range = index..(index + 12 + length);
            index = chunk_range.end;

            if is_first {
                if chunk_type != "IHDR" || length != 13 {
                    return Err(ImageMetadataStrippingError::MalformedImage);
                }
                is_first = false;
            }

            let is_critical = (type_bytes[0] & 0x20) == 0;
            if is_critical || PNG_RENDERING_CHUNKS.contains(&chunk_type) {
                output.extend_from_slice(&bytes[chunk_range]);
            } else if chunk_type == "eXIf"
                && !kept_orientation
                && let Some(orientation) = Self::display_orientation(&bytes[data_range])
            {
                kept_orientation = true;
                let mut type_and_data = type_bytes.to_vec();
                type_and_data.extend_from_slice(&Self::orientation_only_tiff(orientation));
                let new_len = u32::try_from(type_and_data.len() - 4)
                    .map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
                output.extend_from_slice(&new_len.to_be_bytes());
                output.extend_from_slice(&type_and_data);
                output.extend_from_slice(&Self::crc32(&type_and_data).to_be_bytes());
            }

            if chunk_type == "IEND" {
                return Ok(output);
            }
        }
    }

    /// Losslessly strips metadata chunks from a RIFF/WebP stream.
    pub fn strip_webp(bytes: &[u8]) -> Result<Vec<u8>, ImageMetadataStrippingError> {
        if bytes.len() < 12 || &bytes[..4] != b"RIFF" || &bytes[8..12] != b"WEBP" {
            return Err(ImageMetadataStrippingError::MalformedImage);
        }
        let riff_size =
            usize::try_from(u32::from_le_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]))
                .map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
        if riff_size < 4 || riff_size > bytes.len() - 8 {
            return Err(ImageMetadataStrippingError::MalformedImage);
        }
        let end = 8 + riff_size;

        let mut chunks: Vec<([u8; 4], Vec<u8>)> = Vec::new();
        let mut has_image = false;
        let mut has_extended_header = false;
        let mut kept_orientation = false;
        let mut index = 12_usize;

        while index < end {
            if index + 8 > end {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let four_cc = [
                bytes[index],
                bytes[index + 1],
                bytes[index + 2],
                bytes[index + 3],
            ];
            let size = usize::try_from(u32::from_le_bytes([
                bytes[index + 4],
                bytes[index + 5],
                bytes[index + 6],
                bytes[index + 7],
            ]))
            .map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
            if size > end - index - 8 {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            let payload = &bytes[index + 8..index + 8 + size];
            let padded_size = size
                .checked_add(size % 2)
                .ok_or(ImageMetadataStrippingError::MalformedImage)?;
            index = index
                .checked_add(8 + padded_size)
                .ok_or(ImageMetadataStrippingError::MalformedImage)?;

            let name = String::from_utf8_lossy(&four_cc);
            if WEBP_RENDERING_CHUNKS.contains(&name.as_ref()) {
                if name == "VP8X" {
                    if size < 10 || !chunks.is_empty() {
                        return Err(ImageMetadataStrippingError::MalformedImage);
                    }
                    has_extended_header = true;
                } else if matches!(name.as_ref(), "VP8 " | "VP8L" | "ANMF") {
                    has_image = true;
                }
                chunks.push((four_cc, payload.to_vec()));
            } else if name == "EXIF" && has_extended_header && !kept_orientation {
                let tiff = payload.strip_prefix(&EXIF_HEADER).unwrap_or(payload);
                if let Some(orientation) = Self::display_orientation(tiff) {
                    kept_orientation = true;
                    chunks.push((four_cc, Self::orientation_only_tiff(orientation)));
                }
            }
        }

        if !has_image {
            return Err(ImageMetadataStrippingError::MalformedImage);
        }

        if has_extended_header {
            chunks[0].1[0] &= !0x04;
            if !kept_orientation {
                chunks[0].1[0] &= !0x08;
            }
        }

        let mut body = Vec::with_capacity(riff_size);
        body.extend_from_slice(b"WEBP");
        for (four_cc, payload) in chunks {
            let size = u32::try_from(payload.len())
                .map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
            body.extend_from_slice(&four_cc);
            body.extend_from_slice(&size.to_le_bytes());
            body.extend_from_slice(&payload);
            if payload.len() % 2 == 1 {
                body.push(0);
            }
        }
        let body_len =
            u32::try_from(body.len()).map_err(|_| ImageMetadataStrippingError::MalformedImage)?;
        let mut output = Vec::with_capacity(8 + body.len());
        output.extend_from_slice(b"RIFF");
        output.extend_from_slice(&body_len.to_le_bytes());
        output.extend_from_slice(&body);
        Ok(output)
    }

    /// Losslessly strips metadata blocks from a GIF87a/GIF89a stream.
    pub fn strip_gif(bytes: &[u8]) -> Result<Vec<u8>, ImageMetadataStrippingError> {
        if bytes.len() < 13 || Self::sniff(bytes) != Some(Container::Gif) {
            return Err(ImageMetadataStrippingError::MalformedImage);
        }
        let color_table_size = |packed: u8| -> usize {
            if packed & 0x80 == 0 {
                0
            } else {
                3_usize << (usize::from(packed & 0x07) + 1)
            }
        };
        let end_of_sub_blocks = |start: usize| -> Result<usize, ImageMetadataStrippingError> {
            let mut idx = start;
            loop {
                if idx >= bytes.len() {
                    return Err(ImageMetadataStrippingError::MalformedImage);
                }
                let size = usize::from(bytes[idx]);
                idx += 1;
                if size == 0 {
                    return Ok(idx);
                }
                if size > bytes.len() - idx {
                    return Err(ImageMetadataStrippingError::MalformedImage);
                }
                idx += size;
            }
        };

        let mut index = 13 + color_table_size(bytes[10]);
        if index > bytes.len() {
            return Err(ImageMetadataStrippingError::MalformedImage);
        }
        let mut output = Vec::with_capacity(bytes.len());
        output.extend_from_slice(&bytes[..index]);

        loop {
            if index >= bytes.len() {
                return Err(ImageMetadataStrippingError::MalformedImage);
            }
            match bytes[index] {
                0x3B => {
                    output.push(0x3B);
                    return Ok(output);
                }
                0x2C => {
                    if index + 10 > bytes.len() {
                        return Err(ImageMetadataStrippingError::MalformedImage);
                    }
                    let data_start = index + 10 + color_table_size(bytes[index + 9]) + 1;
                    if data_start > bytes.len() {
                        return Err(ImageMetadataStrippingError::MalformedImage);
                    }
                    let block_end = end_of_sub_blocks(data_start)?;
                    output.extend_from_slice(&bytes[index..block_end]);
                    index = block_end;
                }
                0x21 => {
                    if index + 2 >= bytes.len() {
                        return Err(ImageMetadataStrippingError::MalformedImage);
                    }
                    let label = bytes[index + 1];
                    let block_end = end_of_sub_blocks(index + 2)?;
                    let keep = match label {
                        0xF9 | 0x01 => true,
                        0xFF => {
                            bytes[index + 2] == 11
                                && index + 14 <= bytes.len()
                                && GIF_RENDERING_APPLICATIONS
                                    .iter()
                                    .any(|app| &bytes[index + 3..index + 14] == app.as_slice())
                        }
                        _ => false,
                    };
                    if keep {
                        output.extend_from_slice(&bytes[index..block_end]);
                    }
                    index = block_end;
                }
                _ => return Err(ImageMetadataStrippingError::MalformedImage),
            }
        }
    }
}

fn kept_jpeg_segment(marker: u8, payload: &[u8], kept_orientation: &mut bool) -> Option<Vec<u8>> {
    match marker {
        0xE0 => {
            if !payload.starts_with(b"JFIF\0") || payload.len() < 14 {
                return None;
            }
            let mut header = payload[..12].to_vec();
            header.extend_from_slice(&[0, 0]);
            Some(header)
        }
        0xE1 => {
            let tiff = payload.strip_prefix(&EXIF_HEADER)?;
            if *kept_orientation {
                return None;
            }
            let orientation = ImageContainerSurgery::display_orientation(tiff)?;
            *kept_orientation = true;
            let mut exif = EXIF_HEADER.to_vec();
            exif.extend_from_slice(&ImageContainerSurgery::orientation_only_tiff(orientation));
            Some(exif)
        }
        0xE2 => payload
            .starts_with(b"ICC_PROFILE\0")
            .then(|| payload.to_vec()),
        0xEE => payload.starts_with(b"Adobe").then(|| payload.to_vec()),
        0xE3..=0xED | 0xEF | 0xFE => None,
        _ => Some(payload.to_vec()),
    }
}
