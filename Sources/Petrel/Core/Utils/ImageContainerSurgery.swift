import Foundation

/// Lossless metadata removal for JPEG, PNG, WebP and GIF.
///
/// Each function walks the container, copies the parts a decoder needs and
/// leaves out the parts that describe the photographer, the camera or the
/// place. Compressed image data is never decoded or re-encoded, so the pixels
/// of the result are bit-for-bit those of the input. The code is plain Swift
/// and runs on every platform.
///
/// The functions are strict about framing: anything they cannot walk to its
/// end throws ``ImageMetadataStrippingError/malformedImage`` rather than being
/// passed through with unknown content.
enum ImageContainerSurgery {
    /// The containers that can be stripped without an image codec.
    enum Container {
        case jpeg, png, webp, gif
    }

    /// Recognises a container from its leading bytes.
    static func sniff(_ bytes: [UInt8]) -> Container? {
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return .jpeg
        }
        if bytes.count >= 8, bytes[0 ..< 8].elementsEqual(pngSignature) {
            return .png
        }
        if bytes.count >= 12, bytes[0 ..< 4].elementsEqual(ascii("RIFF")), bytes[8 ..< 12].elementsEqual(ascii("WEBP")) {
            return .webp
        }
        if bytes.count >= 6, bytes[0 ..< 6].elementsEqual(ascii("GIF87a")) || bytes[0 ..< 6].elementsEqual(ascii("GIF89a")) {
            return .gif
        }
        return nil
    }

    static func strip(_ bytes: [UInt8], as container: Container) throws -> [UInt8] {
        switch container {
        case .jpeg: return try stripJPEG(bytes)
        case .png: return try stripPNG(bytes)
        case .webp: return try stripWebP(bytes)
        case .gif: return try stripGIF(bytes)
        }
    }

    private static let malformed = ImageMetadataStrippingError.malformedImage

    private static func ascii(_ string: StaticString) -> [UInt8] {
        string.withUTF8Buffer { Array($0) }
    }

    private static func hasPrefix(_ bytes: ArraySlice<UInt8>, _ prefix: [UInt8]) -> Bool {
        bytes.count >= prefix.count && bytes.prefix(prefix.count).elementsEqual(prefix)
    }

    // MARK: - Orientation

    /// The EXIF Orientation (tag 0x0112) of a TIFF block, when it is one that
    /// changes how the image is shown (2 through 8).
    ///
    /// Orientation is the one piece of EXIF a viewer needs: without it a photo
    /// taken in portrait would be displayed on its side.
    static func displayOrientation(inTIFF tiff: ArraySlice<UInt8>) -> UInt16? {
        let bytes = Array(tiff)
        guard bytes.count >= 8 else { return nil }
        let littleEndian: Bool
        if bytes[0] == 0x49, bytes[1] == 0x49 {
            littleEndian = true
        } else if bytes[0] == 0x4D, bytes[1] == 0x4D {
            littleEndian = false
        } else {
            return nil
        }
        func u16(_ offset: Int) -> Int? {
            guard offset >= 0, offset + 2 <= bytes.count else { return nil }
            let (first, second) = (Int(bytes[offset]), Int(bytes[offset + 1]))
            return littleEndian ? first | second << 8 : first << 8 | second
        }
        func u32(_ offset: Int) -> Int? {
            guard let low = u16(littleEndian ? offset : offset + 2),
                  let high = u16(littleEndian ? offset + 2 : offset)
            else { return nil }
            return high << 16 | low
        }
        guard u16(2) == 42, let directory = u32(4), let entryCount = u16(directory) else { return nil }
        for entry in 0 ..< entryCount {
            let offset = directory + 2 + entry * 12
            guard let tag = u16(offset) else { return nil }
            guard tag == 0x0112 else { continue }
            guard u16(offset + 2) == 3, u32(offset + 4) == 1, let value = u16(offset + 8), (2 ... 8).contains(value) else {
                return nil
            }
            return UInt16(value)
        }
        return nil
    }

    /// A TIFF block holding nothing but an Orientation entry (26 bytes, big-endian).
    static func orientationOnlyTIFF(_ orientation: UInt16) -> [UInt8] {
        let high = UInt8(truncatingIfNeeded: orientation >> 8)
        let low = UInt8(truncatingIfNeeded: orientation)
        var tiff: [UInt8] = [0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08] // "MM", 42, first IFD at 8
        tiff += [0x00, 0x01] as [UInt8] // one entry
        tiff += [0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, high, low, 0x00, 0x00] as [UInt8] // Orientation, SHORT, count 1
        tiff += [0x00, 0x00, 0x00, 0x00] as [UInt8] // no next IFD
        return tiff
    }

    /// The four bytes of `value`, most significant first.
    private static func bigEndian32(_ value: UInt32) -> [UInt8] {
        var bytes: [UInt8] = []
        for shift in [24, 16, 8, 0] as [UInt32] {
            bytes.append(UInt8(truncatingIfNeeded: value >> shift))
        }
        return bytes
    }

    /// The four bytes of `value`, least significant first.
    private static func littleEndian32(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        for shift in [0, 8, 16, 24] {
            bytes.append(UInt8(truncatingIfNeeded: value >> shift))
        }
        return bytes
    }

    private static let exifHeader: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00] // "Exif\0\0"

    // MARK: - JPEG

    /// Removes metadata segments from a JPEG.
    ///
    /// Kept: the JFIF header (without its thumbnail), ICC profile segments,
    /// the Adobe colour-transform marker, and every table, frame and scan.
    /// Dropped: EXIF, XMP, IPTC/Photoshop, comments, every other application
    /// segment, and anything after the end-of-image marker (appended previews
    /// and secondary images carry their own metadata). If the EXIF block
    /// rotates or mirrors the image, it is replaced by one that holds only
    /// that orientation.
    static func stripJPEG(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { throw malformed }
        var output: [UInt8] = [0xFF, 0xD8]
        output.reserveCapacity(bytes.count)
        var index = 2
        var sawScan = false
        var keptOrientation = false

        while true {
            guard index < bytes.count, bytes[index] == 0xFF else { throw malformed }
            while index < bytes.count, bytes[index] == 0xFF { index += 1 } // fill bytes before a marker
            guard index < bytes.count else { throw malformed }
            let marker = bytes[index]
            index += 1

            switch marker {
            case 0xD9: // end of image
                guard sawScan else { throw malformed }
                output += [0xFF, 0xD9]
                return output
            case 0x00, 0xD8: // a stuffed byte or a second start marker outside a scan
                throw malformed
            case 0x01, 0xD0 ... 0xD7: // markers without a payload
                output += [0xFF, marker]
                continue
            default:
                break
            }

            guard index + 2 <= bytes.count else { throw malformed }
            let length = Int(bytes[index]) << 8 | Int(bytes[index + 1])
            guard length >= 2, index + length <= bytes.count else { throw malformed }
            let payload = bytes[(index + 2) ..< (index + length)]
            index += length

            if let kept = keptJPEGSegment(marker, payload, keptOrientation: &keptOrientation) {
                let segmentLength: Int = kept.count + 2
                output.append(0xFF)
                output.append(marker)
                output.append(UInt8(truncatingIfNeeded: segmentLength >> 8))
                output.append(UInt8(truncatingIfNeeded: segmentLength))
                output += kept
            }

            guard marker == 0xDA else { continue }
            // Entropy-coded data follows a scan header and runs to the next real marker.
            sawScan = true
            let scanStart = index
            while true {
                guard index < bytes.count else { throw malformed } // no end-of-image marker
                guard bytes[index] == 0xFF else {
                    index += 1
                    continue
                }
                guard index + 1 < bytes.count else { throw malformed }
                let next = bytes[index + 1]
                if next == 0x00 || (0xD0 ... 0xD7).contains(next) {
                    index += 2 // a stuffed 0xFF or a restart marker: part of the scan
                } else if next == 0xFF {
                    index += 1 // fill byte
                } else {
                    break
                }
            }
            output += bytes[scanStart ..< index]
        }
    }

    /// The payload to write for a JPEG segment, or `nil` to drop the segment.
    private static func keptJPEGSegment(
        _ marker: UInt8,
        _ payload: ArraySlice<UInt8>,
        keptOrientation: inout Bool
    ) -> [UInt8]? {
        switch marker {
        case 0xE0:
            // JFIF: version, density and thumbnail size. Written back without the
            // thumbnail, which can show a picture as it was before cropping.
            guard hasPrefix(payload, ascii("JFIF\0")), payload.count >= 14 else { return nil }
            var header = Array(payload.prefix(12))
            header.append(0)
            header.append(0)
            return header
        case 0xE1:
            guard hasPrefix(payload, exifHeader), !keptOrientation,
                  let orientation = displayOrientation(inTIFF: payload.dropFirst(exifHeader.count))
            else { return nil }
            keptOrientation = true
            var exif: [UInt8] = exifHeader
            exif += orientationOnlyTIFF(orientation)
            return exif
        case 0xE2:
            return hasPrefix(payload, ascii("ICC_PROFILE\0")) ? Array(payload) : nil
        case 0xEE:
            return hasPrefix(payload, ascii("Adobe")) ? Array(payload) : nil
        case 0xE3 ... 0xED, 0xEF, 0xFE: // other application segments, comments
            return nil
        default: // tables, frame headers, scan headers, restart interval
            return Array(payload)
        }
    }

    // MARK: - PNG

    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// Ancillary chunks that affect how the image is drawn or animated.
    private static let pngRenderingChunks: Set<String> = [
        "tRNS", "gAMA", "cHRM", "sRGB", "iCCP", "sBIT", "bKGD", "pHYs", "sPLT", "hIST",
        "cICP", "mDCV", "cLLI", "acTL", "fcTL", "fdAT",
    ]

    /// Removes metadata chunks from a PNG.
    ///
    /// Kept: every critical chunk (`IHDR`, `PLTE`, `IDAT`, `IEND` and any other
    /// chunk a decoder must understand) and the ancillary chunks that affect
    /// rendering: transparency, colour management, pixel density and
    /// animation. Dropped: `eXIf`, `tEXt`, `zTXt`, `iTXt`, `tIME`, every other
    /// ancillary chunk, and anything after `IEND`. If the `eXIf` chunk rotates
    /// or mirrors the image, it is replaced by one that holds only that
    /// orientation. Kept chunks are copied with their original checksums.
    static func stripPNG(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count >= 8, bytes[0 ..< 8].elementsEqual(pngSignature) else { throw malformed }
        var output = pngSignature
        output.reserveCapacity(bytes.count)
        var index = 8
        var isFirst = true
        var keptOrientation = false

        while true {
            guard index + 12 <= bytes.count else { throw malformed }
            var length = 0
            for offset in 0 ..< 4 {
                length = length << 8 | Int(bytes[index + offset])
            }
            guard length <= bytes.count - index - 12 else { throw malformed }
            let typeBytes = bytes[(index + 4) ..< (index + 8)]
            guard typeBytes.allSatisfy({ (0x41 ... 0x5A).contains($0) || (0x61 ... 0x7A).contains($0) }) else { throw malformed }
            let type = String(decoding: typeBytes, as: UTF8.self)
            let dataRange = (index + 8) ..< (index + 8 + length)
            let chunkRange = index ..< (index + 12 + length)
            index = chunkRange.upperBound

            if isFirst {
                guard type == "IHDR", length == 13 else { throw malformed }
                isFirst = false
            }

            let isCritical = typeBytes[typeBytes.startIndex] & 0x20 == 0
            if isCritical || pngRenderingChunks.contains(type) {
                output += bytes[chunkRange]
            } else if type == "eXIf", !keptOrientation, let orientation = displayOrientation(inTIFF: bytes[dataRange]) {
                keptOrientation = true
                var typeAndData = Array(typeBytes)
                typeAndData += orientationOnlyTIFF(orientation)
                output += bigEndian32(UInt32(typeAndData.count - 4))
                output += typeAndData
                output += bigEndian32(crc32(typeAndData))
            }

            if type == "IEND" {
                return output
            }
        }
    }

    private static let crcTable: [UInt32] = (0 ..< 256).map { value -> UInt32 in
        var crc = UInt32(value)
        for _ in 0 ..< 8 {
            crc = crc & 1 == 1 ? 0xEDB8_8320 ^ (crc >> 1) : crc >> 1
        }
        return crc
    }

    /// CRC-32 (ISO 3309), as PNG chunks use it.
    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    // MARK: - WebP

    /// Chunks of a WebP file that carry image data or say how to draw it.
    private static let webpRenderingChunks: Set<String> = ["VP8X", "VP8 ", "VP8L", "ALPH", "ICCP", "ANIM", "ANMF"]

    /// Removes metadata chunks from a WebP (RIFF) file.
    ///
    /// Kept: the bitstream (`VP8 `, `VP8L`, `ALPH`), the ICC profile, and the
    /// animation chunks. Dropped: `EXIF`, `XMP ` and any chunk that is not part
    /// of the format, plus bytes after the RIFF payload. The EXIF and XMP bits
    /// of the `VP8X` header are cleared and the RIFF size is rewritten. If the
    /// EXIF chunk rotates or mirrors the image, it is replaced by one that
    /// holds only that orientation.
    static func stripWebP(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count >= 12, bytes[0 ..< 4].elementsEqual(ascii("RIFF")), bytes[8 ..< 12].elementsEqual(ascii("WEBP")) else {
            throw malformed
        }
        func le32(_ offset: Int) -> Int {
            var value = 0
            for position in (0 ..< 4).reversed() {
                value = value << 8 | Int(bytes[offset + position])
            }
            return value
        }
        let riffSize = le32(4)
        guard riffSize >= 4, riffSize <= bytes.count - 8 else { throw malformed }
        let end = 8 + riffSize

        var chunks: [(fourCC: [UInt8], payload: [UInt8])] = []
        var hasImage = false
        var hasExtendedHeader = false
        var keptOrientation = false
        var index = 12
        while index < end {
            guard index + 8 <= end else { throw malformed }
            let fourCC = Array(bytes[index ..< index + 4])
            let size = le32(index + 4)
            guard size <= end - index - 8 else { throw malformed }
            let payload = bytes[(index + 8) ..< (index + 8 + size)]
            index += 8 + size + size % 2

            let name = String(decoding: fourCC, as: UTF8.self)
            if webpRenderingChunks.contains(name) {
                if name == "VP8X" {
                    guard size >= 10, chunks.isEmpty else { throw malformed }
                    hasExtendedHeader = true
                } else if name == "VP8 " || name == "VP8L" || name == "ANMF" {
                    hasImage = true
                }
                chunks.append((fourCC, Array(payload)))
            } else if name == "EXIF", hasExtendedHeader, !keptOrientation {
                // Some writers prefix the TIFF block with the JPEG "Exif\0\0" header.
                let tiff = hasPrefix(payload, exifHeader) ? payload.dropFirst(exifHeader.count) : payload
                if let orientation = displayOrientation(inTIFF: tiff) {
                    keptOrientation = true
                    chunks.append((fourCC, orientationOnlyTIFF(orientation)))
                }
            }
        }
        guard hasImage else { throw malformed }

        if hasExtendedHeader {
            // Bit 0x08 announces an EXIF chunk, 0x04 an XMP chunk.
            chunks[0].payload[0] &= ~0x04
            if !keptOrientation {
                chunks[0].payload[0] &= ~0x08
            }
        }

        var body: [UInt8] = ascii("WEBP")
        body.reserveCapacity(riffSize)
        for chunk in chunks {
            let size = chunk.payload.count
            body += chunk.fourCC
            body += littleEndian32(size)
            body += chunk.payload
            if size % 2 == 1 {
                body.append(0)
            }
        }
        var output: [UInt8] = ascii("RIFF")
        output += littleEndian32(body.count)
        output += body
        return output
    }

    // MARK: - GIF

    /// Application extensions that affect playback or colour, by identifier and authentication code.
    private static let gifRenderingApplications: [[UInt8]] = [
        ascii("NETSCAPE2.0"), // loop count
        ascii("ANIMEXTS1.0"), // loop count, alternative form
        ascii("ICCRGBG1012"), // ICC profile
    ]

    /// Removes metadata blocks from a GIF.
    ///
    /// Kept: the header and colour tables, every frame with its graphic
    /// control block, plain-text blocks, and the application blocks that set
    /// the loop count or carry an ICC profile. Dropped: comment blocks, XMP
    /// and every other application block, and anything after the trailer.
    static func stripGIF(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count >= 13, sniff(bytes) == .gif else { throw malformed }
        func colorTableSize(_ packed: UInt8) -> Int {
            packed & 0x80 == 0 ? 0 : 3 << (Int(packed & 0x07) + 1)
        }
        /// The index just past a run of data sub-blocks starting at `start`.
        func endOfSubBlocks(_ start: Int) throws -> Int {
            var index = start
            while true {
                guard index < bytes.count else { throw malformed }
                let size = Int(bytes[index])
                index += 1
                if size == 0 {
                    return index
                }
                guard size <= bytes.count - index else { throw malformed }
                index += size
            }
        }

        var index = 13 + colorTableSize(bytes[10])
        guard index <= bytes.count else { throw malformed }
        var output = Array(bytes[..<index])
        output.reserveCapacity(bytes.count)

        while true {
            guard index < bytes.count else { throw malformed } // no trailer
            switch bytes[index] {
            case 0x3B: // trailer
                output.append(0x3B)
                return output
            case 0x2C: // image descriptor, optional local colour table, LZW data
                guard index + 10 <= bytes.count else { throw malformed }
                let dataStart = index + 10 + colorTableSize(bytes[index + 9]) + 1
                guard dataStart <= bytes.count else { throw malformed }
                let blockEnd = try endOfSubBlocks(dataStart)
                output += bytes[index ..< blockEnd]
                index = blockEnd
            case 0x21: // extension
                guard index + 2 < bytes.count else { throw malformed }
                let label = bytes[index + 1]
                let blockEnd = try endOfSubBlocks(index + 2)
                let keep: Bool
                switch label {
                case 0xF9, 0x01: // graphic control, plain text
                    keep = true
                case 0xFF: // application: an 11-byte identifier in the first sub-block
                    let identifier = bytes[index + 2] == 11 && index + 14 <= bytes.count
                        ? Array(bytes[(index + 3) ..< (index + 14)])
                        : []
                    keep = gifRenderingApplications.contains(identifier)
                default: // comments and anything unknown
                    keep = false
                }
                if keep {
                    output += bytes[index ..< blockEnd]
                }
                index = blockEnd
            default:
                throw malformed
            }
        }
    }
}
