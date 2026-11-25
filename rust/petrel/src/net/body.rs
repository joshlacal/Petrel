//! Native HTTP content decoding after the transport has bounded the wire body.

use std::io::{self, Read};

use bytes::Bytes;
use flate2::read::{DeflateDecoder, MultiGzDecoder, ZlibDecoder};
use http::{HeaderMap, header::CONTENT_ENCODING};
use thiserror::Error;

#[derive(Debug, Error)]
pub(super) enum DecodeError {
    #[error("unsupported HTTP content encoding")]
    Unsupported,
    #[error("HTTP content decoding failed")]
    Invalid(#[source] io::Error),
    #[error("decoded HTTP body exceeded the response limits")]
    TooLarge,
}

pub(super) fn decode(
    wire: Bytes,
    headers: &HeaderMap,
    decoded_limit: usize,
    max_expansion_ratio: usize,
) -> Result<Bytes, DecodeError> {
    let mut encodings = headers.get_all(CONTENT_ENCODING).iter();
    let Some(encoding) = encodings.next() else {
        return uncompressed(wire, decoded_limit);
    };
    if encodings.next().is_some() {
        return Err(DecodeError::Unsupported);
    }

    match encoding
        .to_str()
        .map_err(|_| DecodeError::Unsupported)?
        .trim()
        .to_ascii_lowercase()
        .as_str()
    {
        "identity" => uncompressed(wire, decoded_limit),
        encoding => {
            let limit = decoded_limit.min(wire.len().saturating_mul(max_expansion_ratio));
            match encoding {
                "gzip" => read_decoded(MultiGzDecoder::new(wire.as_ref()), limit),
                "deflate" if is_zlib(&wire) => read_decoded(ZlibDecoder::new(wire.as_ref()), limit),
                "deflate" => read_decoded(DeflateDecoder::new(wire.as_ref()), limit),
                "br" => read_decoded(brotli::Decompressor::new(wire.as_ref(), 4096), limit),
                _ => Err(DecodeError::Unsupported),
            }
        }
    }
}

fn uncompressed(wire: Bytes, limit: usize) -> Result<Bytes, DecodeError> {
    if wire.len() > limit {
        Err(DecodeError::TooLarge)
    } else {
        Ok(wire)
    }
}

fn is_zlib(wire: &[u8]) -> bool {
    let [method, flags, ..] = wire else {
        return false;
    };
    method & 0x0f == 8 && u16::from_be_bytes([*method, *flags]) % 31 == 0
}

fn read_decoded(reader: impl Read, limit: usize) -> Result<Bytes, DecodeError> {
    let mut output = Vec::new();
    reader
        .take(u64::try_from(limit.saturating_add(1)).unwrap_or(u64::MAX))
        .read_to_end(&mut output)
        .map_err(DecodeError::Invalid)?;
    if output.len() > limit {
        return Err(DecodeError::TooLarge);
    }
    Ok(output.into())
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use flate2::{Compression, write::GzEncoder};
    use http::HeaderValue;

    use super::*;

    #[test]
    fn enforces_exact_decoded_length_and_expansion_limits() {
        let clear = vec![b'a'; 4096];
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(&clear).unwrap();
        let wire = Bytes::from(encoder.finish().unwrap());
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_ENCODING, HeaderValue::from_static("gzip"));

        assert!(matches!(
            decode(wire.clone(), &headers, 8192, 20),
            Err(DecodeError::TooLarge),
        ));
        assert!(matches!(
            decode(wire.clone(), &headers, 4095, 1000),
            Err(DecodeError::TooLarge),
        ));
        assert_eq!(decode(wire, &headers, 4096, 1000).unwrap(), clear);
    }

    #[test]
    fn rejects_unsupported_encoding_chains() {
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_ENCODING, HeaderValue::from_static("gzip, br"));
        assert!(matches!(
            decode(Bytes::new(), &headers, 64, 20),
            Err(DecodeError::Unsupported),
        ));
    }
}
