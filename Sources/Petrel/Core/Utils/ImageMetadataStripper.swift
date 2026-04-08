//
//  ImageMetadataStripper.swift
//  Petrel
//
//  Created by Josh LaCalamito on 8/6/24.
//

import Foundation

#if os(iOS) || os(macOS)
    import ImageIO
#endif

#if os(iOS)
    import MobileCoreServices
#elseif os(macOS)
    import CoreServices
#endif

public class ImageMetadataStripper {
    public static func stripMetadata(from imageData: Data) -> Data? {
        #if os(iOS) || os(macOS)
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
                print("Failed to create image source")
                return nil
            }

            let mutableData = NSMutableData()

            guard let imageType = CGImageSourceGetType(source) else {
                print("Failed to get image type")
                return nil
            }

            guard
                let destination = CGImageDestinationCreateWithData(
                    mutableData, imageType, 1, nil
                )
            else {
                print("Failed to create image destination")
                return nil
            }

            guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
            else {
                print("Failed to copy image properties")
                return nil
            }

            var strippedProperties = imageProperties

            // Remove EXIF data
            strippedProperties[kCGImagePropertyExifDictionary as String] = nil

            // Remove GPS data
            strippedProperties[kCGImagePropertyGPSDictionary as String] = nil

            // Remove TIFF data
            strippedProperties[kCGImagePropertyTIFFDictionary as String] = nil

            // Remove IPTC data
            strippedProperties[kCGImagePropertyIPTCDictionary as String] = nil

            CGImageDestinationAddImageFromSource(destination, source, 0, strippedProperties as CFDictionary)

            guard CGImageDestinationFinalize(destination) else {
                print("Failed to finalize image destination")
                return nil
            }

            return mutableData as Data
        #else
            // On Linux, metadata stripping is not available
            // Return the original data unchanged
            LogManager.logDebug("ImageMetadataStripper - Metadata stripping not available on this platform, returning original data")
            return imageData
        #endif
    }

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
        #if os(iOS) || os(macOS)
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
                return resizeToFit(cgImage, imageType: kUTTypeJPEG, isLossy: true, maxSizeInBytes: maxSizeInBytes)

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
                return resizeToFit(cgImage, imageType: kUTTypeJPEG, isLossy: true, maxSizeInBytes: maxSizeInBytes)

            default:
                // GIF, WebP, HEIC → convert to JPEG
                for q in stride(from: 0.9, through: 0.1, by: -0.1) {
                    if let result = encodeJPEG(cgImage, quality: q), result.count <= maxSizeInBytes {
                        return result
                    }
                }
                return resizeToFit(cgImage, imageType: kUTTypeJPEG, isLossy: true, maxSizeInBytes: maxSizeInBytes)
            }
        #else
            return data.count <= maxSizeInBytes ? data : nil
        #endif
    }

    // MARK: - Private Helpers

    #if os(iOS) || os(macOS)
    private static func encodeJPEG(_ image: CGImage, quality: Double) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, kUTTypePNG, 1, nil) else {
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
