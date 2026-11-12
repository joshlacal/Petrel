//
//  ImageMetadataStripper.swift
//  Petrel
//
//  Created by Josh LaCalamito on 8/6/24.
//

import Foundation

#if canImport(ImageIO)
    import CoreGraphics
    import ImageIO
#endif
#if os(iOS) || os(macOS) || os(tvOS)
    import UniformTypeIdentifiers
#endif

/// Why image metadata could not be removed.
public enum ImageMetadataStrippingError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The data is declared as an image, but of a format this platform has no
    /// way to strip. Nothing was removed; do not upload it as if it were clean.
    /// The associated value is the media type that was declared.
    case unsupportedImageFormat(String)

    /// The data is declared as an image but its container is damaged,
    /// truncated or not what it claims to be.
    case malformedImage

    public var description: String {
        switch self {
        case let .unsupportedImageFormat(mimeType):
            return "Metadata cannot be removed from \(mimeType) images on this platform"
        case .malformedImage:
            return "The image is malformed, so its metadata cannot be removed safely"
        }
    }
}

/// Removes identifying metadata from images before they are uploaded.
///
/// Photos carry more than pixels: where they were taken (GPS), when, with
/// which device, sometimes the owner's name, and thumbnails of the picture
/// before it was cropped. ``stripMetadata(from:mimeType:)`` removes all of it
/// and keeps what is needed to show the image correctly: the pixels, the
/// colour profile and the orientation.
public class ImageMetadataStripper {
    /// The media types handled by lossless, pure-Swift container rewriting.
    private static let containerTypes: Set<String> = [
        "image/jpeg", "image/jpg", "image/pjpeg", "image/png", "image/apng", "image/webp", "image/gif",
    ]

    /// Removes metadata from image data, keeping its format.
    ///
    /// - JPEG, PNG, WebP and GIF are rewritten losslessly on every platform:
    ///   metadata blocks are left out and the compressed image data is copied
    ///   as it is, so the pixels do not change and nothing is re-encoded. The
    ///   container is recognised from the data itself, so a mislabelled image
    ///   of one of these formats is still stripped.
    /// - Other image types (HEIC, HEIF, AVIF, TIFF, …) are decoded and written
    ///   back in the same format by ImageIO on Apple platforms. Elsewhere they
    ///   are refused with ``ImageMetadataStrippingError/unsupportedImageFormat(_:)``.
    /// - Data whose media type is not `image/*` is returned unchanged.
    ///
    /// Removed: EXIF (including GPS and maker notes), XMP, IPTC, comments,
    /// text chunks, timestamps, embedded thumbnails and anything appended
    /// after the end of the image. Kept: pixels, ICC colour profile,
    /// transparency, animation, pixel density, and the orientation (as an
    /// EXIF block containing only that one value, when the image is rotated).
    ///
    /// The result always has the same media type as the input.
    ///
    /// - Parameters:
    ///   - data: The file contents.
    ///   - mimeType: The media type the data will be uploaded as. Matched
    ///     case-insensitively; parameters after `;` are ignored.
    /// - Returns: The data without metadata.
    /// - Throws: ``ImageMetadataStrippingError``. On any error nothing was
    ///   stripped and the data must be treated as still carrying metadata.
    public static func stripMetadata(from data: Data, mimeType: String) throws -> Data {
        let type = normalizedMediaType(mimeType)
        guard type.hasPrefix("image/") else { return data }

        let bytes = [UInt8](data)
        if let container = ImageContainerSurgery.sniff(bytes) {
            return try Data(ImageContainerSurgery.strip(bytes, as: container))
        }
        guard !containerTypes.contains(type) else {
            // Declared as a format we know how to walk, but the bytes are not that format.
            throw ImageMetadataStrippingError.malformedImage
        }
        #if canImport(ImageIO)
            return try reencodeWithoutMetadata(data, mimeType: type)
        #else
            throw ImageMetadataStrippingError.unsupportedImageFormat(type)
        #endif
    }

