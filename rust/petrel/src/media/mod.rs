//! Media utilities: lossless container metadata stripping and blob upload validation.

mod surgery;

pub use surgery::{Container, ImageContainerSurgery};

use bytes::Bytes;

/// Why image metadata could not be stripped safely.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ImageMetadataStrippingError {
    /// Data is declared as an image format that this portable implementation cannot strip
    /// without an external codec (for example HEIC, HEIF, AVIF, or TIFF).
    #[error("metadata cannot be removed from {0} images on this platform")]
    UnsupportedImageFormat(String),
    /// Container framing is damaged, truncated, or does not match the declared container format.
    #[error("the image is malformed, so its metadata cannot be removed safely")]
    MalformedImage,
}

const CONTAINER_TYPES: &[&str] = &[
    "image/jpeg",
    "image/jpg",
    "image/pjpeg",
    "image/png",
    "image/apng",
    "image/webp",
    "image/gif",
];

/// Lossless metadata remover matching Swift `ImageMetadataStripper`.
///
/// - JPEG, PNG, WebP, and GIF are rewritten losslessly by stripping EXIF (retaining only
///   display orientation 2..=8 when needed), XMP, IPTC, comments, text chunks, and trailing bytes.
/// - Other `image/*` media types fail closed with [`ImageMetadataStrippingError::UnsupportedImageFormat`].
/// - Non-`image/*` data is returned unchanged.
#[derive(Debug, Clone, Copy, Default)]
pub struct ImageMetadataStripper;

impl ImageMetadataStripper {
    /// Strips metadata from `data` using the declared `mime_type`.
    pub fn strip_metadata(
        data: &[u8],
        mime_type: &str,
    ) -> Result<Bytes, ImageMetadataStrippingError> {
        let normalized = normalized_media_type(mime_type);
        if !normalized.starts_with("image/") {
            return Ok(Bytes::copy_from_slice(data));
        }
        if let Some(container) = ImageContainerSurgery::sniff(data) {
            return ImageContainerSurgery::strip(data, container).map(Bytes::from);
        }
        if CONTAINER_TYPES.contains(&normalized.as_str()) {
            return Err(ImageMetadataStrippingError::MalformedImage);
        }
        Err(ImageMetadataStrippingError::UnsupportedImageFormat(
            normalized,
        ))
    }

    /// Strips metadata when container format is recognized purely from leading bytes.
    /// Returns `None` if unrecognized or malformed.
    #[must_use]
    pub fn strip_sniffed(data: &[u8]) -> Option<Bytes> {
        let container = ImageContainerSurgery::sniff(data)?;
        ImageContainerSurgery::strip(data, container)
            .ok()
            .map(Bytes::from)
    }
}

fn normalized_media_type(mime_type: &str) -> String {
    mime_type
        .split(';')
        .next()
        .unwrap_or("")
        .trim()
        .to_ascii_lowercase()
}