    /// Removes metadata from image data whose format is recognised from the data itself.
    ///
    /// JPEG, PNG, WebP and GIF are rewritten losslessly in their own format;
    /// other images are re-encoded in their own format by ImageIO on Apple
    /// platforms. Prefer ``stripMetadata(from:mimeType:)``, which reports why
    /// stripping failed and passes non-image data through.
    ///
    /// - Returns: The data without metadata, or `nil` when it is not an image
    ///   this platform can strip. `nil` means the metadata is still there.
    public static func stripMetadata(from imageData: Data) -> Data? {
        let bytes = [UInt8](imageData)
        if let container = ImageContainerSurgery.sniff(bytes) {
            guard let stripped = try? ImageContainerSurgery.strip(bytes, as: container) else {
                LogManager.logError("ImageMetadataStripper - Malformed image; metadata not removed")
                return nil
            }
            return Data(stripped)
        }
        #if canImport(ImageIO)
            guard let stripped = try? reencodeWithoutMetadata(imageData, mimeType: "image/*") else {
                LogManager.logError("ImageMetadataStripper - Could not re-encode image without metadata")
                return nil
            }
            return stripped
        #else
            // Fail closed: without ImageIO only the pure-Swift containers can be stripped.
            LogManager.logError("ImageMetadataStripper - Metadata stripping not available for this format on this platform")
            return nil
        #endif
    }

    private static func normalizedMediaType(_ mimeType: String) -> String {
        let essence = mimeType.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        return essence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    #if canImport(ImageIO)
        /// Decodes every frame and writes it back in the same format with no
        /// properties other than orientation.
        ///
        /// Nothing is copied from the source's metadata: the destination only
        /// ever sees pixels (with their colour space) and the orientation.
        private static func reencodeWithoutMetadata(_ data: Data, mimeType: String) throws -> Data {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let type = CGImageSourceGetType(source)
            else {
                throw ImageMetadataStrippingError.malformedImage
            }
            let count = CGImageSourceGetCount(source)
            guard count > 0 else { throw ImageMetadataStrippingError.malformedImage }

            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, type, count, nil) else {
                // ImageIO can read this format but not write it.
                throw ImageMetadataStrippingError.unsupportedImageFormat(mimeType)
            }
            for index in 0 ..< count {
                guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                    throw ImageMetadataStrippingError.malformedImage
                }
                var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
                if let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                   let orientation = sourceProperties[kCGImagePropertyOrientation]
                {
                    properties[kCGImagePropertyOrientation] = orientation
                }
                CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            }
            guard CGImageDestinationFinalize(destination) else {
                throw ImageMetadataStrippingError.unsupportedImageFormat(mimeType)
            }

            let result = output as Data
            guard hasNoIdentifyingProperties(result) else {
                // Never hand back data that still identifies its author.
                throw ImageMetadataStrippingError.unsupportedImageFormat(mimeType)
            }
            return result
        }

        /// Confirms that re-encoded data carries no location, authorship or device properties.
        private static func hasNoIdentifyingProperties(_ data: Data) -> Bool {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
            let forbiddenDictionaries = [
                kCGImagePropertyGPSDictionary, kCGImagePropertyIPTCDictionary, kCGImagePropertyMakerAppleDictionary,
            ]
            let forbiddenTIFF = [
                kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel, kCGImagePropertyTIFFArtist,
                kCGImagePropertyTIFFCopyright, kCGImagePropertyTIFFDateTime, kCGImagePropertyTIFFHostComputer,
                kCGImagePropertyTIFFImageDescription,
            ]
            let forbiddenExif = [
                kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifDateTimeDigitized,
                kCGImagePropertyExifMakerNote, kCGImagePropertyExifUserComment, kCGImagePropertyExifLensMake,
                kCGImagePropertyExifLensModel, kCGImagePropertyExifLensSerialNumber,
                kCGImagePropertyExifBodySerialNumber, kCGImagePropertyExifCameraOwnerName,
            ]
            for index in 0 ..< CGImageSourceGetCount(source) {
                guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
                    continue
                }
                if forbiddenDictionaries.contains(where: { properties[$0] != nil }) {
                    return false
                }
                if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                   forbiddenTIFF.contains(where: { tiff[$0] != nil })
                {
                    return false
                }
                if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
                   forbiddenExif.contains(where: { exif[$0] != nil })
                {
                    return false
                }
            }
            return true
        }
    #endif

    // MARK: - MIME Type Detection

    /// Detects the MIME type of image data by inspecting magic bytes.
    public static func detectMIMEType(from data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }

        let bytes = [UInt8](data.prefix(12))

        // JPEG: FF D8 FF
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return "image/jpeg"
        }

        // PNG: 89 50 4E 47
        if bytes.count >= 4, bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return "image/png"
        }

        // GIF: 47 49 46 38
        if bytes.count >= 4, bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x38 {
            return "image/gif"
        }

        // WebP: RIFF ???? WEBP
        if bytes.count >= 12,
           bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
           bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
            return "image/webp"
        }

        // HEIC: 00 00 00 ?? 66 74 79 70 + heic/heix
        if data.count >= 12, bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
            let brandBytes = data[8..<12]
            if let brand = String(data: brandBytes, encoding: .ascii) {
                if brand.contains("heic") || brand.contains("heix") {
                    return "image/heic"
                }
            }
        }

        return "image/jpeg"
    }

    // MARK: - Format-Preserving Compression

    /// Compresses image data while preserving the original format when possible.
    ///
    /// For JPEG: re-encodes with progressively lower quality.
    /// For PNG: attempts re-encoding; falls back to JPEG if still too large.
    /// For others: converts to JPEG as fallback.
    public static func compressPreservingFormat(
        _ data: Data,
        maxSizeInBytes: Int = 1_000_000
    ) -> Data? {
        #if os(iOS) || os(macOS) || os(tvOS)
            guard data.count > maxSizeInBytes else { return data }

            let mimeType = detectMIMEType(from: data)

            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return nil
            }

            switch mimeType {
            case "image/jpeg":
                // Try decreasing quality
                for q in stride(from: 0.9, through: 0.1, by: -0.1) {
                    if let result = encodeJPEG(cgImage, quality: q), result.count <= maxSizeInBytes {
                        return result
                    }
                }
                // Quality alone wasn't enough — resize
                return resizeToFit(cgImage, imageType: jpegTypeIdentifier, isLossy: true, maxSizeInBytes: maxSizeInBytes)

            case "image/png":
                if let pngData = encodePNG(cgImage), pngData.count <= maxSizeInBytes {
                    return pngData
                }
                // PNG can't be quality-reduced — convert to JPEG
                for q in stride(from: 0.9, through: 0.1, by: -0.1) {
                    if let result = encodeJPEG(cgImage, quality: q), result.count <= maxSizeInBytes {
                        return result
                    }
                }
                return resizeToFit(cgImage, imageType: jpegTypeIdentifier, isLossy: true, maxSizeInBytes: maxSizeInBytes)

            default:
                // GIF, WebP, HEIC → convert to JPEG
                for q in stride(from: 0.9, through: 0.1, by: -0.1) {
                    if let result = encodeJPEG(cgImage, quality: q), result.count <= maxSizeInBytes {
                        return result
                    }
                }
                return resizeToFit(cgImage, imageType: jpegTypeIdentifier, isLossy: true, maxSizeInBytes: maxSizeInBytes)
            }
        #else
            return data.count <= maxSizeInBytes ? data : nil
        #endif
    }

    // MARK: - Private Helpers

    #if os(iOS) || os(macOS) || os(tvOS)
    private static var jpegTypeIdentifier: CFString {
        UTType.jpeg.identifier as CFString
    }

    private static var pngTypeIdentifier: CFString {
        UTType.png.identifier as CFString
    }

    private static func encodeJPEG(_ image: CGImage, quality: Double) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, jpegTypeIdentifier, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, pngTypeIdentifier, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }

    private static func resizeToFit(
        _ image: CGImage,
        imageType: CFString,
        isLossy: Bool,
        maxSizeInBytes: Int
    ) -> Data? {
        var width = image.width
        var height = image.height
        let quality = isLossy ? 0.8 : 1.0

        // Halve dimensions until result fits
        for _ in 0..<8 {
            width = width * 3 / 4
            height = height * 3 / 4

            guard width > 0, height > 0 else { return nil }

            guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: nil,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: 0,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                continue
            }

            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

            guard let resized = context.makeImage() else { continue }

            let mutableData = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(mutableData, imageType, 1, nil) else {
                continue
            }

            if isLossy {
                let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
                CGImageDestinationAddImage(dest, resized, options as CFDictionary)
            } else {
                CGImageDestinationAddImage(dest, resized, nil)
            }

            guard CGImageDestinationFinalize(dest) else { continue }

            if (mutableData as Data).count <= maxSizeInBytes {
                return mutableData as Data
            }
        }

        return nil
    }
    #endif
}
