import Foundation
@testable import Petrel
import Testing
#if canImport(ImageIO)
    import CoreGraphics
    import ImageIO
    import UniformTypeIdentifiers
#endif

// Metadata stripping, checked on images assembled in the test: a small valid
// base image of each format gets real EXIF (with a GPS IFD), XMP, IPTC and
// comment blocks spliced in, and the stripped result is compared with the base
// byte for byte where pixels live.

// MARK: - Byte helpers

// Fixtures are joined with `cat` and built up in steps rather than written as
// long `+` chains of array literals: the Swift 6.1 type checker gives up on those.

/// Concatenates byte arrays.
private func cat(_ parts: [UInt8]...) -> [UInt8] {
    var result: [UInt8] = []
    for part in parts {
        result.append(contentsOf: part)
    }
    return result
}

private func byte(_ value: Int) -> UInt8 {
    UInt8(truncatingIfNeeded: value)
}

private func be16(_ value: Int) -> [UInt8] {
    let bytes: [UInt8] = [byte(value >> 8), byte(value)]
    return bytes
}

private func be32(_ value: Int) -> [UInt8] {
    cat(be16(value >> 16), be16(value))
}

private func le32(_ value: Int) -> [UInt8] {
    be32(value).reversed()
}

private func ascii(_ string: String) -> [UInt8] {
    Array(string.utf8)
}

private func contains(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
    guard !needle.isEmpty, haystack.count >= needle.count else { return false }
    let lastStart = haystack.count - needle.count
    for start in 0 ... lastStart where haystack[start ..< start + needle.count].elementsEqual(needle) {
        return true
    }
    return false
}

private func contains(_ haystack: [UInt8], _ needle: String) -> Bool {
    contains(haystack, ascii(needle))
}

/// CRC-32 as PNG uses it, written independently of the implementation under test.
private func crc32(_ bytes: [UInt8]) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in bytes {
        crc ^= UInt32(byte)
        for _ in 0 ..< 8 {
            let shifted: UInt32 = crc >> 1
            crc = crc & 1 == 1 ? shifted ^ 0xEDB8_8320 : shifted
        }
    }
    return crc ^ 0xFFFF_FFFF
}

private func adler32(_ bytes: [UInt8]) -> UInt32 {
    var a: UInt32 = 1
    var b: UInt32 = 0
    for byte in bytes {
        a = (a + UInt32(byte)) % 65521
        b = (b + a) % 65521
    }
    return b << 16 | a
}

/// A zlib stream holding `bytes` in one stored (uncompressed) deflate block.
private func zlibStored(_ bytes: [UInt8]) -> [UInt8] {
    let length = bytes.count
    let header: [UInt8] = [0x78, 0x01, 0x01, byte(length), byte(length >> 8), byte(~length), byte(~length >> 8)]
    return cat(header, bytes, be32(Int(adler32(bytes))))
}

/// The bytes of an IFD entry holding one SHORT: tag, type 3, count 1, value.
private func shortEntry(tag: Int, value: Int) -> [UInt8] {
    cat(be16(tag), be16(3), be32(1), be16(value), be16(0))
}

/// What the stripper leaves of an EXIF block that rotates the image: a
/// big-endian TIFF with the single Orientation entry.
private func orientationOnlyTIFF(_ orientation: Int) -> [UInt8] {
    cat(ascii("MM"), be16(42), be32(8), be16(1), shortEntry(tag: 0x0112, value: orientation), be32(0))
}

// MARK: - Metadata payloads

private enum Secret {
    static let cameraMake = "PetrelCam-9000"
    static let xmpAuthor = "xmp-author-Jane-Doe"
    static let xmpGPS = "40,26.767N"
    static let iptcCity = "IPTC-City-Pittsburgh"
    static let comment = "comment-shot-at-home"
    static let trailer = "TRAILER-AFTER-END"
    /// GPSLatitude 40° 26' 46" as three big-endian rationals.
    static let gpsLatitude: [UInt8] = cat(be32(40), be32(1), be32(26), be32(1), be32(46), be32(1))
}

/// A big-endian TIFF/EXIF block: Make, Orientation and a GPS IFD with a latitude.
private func exifTIFF(orientation: Int) -> [UInt8] {
    var make: [UInt8] = ascii(Secret.cameraMake)
    make.append(0)
    let makePadding: Int = make.count % 2
    // Layout: header(8) IFD0(2 + 3*12 + 4 = 42) -> 50: make, then GPS IFD, then rationals.
    let makeOffset = 50
    let gpsOffset: Int = makeOffset + make.count + makePadding
    let latitudeOffset: Int = gpsOffset + 30

    var tiff: [UInt8] = cat(ascii("MM"), be16(42), be32(8))
    tiff += be16(3)
    tiff += cat(be16(0x010F), be16(2), be32(make.count), be32(makeOffset)) // Make
    tiff += shortEntry(tag: 0x0112, value: orientation) // Orientation
    tiff += cat(be16(0x8825), be16(4), be32(1), be32(gpsOffset)) // GPS IFD pointer
    tiff += be32(0)
    tiff += make
    if makePadding == 1 {
        tiff.append(0)
    }
    tiff += be16(2)
    let northPadded: [UInt8] = [0x4E, 0, 0, 0] // "N"
    tiff += cat(be16(0x0001), be16(2), be32(2), northPadded) // GPSLatitudeRef
    tiff += cat(be16(0x0002), be16(5), be32(3), be32(latitudeOffset)) // GPSLatitude
    tiff += be32(0)
    tiff += Secret.gpsLatitude
    return tiff
}

private let xmpPacket: [UInt8] = {
    var xml = "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:Description dc:creator=\"\(Secret.xmpAuthor)\" "
    xml += "exif:GPSLatitude=\"\(Secret.xmpGPS)\"/></x:xmpmeta>"
    return ascii(xml)
}()

/// An ICC profile: the system sRGB profile where CoreGraphics is available,
/// otherwise opaque bytes (the stripper must carry it through untouched either way).
private let iccProfile: [UInt8] = {
    #if canImport(ImageIO)
        if let data = CGColorSpace(name: CGColorSpace.sRGB)?.copyICCData() as Data? {
            return [UInt8](data)
        }
    #endif
    return ascii("not-a-real-icc-profile-but-kept-verbatim")
}()

// MARK: - JPEG fixtures

private enum JPEGFixture {
    /// 16×16 baseline JPEG from `cjpeg -quality 75 -restart 1B`: SOI APP0(JFIF) DQT DQT SOF0 DHT×4 DRI SOS … EOI.
    static let baseline = [UInt8](Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAQABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/90ABAAB/9oADAMBAAIRAxEAPwDzfTtA6fJXXadoHT5P0rpNO0Dp8n6V12naB0+SilVDIc+21P/Z")!)

    /// The same picture as a progressive JPEG (`cjpeg -progressive`): ten scans with DHT segments between them.
    static let progressive = [UInt8](Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wgARCAAQABADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAABQb/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGbXSXP/8QAFRABAQAAAAAAAAAAAAAAAAAAAwD/2gAIAQEAAQUCMIwjCML/xAAVEQEBAAAAAAAAAAAAAAAAAAAEAP/aAAgBAwEBPwED7//EABURAQEAAAAAAAAAAAAAAAAAAAIA/9oACAECAQE/ASr/xAAUEAEAAAAAAAAAAAAAAAAAAAAg/9oACAEBAAY/Ah//xAAVEAEBAAAAAAAAAAAAAAAAAAAAYf/aAAgBAQABPyGKKKL/2gAMAwEAAgADAAAAEAP/xAAWEQADAAAAAAAAAAAAAAAAAAAAITH/2gAIAQMBAT8Qgz//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EH//xAAWEAEBAQAAAAAAAAAAAAAAAAAAMcH/2gAIAQEAAT8QmzynlN//2Q==")!)

    static let exifHeader: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0, 0] // "Exif\0\0"
    static let iccHeader: [UInt8] = cat(ascii("ICC_PROFILE"), [0, 1, 1])
    static let adobePayload: [UInt8] = cat(ascii("Adobe"), [0, 100, 0, 0, 0, 0, 1])
    static let scanHeader: [UInt8] = [1, 1, 0, 0, 63, 0]
    static let endOfImage: [UInt8] = [0xFF, 0xD9]

    static func segment(_ marker: UInt8, _ payload: [UInt8]) -> [UInt8] {
        let lead: [UInt8] = [0xFF, marker]
        return cat(lead, be16(payload.count + 2), payload)
    }

    /// The length of the segment starting at `index`, marker included.
    private static func segmentSize(_ jpeg: [UInt8], at index: Int) -> Int {
        let high = Int(jpeg[index + 2])
        let low = Int(jpeg[index + 3])
        return 2 + (high << 8 | low)
    }

    /// Everything from the first SOS marker to the end: all entropy-coded data.
    static func scans(_ jpeg: [UInt8]) -> [UInt8] {
        var index = 2
        while index + 4 <= jpeg.count {
            if jpeg[index] == 0xFF, jpeg[index + 1] == 0xDA {
                return Array(jpeg[index...])
            }
            index += segmentSize(jpeg, at: index)
        }
        return []
    }

    /// The marker of every segment before the first scan.
    static func headerMarkers(_ jpeg: [UInt8]) -> [UInt8] {
        var markers: [UInt8] = []
        var index = 2
        while index + 4 <= jpeg.count, jpeg[index] == 0xFF, jpeg[index + 1] != 0xDA {
            markers.append(jpeg[index + 1])
            index += segmentSize(jpeg, at: index)
        }
        return markers
    }

    /// `base` with every kind of metadata spliced in after its JFIF segment, and data after the end marker.
    static func loaded(_ base: [UInt8], orientation: Int, icc: Bool = true) -> [UInt8] {
        let jfifEnd = 20 // SOI (2) + APP0 marker (2) + APP0 length (16)
        let nul: [UInt8] = [0]
        var metadata: [UInt8] = []
        metadata += segment(0xE0, cat(ascii("JFXX"), [0, 0x13], ascii("thumbnail-bytes")))
        metadata += segment(0xE1, cat(exifHeader, exifTIFF(orientation: orientation)))
        metadata += segment(0xE1, cat(ascii("http://ns.adobe.com/xap/1.0/"), nul, xmpPacket))
        if icc {
            metadata += segment(0xE2, cat(iccHeader, iccProfile))
        }
        metadata += segment(0xE2, cat(ascii("MPF"), nul, ascii("multi-picture-index")))
        let iptcHeader: [UInt8] = [0x04, 0x04, 0, 0]
        let iptc: [UInt8] = cat(ascii("8BIM"), iptcHeader, be32(Secret.iptcCity.count), ascii(Secret.iptcCity))
        metadata += segment(0xED, cat(ascii("Photoshop 3.0"), nul, iptc))
        metadata += segment(0xEE, adobePayload)
        metadata += segment(0xEC, ascii("Ducky-private-app12"))
        metadata += segment(0xFE, ascii(Secret.comment))

        let head = Array(base[..<jfifEnd])
        let tail = Array(base[jfifEnd...])
        return cat(head, metadata, tail, ascii(Secret.trailer), base)
    }
}

// MARK: - PNG fixtures

private enum PNGFixture {
    static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    static func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        let typeAndData: [UInt8] = cat(ascii(type), data)
        return cat(be32(data.count), typeAndData, be32(Int(crc32(typeAndData))))
    }

    /// 4×4 RGB pixels, split across two IDAT chunks.
    static let idat: ([UInt8], [UInt8]) = {
        var raw: [UInt8] = []
        for y in 0 ..< 4 {
            raw.append(0)
            for x in 0 ..< 4 {
                raw.append(byte(x * 60))
                raw.append(byte(y * 60))
                raw.append(byte((x + y) * 30))
            }
        }
        let stream = zlibStored(raw)
        return (Array(stream[..<20]), Array(stream[20...]))
    }()

    static let ihdr: [UInt8] = chunk("IHDR", cat(be32(4), be32(4), [8, 2, 0, 0, 0]))
    static let header: [UInt8] = cat(signature, ihdr)
    static let imageData: [UInt8] = cat(chunk("IDAT", idat.0), chunk("IDAT", idat.1))
    static let end: [UInt8] = chunk("IEND", [])

    static var base: [UInt8] {
        cat(header, imageData, end)
    }

    static func loaded(orientation: Int) -> [UInt8] {
        let nul: [UInt8] = [0]
        var png: [UInt8] = header
        png += chunk("sRGB", [0])
        png += chunk("gAMA", be32(45455))
        png += chunk("pHYs", cat(be32(2835), be32(2835), [1]))
        png += chunk("tEXt", cat(ascii("Comment"), nul, ascii(Secret.comment)))
        png += chunk("iTXt", cat(ascii("XML:com.adobe.xmp"), [0, 0, 0, 0, 0], xmpPacket))
        png += chunk("zTXt", cat(ascii("Author"), [0, 0], zlibStored(ascii(Secret.xmpAuthor))))
        png += chunk("tIME", cat(be16(2026), [11, 11, 9, 30, 0]))
        png += chunk("eXIf", exifTIFF(orientation: orientation))
        png += chunk("prVt", ascii(Secret.iptcCity))
        png += imageData
        png += chunk("tEXt", cat(ascii("Software"), nul, ascii(Secret.cameraMake)))
        png += end
        png += ascii(Secret.trailer)
        return png
    }

    /// (type, data) of every chunk; fails the test on a bad CRC or framing.
    static func chunks(_ png: [UInt8]) -> [(type: String, data: [UInt8])] {
        var result: [(String, [UInt8])] = []
        var index = 8
        while index + 12 <= png.count {
            var length = 0
            for offset in 0 ..< 4 {
                length = length << 8 | Int(png[index + offset])
            }
            let dataStart: Int = index + 8
            let dataEnd: Int = dataStart + length
            guard dataEnd + 4 <= png.count else { break }
            let typeBytes = Array(png[index + 4 ..< dataStart])
            let data = Array(png[dataStart ..< dataEnd])
            let stored = Array(png[dataEnd ..< dataEnd + 4])
            let type = String(decoding: typeBytes, as: UTF8.self)
            let expected: [UInt8] = be32(Int(crc32(cat(typeBytes, data))))
            #expect(stored == expected, "CRC of \(type)")
            result.append((type, data))
            index = dataEnd + 4
        }
        #expect(index == png.count, "PNG has bytes after its last chunk")
        return result
    }
}

// MARK: - WebP fixtures

private enum WebPFixture {
    /// 8×8 lossy WebP from `cwebp -q 80`: RIFF, WEBP, one `VP8 ` chunk.
    static let lossy = [UInt8](Data(base64Encoded: "UklGRkwAAABXRUJQVlA4IEAAAADQAQCdASoIAAgAAUAmJagCdAEPDAbF4AD+/NL+knuy93LHeaDzZiaV80//9R/NBckl/v+ftEZD/4D/opcMAAAA")!)
    /// 8×8 lossless WebP from `cwebp -lossless`: RIFF, WEBP, one `VP8L` chunk.
    static let lossless = [UInt8](Data(base64Encoded: "UklGRiwAAABXRUJQVlA4TCAAAAAvB8ABALmM6H/sClGIgvc/ICQgTPF/p+bAgERMANjeAA==")!)

    /// A `VP8X` payload for an 8×8 canvas (sizes are stored minus one) with the given feature flags.
    static func extendedHeader(flags: UInt8) -> [UInt8] {
        let payload: [UInt8] = [flags, 0, 0, 0, 7, 0, 0, 7, 0, 0]
        return payload
    }

    static func chunk(_ fourCC: String, _ payload: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = cat(ascii(fourCC), le32(payload.count), payload)
        if payload.count % 2 == 1 {
            bytes.append(0)
        }
        return bytes
    }

    static func riff(_ chunks: [UInt8]) -> [UInt8] {
        cat(ascii("RIFF"), le32(chunks.count + 4), ascii("WEBP"), chunks)
    }

    /// The image chunk (`VP8 ` or `VP8L`) of a simple-format file, header included.
    static func imageChunk(_ simple: [UInt8]) -> [UInt8] {
        Array(simple[12...])
    }

    private static func readLE32(at index: Int, in bytes: [UInt8]) -> Int {
        var value = 0
        for offset in (0 ..< 4).reversed() {
            value = value << 8 | Int(bytes[index + offset])
        }
        return value
    }

    /// (fourCC, payload) of every chunk; fails the test on bad framing or a wrong RIFF size.
    static func chunks(_ webp: [UInt8]) -> [(fourCC: String, payload: [UInt8])] {
        let declared = readLE32(at: 4, in: webp)
        #expect(declared == webp.count - 8, "RIFF size field")
        var result: [(String, [UInt8])] = []
        var index = 12
        while index + 8 <= webp.count {
            let size = readLE32(at: index + 4, in: webp)
            let payloadStart: Int = index + 8
            let payloadEnd: Int = payloadStart + size
            guard payloadEnd <= webp.count else { break }
            let fourCC = String(decoding: webp[index ..< index + 4], as: UTF8.self)
            result.append((fourCC, Array(webp[payloadStart ..< payloadEnd])))
            index = payloadEnd + size % 2
        }
        #expect(index == webp.count, "WebP has bytes after its last chunk")
        return result
    }

    /// An extended-format file around `simple`'s image: VP8X, ICCP, image, EXIF, XMP (odd length) and an unknown chunk.
    static func loaded(_ simple: [UInt8], orientation: Int) -> [UInt8] {
        var oddXMP: [UInt8] = xmpPacket
        if oddXMP.count % 2 == 0 {
            oddXMP.append(0x21)
        }
        var chunks: [UInt8] = chunk("VP8X", extendedHeader(flags: 0x2C)) // ICC 0x20, EXIF 0x08, XMP 0x04
        chunks += chunk("ICCP", iccProfile)
        chunks += imageChunk(simple)
        chunks += chunk("EXIF", exifTIFF(orientation: orientation))
        chunks += chunk("XMP ", oddXMP)
        chunks += chunk("JUNK", ascii(Secret.iptcCity))
        return cat(riff(chunks), ascii(Secret.trailer))
    }
}

// MARK: - GIF fixture

private enum GIFFixture {
    static func subBlocks(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let size = min(255, bytes.count - index)
            out.append(byte(size))
            out.append(contentsOf: bytes[index ..< index + size])
            index += size
        }
        out.append(0)
        return out
    }

    static let screen: [UInt8] = [1, 0, 1, 0, 0x80, 0, 0] // 1×1, global colour table of two entries
    static let palette: [UInt8] = [0, 0, 0, 255, 255, 255]
    static let header: [UInt8] = cat(ascii("GIF89a"), screen, palette)

    static let applicationIntro: [UInt8] = [0x21, 0xFF, 11]
    static let commentIntro: [UInt8] = [0x21, 0xFE]
    static let trailer: [UInt8] = [0x3B]
    static let loop: [UInt8] = cat(applicationIntro, ascii("NETSCAPE2.0"), [3, 1, 0, 0, 0])

    static let graphicControl: [UInt8] = [0x21, 0xF9, 4, 0, 10, 0, 0, 0]
    static let imageDescriptor: [UInt8] = [0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0] // 1×1
    static let imageData: [UInt8] = [2, 2, 0x4C, 0x01, 0] // LZW
    static let frame: [UInt8] = cat(graphicControl, imageDescriptor, imageData)

    static var base: [UInt8] {
        cat(header, loop, frame, frame, trailer)
    }

    static var loaded: [UInt8] {
        var gif: [UInt8] = header
        gif += cat(commentIntro, subBlocks(ascii(Secret.comment)))
        gif += loop
        gif += cat(applicationIntro, ascii("XMP DataXMP"), subBlocks(xmpPacket))
        gif += frame
        gif += cat(applicationIntro, ascii("PRIVATE1.00"), subBlocks(ascii(Secret.iptcCity)))
        gif += frame
        gif += trailer
        gif += ascii(Secret.trailer)
        return gif
    }
}

// MARK: - Shared checks

private let allSecrets: [[UInt8]] = [
    ascii(Secret.cameraMake), ascii(Secret.xmpAuthor), ascii(Secret.xmpGPS), ascii(Secret.iptcCity),
    ascii(Secret.comment), ascii(Secret.trailer), Secret.gpsLatitude, ascii("xmpmeta"), ascii("GPSLatitude"),
]

private func expectNoSecrets(_ bytes: [UInt8], sourceLocation: SourceLocation = #_sourceLocation) {
    for secret in allSecrets {
        #expect(!contains(bytes, secret), "leaked \(String(decoding: secret, as: UTF8.self).debugDescription)", sourceLocation: sourceLocation)
    }
}

private func strip(_ bytes: [UInt8], _ mimeType: String) throws -> [UInt8] {
    try [UInt8](ImageMetadataStripper.stripMetadata(from: Data(bytes), mimeType: mimeType))
}

#if canImport(ImageIO)
    private struct Decoded {
        let type: String
        let width: Int
        let height: Int
        let pixels: Data
        let properties: [String: Any]
        let frameCount: Int
    }

    private func decode(_ bytes: [UInt8]) throws -> Decoded {
        let source = try #require(CGImageSourceCreateWithData(Data(bytes) as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let pixels = try #require(image.dataProvider?.data as Data?)
        return Decoded(
            type: (CGImageSourceGetType(source) as String?) ?? "",
            width: image.width,
            height: image.height,
            pixels: pixels,
            properties: (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:],
            frameCount: CGImageSourceGetCount(source)
        )
    }

    private func expectNoPrivateProperties(_ decoded: Decoded, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(decoded.properties[kCGImagePropertyGPSDictionary as String] == nil, sourceLocation: sourceLocation)
        #expect(decoded.properties[kCGImagePropertyIPTCDictionary as String] == nil, sourceLocation: sourceLocation)
        let tiff = decoded.properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake as String] == nil, sourceLocation: sourceLocation)
    }
#endif

// MARK: - Tests

@Suite("ImageMetadataStripper: JPEG")
struct ImageMetadataStripperJPEGTests {
    @Test("drops EXIF, GPS, XMP, IPTC, comments and trailing data; keeps the image bytes", arguments: [false, true])
    func stripsEverything(progressive: Bool) throws {
        let base = progressive ? JPEGFixture.progressive : JPEGFixture.baseline
        let loaded = JPEGFixture.loaded(base, orientation: 1)
        // The fixture really carries what the test says it does.
        for secret in allSecrets { #expect(contains(loaded, secret)) }

        let stripped = try strip(loaded, "image/jpeg")

        expectNoSecrets(stripped)
        #expect(!contains(stripped, "Exif"))
        #expect(!contains(stripped, "JFXX"))
        #expect(!contains(stripped, "MPF"))
        #expect(!contains(stripped, "Photoshop"))
        #expect(!contains(stripped, "Ducky"))
        // Pixels: every scan, and the tables and frame header before them, are byte-identical.
        #expect(JPEGFixture.scans(stripped) == JPEGFixture.scans(base))
        let kept = JPEGFixture.headerMarkers(stripped)
        var expectedMarkers: [UInt8] = [0xE0, 0xE2, 0xEE]
        expectedMarkers.append(contentsOf: JPEGFixture.headerMarkers(base).dropFirst())
        #expect(kept == expectedMarkers)
        // Colour: the ICC profile and the Adobe transform marker survive verbatim.
        #expect(contains(stripped, JPEGFixture.segment(0xE2, cat(JPEGFixture.iccHeader, iccProfile))))
        #expect(contains(stripped, JPEGFixture.segment(0xEE, JPEGFixture.adobePayload)))
        #expect(stripped.suffix(2) == [0xFF, 0xD9])
        // Stripping again changes nothing.
        #expect(try strip(stripped, "image/jpeg") == stripped)
    }

    @Test("an image without metadata comes back unchanged")
    func cleanImageUnchanged() throws {
        #expect(try strip(JPEGFixture.baseline, "image/jpeg") == JPEGFixture.baseline)
        #expect(try strip(JPEGFixture.progressive, "image/jpeg") == JPEGFixture.progressive)
    }

    @Test("a rotated image keeps only its orientation", arguments: [2, 3, 6, 8])
    func keepsOrientation(orientation: Int) throws {
        let loaded = JPEGFixture.loaded(JPEGFixture.baseline, orientation: orientation)
        let stripped = try strip(loaded, "image/jpeg")

        expectNoSecrets(stripped)
        // Exactly one EXIF segment, holding a TIFF with the single Orientation entry.
        let minimal = JPEGFixture.segment(0xE1, cat(JPEGFixture.exifHeader, orientationOnlyTIFF(orientation)))
        #expect(contains(stripped, minimal))
        #expect(JPEGFixture.headerMarkers(stripped).filter { $0 == 0xE1 }.count == 1)
        #expect(JPEGFixture.scans(stripped) == JPEGFixture.scans(JPEGFixture.baseline))

        #if canImport(ImageIO)
            let decoded = try decode(stripped)
            #expect(decoded.properties[kCGImagePropertyOrientation as String] as? Int == orientation)
            expectNoPrivateProperties(decoded)
        #endif
    }

    @Test("little-endian EXIF orientation is understood too")
    func littleEndianOrientation() throws {
        let header: [UInt8] = [0x49, 0x49, 42, 0, 8, 0, 0, 0] // "II", 42, first IFD at 8
        let entryCount: [UInt8] = [1, 0]
        let orientationEntry: [UInt8] = [0x12, 0x01, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0]
        let noNextDirectory: [UInt8] = [0, 0, 0, 0]
        let tiff: [UInt8] = cat(header, entryCount, orientationEntry, noNextDirectory, ascii(Secret.cameraMake))
        let exif: [UInt8] = JPEGFixture.segment(0xE1, cat(JPEGFixture.exifHeader, tiff))
        let head = Array(JPEGFixture.baseline[..<20])
        let tail = Array(JPEGFixture.baseline[20...])
        let jpeg: [UInt8] = cat(head, exif, tail)
        let stripped = try strip(jpeg, "image/jpeg")
        expectNoSecrets(stripped)
        #expect(contains(stripped, shortEntry(tag: 0x0112, value: 6)))
    }

    @Test("a JFIF thumbnail is removed from the JFIF segment")
    func jfifThumbnail() throws {
        var jpeg = JPEGFixture.baseline
        // Rewrite APP0 to declare a 1×1 thumbnail followed by its three RGB bytes.
        let thumbnail: [UInt8] = [0xAB, 0xCD, 0xEF]
        let jfifWithoutSize = Array(JPEGFixture.baseline[6 ..< 18])
        let thumbnailSize: [UInt8] = [1, 1]
        jpeg.replaceSubrange(2 ..< 20, with: JPEGFixture.segment(0xE0, cat(jfifWithoutSize, thumbnailSize, thumbnail)))
        let stripped = try strip(jpeg, "image/jpeg")
        #expect(stripped == JPEGFixture.baseline)
    }

    @Test("restart markers, stuffed bytes and fill bytes inside a scan are data, not segments")
    func scanParsing() throws {
        // Not a decodable picture: a structurally valid stream exercising the scanner.
        let scanOne: [UInt8] = [0x12, 0xFF, 0x00, 0x34, 0xFF, 0xD0, 0x56, 0xFF, 0xD7, 0xFF, 0x00, 0xFF]
        let scanTwo: [UInt8] = [0x9A, 0xFF, 0x00]
        let startOfImage: [UInt8] = [0xFF, 0xD8]
        let comment = JPEGFixture.segment(0xFE, ascii(Secret.comment))
        let quantization = JPEGFixture.segment(0xDB, [0, 1, 2, 3])
        let huffman = JPEGFixture.segment(0xC4, [0, 9, 9])
        let firstScan: [UInt8] = cat(JPEGFixture.segment(0xDA, JPEGFixture.scanHeader), scanOne)
        let secondScan: [UInt8] = cat(JPEGFixture.segment(0xDA, JPEGFixture.scanHeader), scanTwo)

        var stream: [UInt8] = cat(startOfImage, comment, quantization, firstScan)
        stream += cat(comment, huffman, secondScan, JPEGFixture.endOfImage)
        stream += ascii(Secret.trailer)

        var expected: [UInt8] = cat(startOfImage, quantization, firstScan)
        expected += cat(huffman, secondScan, JPEGFixture.endOfImage)
        #expect(try strip(stream, "image/jpeg") == expected)
    }

    #if canImport(ImageIO)
        @Test("the stripped image decodes to the same pixels, with no private properties")
        func decodesIdentically() throws {
            // No ICC here so both files decode in the same colour space.
            let loaded = JPEGFixture.loaded(JPEGFixture.baseline, orientation: 1, icc: false)
            let before = try decode(loaded)
            #expect(before.properties[kCGImagePropertyGPSDictionary as String] != nil)

            let after = try decode(strip(loaded, "image/jpeg"))
            #expect(after.type == UTType.jpeg.identifier)
            #expect(after.width == 16 && after.height == 16)
            #expect(after.pixels == before.pixels)
            expectNoPrivateProperties(after)

            // With the ICC profile kept, the image still decodes.
            let withProfile = try decode(strip(JPEGFixture.loaded(JPEGFixture.baseline, orientation: 1), "image/jpeg"))
            #expect(withProfile.width == 16)
        }
    #endif
}

@Suite("ImageMetadataStripper: PNG")
struct ImageMetadataStripperPNGTests {
    @Test("drops eXIf, text chunks, tIME, private chunks and trailing data; keeps IDAT and colour chunks")
    func stripsEverything() throws {
        let loaded = PNGFixture.loaded(orientation: 1)
        #expect(contains(loaded, Secret.gpsLatitude) && contains(loaded, Secret.comment))

        let stripped = try strip(loaded, "image/png")

        expectNoSecrets(stripped)
        let chunks = PNGFixture.chunks(stripped)
        #expect(chunks.map(\.type) == ["IHDR", "sRGB", "gAMA", "pHYs", "IDAT", "IDAT", "IEND"])
        // Pixels: the IDAT payloads are byte-identical.
        #expect(chunks.filter { $0.type == "IDAT" }.map(\.data) == [PNGFixture.idat.0, PNGFixture.idat.1])
        #expect(Array(stripped.prefix(PNGFixture.header.count)) == PNGFixture.header)
        #expect(try strip(stripped, "image/png") == stripped)
        #expect(try strip(PNGFixture.base, "image/png") == PNGFixture.base)
    }

    @Test("a rotated image keeps an eXIf chunk holding only its orientation")
    func keepsOrientation() throws {
        let stripped = try strip(PNGFixture.loaded(orientation: 6), "image/png")
        expectNoSecrets(stripped)
        let chunks = PNGFixture.chunks(stripped)
        #expect(chunks.map(\.type) == ["IHDR", "sRGB", "gAMA", "pHYs", "eXIf", "IDAT", "IDAT", "IEND"])
        let exif: [UInt8]? = chunks.first { $0.type == "eXIf" }?.data
        #expect(exif == orientationOnlyTIFF(6))
    }

    @Test("animation and colour-management chunks are kept; unknown critical chunks are kept")
    func keepsRenderingChunks() throws {
        let pixels: [UInt8] = cat(PNGFixture.idat.0, PNGFixture.idat.1)
        let frameControl: [UInt8] = PNGFixture.chunk("fcTL", [UInt8](repeating: 0, count: 26))
        var animated: [UInt8] = PNGFixture.header
        animated += PNGFixture.chunk("iCCP", cat(ascii("icc"), [0, 0], zlibStored(iccProfile)))
        animated += PNGFixture.chunk("cHRM", [UInt8](repeating: 1, count: 32))
        animated += PNGFixture.chunk("acTL", cat(be32(2), be32(0)))
        animated += frameControl
        animated += PNGFixture.chunk("IDAT", pixels)
        animated += frameControl
        animated += PNGFixture.chunk("fdAT", cat(be32(1), pixels))
        animated += PNGFixture.chunk("NEWc", [1, 2, 3])
        animated += PNGFixture.chunk("tRNS", [0, 0, 0, 0, 0, 0])
        animated += PNGFixture.end
        #expect(try strip(animated, "image/apng") == animated)
    }

    #if canImport(ImageIO)
        @Test("the stripped image decodes to the same pixels, with no private properties")
        func decodesIdentically() throws {
            let loaded = PNGFixture.loaded(orientation: 1)
            let after = try decode(strip(loaded, "image/png"))
            #expect(after.type == UTType.png.identifier)
            #expect(after.width == 4 && after.height == 4)
            #expect(try after.pixels == decode(PNGFixture.base).pixels)
            expectNoPrivateProperties(after)
            #expect(after.properties[kCGImagePropertyExifDictionary as String] == nil)
        }
    #endif
}

@Suite("ImageMetadataStripper: WebP")
struct ImageMetadataStripperWebPTests {
    @Test("drops EXIF, XMP and unknown chunks, clears their flags and fixes the RIFF size", arguments: [false, true])
    func stripsEverything(lossless: Bool) throws {
        let simple = lossless ? WebPFixture.lossless : WebPFixture.lossy
        let loaded = WebPFixture.loaded(simple, orientation: 1)
        #expect(contains(loaded, Secret.gpsLatitude) && contains(loaded, Secret.xmpAuthor))

        let stripped = try strip(loaded, "image/webp")

        expectNoSecrets(stripped)
        let chunks = WebPFixture.chunks(stripped)
        #expect(chunks.map(\.fourCC) == ["VP8X", "ICCP", lossless ? "VP8L" : "VP8 "])
        // Only the ICC flag is left; the canvas size is untouched.
        #expect(chunks[0].payload == WebPFixture.extendedHeader(flags: 0x20))
        #expect(chunks[1].payload == iccProfile)
        // Pixels: the bitstream chunk is byte-identical.
        #expect(contains(stripped, WebPFixture.imageChunk(simple)))
        #expect(try strip(stripped, "image/webp") == stripped)
        // A simple-format file has nothing to strip.
        #expect(try strip(simple, "image/webp") == simple)
    }

    @Test("a rotated image keeps an EXIF chunk holding only its orientation")
    func keepsOrientation() throws {
        let stripped = try strip(WebPFixture.loaded(WebPFixture.lossy, orientation: 8), "image/webp")
        expectNoSecrets(stripped)
        let chunks = WebPFixture.chunks(stripped)
        #expect(chunks.map(\.fourCC) == ["VP8X", "ICCP", "VP8 ", "EXIF"])
        #expect(chunks[0].payload.first == UInt8(0x28)) // ICC and EXIF bits
        #expect(chunks[3].payload == orientationOnlyTIFF(8))
    }

    @Test("animation chunks are kept")
    func keepsAnimation() throws {
        let frameHeader = [UInt8](repeating: 0, count: 16)
        let frame: [UInt8] = cat(frameHeader, WebPFixture.imageChunk(WebPFixture.lossless))
        var chunks: [UInt8] = WebPFixture.chunk("VP8X", WebPFixture.extendedHeader(flags: 0x02)) // animation
        chunks += WebPFixture.chunk("ANIM", [0, 0, 0, 0, 0, 0])
        chunks += WebPFixture.chunk("ANMF", frame)
        chunks += WebPFixture.chunk("ANMF", frame)
        let animated: [UInt8] = WebPFixture.riff(chunks)
        #expect(try strip(animated, "image/webp") == animated)
    }

    #if canImport(ImageIO)
        @Test("the stripped image decodes to the same pixels, with no private properties", arguments: [false, true])
        func decodesIdentically(lossless: Bool) throws {
            let simple = lossless ? WebPFixture.lossless : WebPFixture.lossy
            let after = try decode(strip(WebPFixture.loaded(simple, orientation: 1), "image/webp"))
            #expect(after.type == UTType.webP.identifier)
            #expect(after.width == 8 && after.height == 8)
            expectNoPrivateProperties(after)
            #expect(after.properties[kCGImagePropertyExifDictionary as String] == nil)

            // Same bitstream without a profile decodes to the same pixels as the original file.
            var noProfileChunks: [UInt8] = WebPFixture.chunk("VP8X", WebPFixture.extendedHeader(flags: 0x0C)) // EXIF, XMP
            noProfileChunks += WebPFixture.imageChunk(simple)
            noProfileChunks += WebPFixture.chunk("EXIF", exifTIFF(orientation: 1))
            noProfileChunks += WebPFixture.chunk("XMP ", xmpPacket)
            var noProfile: [UInt8] = WebPFixture.riff(noProfileChunks)
            noProfile = try strip(noProfile, "image/webp")
            #expect(try decode(noProfile).pixels == decode(simple).pixels)
        }
    #endif
}

@Suite("ImageMetadataStripper: GIF")
struct ImageMetadataStripperGIFTests {
    @Test("drops comments, XMP and private application blocks; keeps frames and the loop count")
    func stripsEverything() throws {
        #expect(contains(GIFFixture.loaded, Secret.comment) && contains(GIFFixture.loaded, Secret.xmpAuthor))
        let stripped = try strip(GIFFixture.loaded, "image/gif")
        expectNoSecrets(stripped)
        #expect(stripped == GIFFixture.base)
        #expect(try strip(GIFFixture.base, "image/gif") == GIFFixture.base)
    }

    #if canImport(ImageIO)
        @Test("the stripped animation still has both frames")
        func decodes() throws {
            let after = try decode(strip(GIFFixture.loaded, "image/gif"))
            #expect(after.type == UTType.gif.identifier)
            #expect(after.frameCount == 2)
        }
    #endif
}

@Suite("ImageMetadataStripper: dispatch and failures")
struct ImageMetadataStripperDispatchTests {
    @Test(
        "data that is not declared as an image is returned unchanged and never throws",
        arguments: ["video/mp4", "application/octet-stream", "text/vtt", "", "imagejpeg", "application/image/jpeg"]
    )
    func nonImagePassthrough(mimeType: String) throws {
        // Even bytes that are a JPEG full of metadata: the caller said it is not an image.
        for payload in [JPEGFixture.loaded(JPEGFixture.baseline, orientation: 6), ascii("WEBVTT\n\n00:00.000 --> 00:01.000\nhi"), []] {
            #expect(try ImageMetadataStripper.stripMetadata(from: Data(payload), mimeType: mimeType) == Data(payload))
        }
    }

    @Test(
        "the media type is matched case-insensitively and parameters are ignored",
        arguments: ["image/jpeg", "IMAGE/JPEG", " image/jpeg ", "image/jpeg; charset=binary", "image/jpg", "image/pjpeg"]
    )
    func mimeTypeForms(mimeType: String) throws {
        let stripped = try strip(JPEGFixture.loaded(JPEGFixture.baseline, orientation: 1), mimeType)
        expectNoSecrets(stripped)
    }

    @Test("the container is recognised from the bytes even when the declared image type is wrong")
    func sniffsContainer() throws {
        let png = try strip(PNGFixture.loaded(orientation: 1), "image/jpeg")
        expectNoSecrets(png)
        #expect(png.prefix(8) == ArraySlice(PNGFixture.signature))
        let jpeg = try strip(JPEGFixture.loaded(JPEGFixture.baseline, orientation: 1), "image/heic")
        expectNoSecrets(jpeg)
        #expect(jpeg.prefix(2) == [0xFF, 0xD8])
    }

    @Test("malformed and truncated images throw malformedImage")
    func malformed() {
        let jpeg = JPEGFixture.loaded(JPEGFixture.baseline, orientation: 1)
        let png = PNGFixture.loaded(orientation: 1)
        let webp = WebPFixture.loaded(WebPFixture.lossy, orientation: 1)
        var wrongRIFFSize = WebPFixture.lossy
        wrongRIFFSize[4] = 0xFF
        let webpWithoutImage: [UInt8] = WebPFixture.riff(WebPFixture.chunk("EXIF", exifTIFF(orientation: 1)))
        let pngWithoutHeader: [UInt8] = cat(PNGFixture.signature, PNGFixture.chunk("IDAT", [0]), PNGFixture.end)
        var badChunkLength = PNGFixture.base
        badChunkLength[PNGFixture.header.count] = 0x7F
        let cases: [(String, [UInt8], String)] = [
            ("empty jpeg", [], "image/jpeg"),
            ("empty png", [], "image/png"),
            ("empty webp", [], "image/webp"),
            ("garbage declared jpeg", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], "image/jpeg"),
            ("garbage declared png", ascii("definitely not a png file"), "image/png"),
            ("garbage declared webp", ascii("RIFFxxxxWAVEfmt "), "image/webp"),
            ("jpeg cut inside a segment", Array(jpeg[..<60]), "image/jpeg"),
            ("jpeg cut inside the scan", Array(JPEGFixture.baseline.dropLast(10)), "image/jpeg"),
            ("jpeg without end marker", Array(JPEGFixture.baseline.dropLast(2)), "image/jpeg"),
            ("jpeg with a zero-length segment", [0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x00, 0xFF, 0xD9], "image/jpeg"),
            ("jpeg that is only a start marker", [0xFF, 0xD8, 0xFF], "image/jpeg"),
            ("png cut inside a chunk", Array(png[..<100]), "image/png"),
            ("png without IEND", Array(PNGFixture.base.dropLast(12)), "image/png"),
            ("png with an oversized chunk length", badChunkLength, "image/png"),
            ("png not starting with IHDR", pngWithoutHeader, "image/png"),
            ("webp cut inside a chunk", Array(webp[..<40]), "image/webp"),
            ("webp with a RIFF size past the end", wrongRIFFSize, "image/webp"),
            ("webp without an image chunk", webpWithoutImage, "image/webp"),
            ("gif cut inside a block", Array(GIFFixture.loaded[..<30]), "image/gif"),
            ("gif without trailer", Array(GIFFixture.base.dropLast(1)), "image/gif"),
        ]
        for (name, bytes, mimeType) in cases {
            #expect(throws: ImageMetadataStrippingError.malformedImage, "\(name)") {
                try ImageMetadataStripper.stripMetadata(from: Data(bytes), mimeType: mimeType)
            }
        }
    }

    @Test("fuzz: truncations and bit flips of every fixture never trap")
    func fuzz() {
        let fixtures: [([UInt8], String)] = [
            (JPEGFixture.loaded(JPEGFixture.progressive, orientation: 6), "image/jpeg"),
            (PNGFixture.loaded(orientation: 6), "image/png"),
            (WebPFixture.loaded(WebPFixture.lossy, orientation: 6), "image/webp"),
            (GIFFixture.loaded, "image/gif"),
        ]
        var state: UInt64 = 0x1234_5678_9ABC_DEF0
        func next() -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(state >> 33)
        }
        for (fixture, mimeType) in fixtures {
            for length in stride(from: 0, to: fixture.count, by: 7) {
                _ = try? ImageMetadataStripper.stripMetadata(from: Data(fixture[..<length]), mimeType: mimeType)
            }
            for _ in 0 ..< 400 {
                var mutated = fixture
                for _ in 0 ..< 1 + next() % 3 {
                    mutated[next() % mutated.count] ^= UInt8(1 << (next() % 8))
                }
                _ = try? ImageMetadataStripper.stripMetadata(from: Data(mutated), mimeType: mimeType)
            }
        }
    }

    @Test("an image format without a pure-Swift path is re-encoded by ImageIO or refused")
    func otherFormats() throws {
        let notAnImage = Data(ascii("<svg xmlns=\"http://www.w3.org/2000/svg\"><metadata>secret</metadata></svg>"))
        #if canImport(ImageIO)
            // ImageIO cannot read it: refused as malformed rather than passed through.
            #expect(throws: ImageMetadataStrippingError.malformedImage) {
                try ImageMetadataStripper.stripMetadata(from: notAnImage, mimeType: "image/svg+xml")
            }
        #else
            #expect(throws: ImageMetadataStrippingError.unsupportedImageFormat("image/svg+xml")) {
                try ImageMetadataStripper.stripMetadata(from: notAnImage, mimeType: "image/svg+xml")
            }
            #expect(throws: ImageMetadataStrippingError.unsupportedImageFormat("image/heic")) {
                try ImageMetadataStripper.stripMetadata(from: Data([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]), mimeType: "IMAGE/HEIC")
            }
        #endif
    }

    #if canImport(ImageIO)
        /// An image of `type` written by ImageIO with EXIF, TIFF and GPS properties and an orientation.
        private func imageIOFixture(_ type: UTType) throws -> Data {
            let context = try #require(CGContext(
                data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.setFillColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
            let image = try #require(context.makeImage())
            let data = NSMutableData()
            let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
            let properties: [CFString: Any] = [
                kCGImagePropertyOrientation: 6,
                kCGImagePropertyGPSDictionary: [
                    kCGImagePropertyGPSLatitude: 40.446, kCGImagePropertyGPSLatitudeRef: "N",
                    kCGImagePropertyGPSLongitude: 79.982, kCGImagePropertyGPSLongitudeRef: "W",
                ],
                kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: Secret.cameraMake, kCGImagePropertyTIFFModel: "Model-X"],
                kCGImagePropertyExifDictionary: [
                    kCGImagePropertyExifDateTimeOriginal: "2026:11:11 09:30:00",
                    kCGImagePropertyExifLensModel: "Secret Lens 50mm",
                ],
            ]
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            try #require(CGImageDestinationFinalize(destination))
            return data as Data
        }

        @Test("HEIC is stripped through ImageIO and stays HEIC")
        func heic() throws {
            let original = try imageIOFixture(.heic)
            let before = try decode([UInt8](original))
            #expect(before.type == UTType.heic.identifier)
            #expect(before.properties[kCGImagePropertyGPSDictionary as String] != nil)

            let stripped = try ImageMetadataStripper.stripMetadata(from: original, mimeType: "image/heic")
            let after = try decode([UInt8](stripped))

            #expect(after.type == UTType.heic.identifier)
            #expect(after.width == 64 && after.height == 48)
            #expect(after.properties[kCGImagePropertyOrientation as String] as? Int == 6)
            expectNoPrivateProperties(after)
            let exif = after.properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
            #expect(exif?[kCGImagePropertyExifDateTimeOriginal as String] == nil)
            #expect(exif?[kCGImagePropertyExifLensModel as String] == nil)
            expectNoSecrets([UInt8](stripped))
        }

        @Test("TIFF is stripped through ImageIO and stays TIFF")
        func tiff() throws {
            let original = try imageIOFixture(.tiff)
            #expect(contains([UInt8](original), Secret.cameraMake))
            let stripped = try ImageMetadataStripper.stripMetadata(from: original, mimeType: "image/tiff")
            let after = try decode([UInt8](stripped))
            #expect(after.type == UTType.tiff.identifier)
            #expect(after.properties[kCGImagePropertyOrientation as String] as? Int == 6)
            expectNoPrivateProperties(after)
            expectNoSecrets([UInt8](stripped))
        }
    #endif
}

@Suite("ImageMetadataStripper: format-sniffing API")
struct ImageMetadataStripperLegacyTests {
    @Test("stripMetadata(from:) strips by container and keeps the format")
    func legacyStrip() throws {
        let jpeg = try #require(ImageMetadataStripper.stripMetadata(from: Data(JPEGFixture.loaded(JPEGFixture.baseline, orientation: 1))))
        expectNoSecrets([UInt8](jpeg))
        #expect(JPEGFixture.scans([UInt8](jpeg)) == JPEGFixture.scans(JPEGFixture.baseline))

        // A PNG stays a PNG; it is no longer transcoded.
        let png = try #require(ImageMetadataStripper.stripMetadata(from: Data(PNGFixture.loaded(orientation: 1))))
        expectNoSecrets([UInt8](png))
        #expect(png.prefix(8) == Data(PNGFixture.signature))

        let webp = try #require(ImageMetadataStripper.stripMetadata(from: Data(WebPFixture.loaded(WebPFixture.lossless, orientation: 1))))
        expectNoSecrets([UInt8](webp))
        #expect(webp.prefix(4) == Data(ascii("RIFF")))
    }

    @Test("stripMetadata(from:) fails closed on data it cannot strip")
    func legacyFailsClosed() {
        #expect(ImageMetadataStripper.stripMetadata(from: Data([0x00, 0x01, 0x02, 0x03])) == nil)
        #expect(ImageMetadataStripper.stripMetadata(from: Data()) == nil)
        // A truncated JPEG.
        #expect(ImageMetadataStripper.stripMetadata(from: Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])) == nil)
    }

    @Test("NetworkError contains metadataStrippingFailed case")
    func metadataStrippingFailedError() {
        let error = NetworkError.metadataStrippingFailed
        #expect(error.localizedDescription.contains("metadata"))
        #expect(error.failureReason?.contains("Metadata") == true)
        #expect(error.recoverySuggestion?.contains("metadata") == true)
    }
}

// MARK: - Helpers on the wire

@Suite("Bluesky image uploads strip metadata by default")
struct BskyImageUploadTests {
    private let photo = JPEGFixture.loaded(JPEGFixture.baseline, orientation: 6)
    private let screenshot = PNGFixture.loaded(orientation: 1)

    private func uploads(_ pds: BskyFakePDS) -> [BskyStubRequest] {
        pds.server.requests(to: "com.atproto.repo.uploadBlob")
    }

    @Test("post(_:images:) uploads stripped bytes and embeds the blobs with alt text and size")
    func postStripsByDefault() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()

        let post = try await agent.post("Seen today", images: [
            PostImage(data: Data(photo), mimeType: "image/jpeg", alt: "A storm petrel", width: 1600, height: 900),
            PostImage(data: Data(screenshot), mimeType: "image/png", alt: "A chart"),
        ])

        let sent = uploads(pds)
        #expect(sent.count == 2)
        #expect(sent.map { $0.header("Content-Type") } == ["image/jpeg", "image/png"])
        // What left the device is exactly what the stripper produces, and holds no metadata.
        #expect(try sent[0].body == ImageMetadataStripper.stripMetadata(from: Data(photo), mimeType: "image/jpeg"))
        #expect(try sent[1].body == ImageMetadataStripper.stripMetadata(from: Data(screenshot), mimeType: "image/png"))
        for request in sent {
            expectNoSecrets([UInt8](request.body))
        }
        #expect(sent[0].body != Data(photo))
        // The pictures themselves are untouched, and the photo keeps its rotation.
        #expect(JPEGFixture.scans([UInt8](sent[0].body)) == JPEGFixture.scans(JPEGFixture.baseline))
        #expect(contains([UInt8](sent[0].body), shortEntry(tag: 0x0112, value: 6)))

        let record = try #require(pds.record(at: post.uri.uriString())?.value)
        #expect(record["text"] == "Seen today")
        let images = try #require(record["embed"]?["images"]?.arrayValue)
        #expect(record["embed"]?["$type"] == "app.bsky.embed.images")
        #expect(images.map { $0["alt"]?.stringValue } == ["A storm petrel", "A chart"])
        #expect(images[0]["aspectRatio"]?["width"] == 1600)
        #expect(images[0]["image"]?["mimeType"] == "image/jpeg")
        #expect(images[0]["image"]?["size"] == .integer(sent[0].body.count))
        #expect(images[1]["aspectRatio"] == nil)
    }

    @Test("post(_:images:stripImageMetadata: false) uploads the files as they are")
    func postOptOut() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()

        try await agent.post(
            "Keep the EXIF",
            images: [PostImage(data: Data(photo), mimeType: "image/jpeg", alt: "")],
            stripImageMetadata: false
        )

        #expect(uploads(pds).map(\.body) == [Data(photo)])
        #expect(contains([UInt8](uploads(pds)[0].body), Secret.gpsLatitude))
    }

    @Test("an image that cannot be stripped stops the post before anything is uploaded")
    func failsClosed() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let truncated = Data(photo.prefix(200)) // cut in the middle of a segment

        await #expect(throws: ImageMetadataStrippingError.malformedImage) {
            try await agent.post("two pictures", images: [
                PostImage(data: Data(photo), mimeType: "image/jpeg", alt: "fine"),
                PostImage(data: truncated, mimeType: "image/jpeg", alt: "broken"),
            ])
        }
        #expect(pds.server.requests.isEmpty)

        // The same files go through when the caller opts out of stripping.
        try await agent.post(
            "two pictures",
            images: [PostImage(data: truncated, mimeType: "image/jpeg", alt: "broken")],
            stripImageMetadata: false
        )
        #expect(uploads(pds).map(\.body) == [truncated])
    }

    @Test("post(_:images:) takes one to four images of an image media type, and can quote")
    func validation() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let image = PostImage(data: Data(JPEGFixture.baseline), mimeType: "image/jpeg", alt: "")

        await #expect(throws: BskyAgentError.self) { try await agent.post("none", images: []) }
        await #expect(throws: BskyAgentError.self) {
            try await agent.post("five", images: Array(repeating: image, count: 5))
        }
        await #expect(throws: BskyAgentError.self) {
            try await agent.post("video", images: [PostImage(data: Data([0, 0, 0, 24]), mimeType: "video/mp4", alt: "")])
        }
        let signedOut = try await pds.server.makeAgent(did: nil)
        await #expect(throws: BskyAgentError.notAuthenticated) { try await signedOut.post("hi", images: [image]) }
        #expect(pds.server.requests.isEmpty)

        let quoted = try ComAtprotoRepoStrongRef(
            uri: ATProtocolURI(uriString: "at://did:plc:bob/app.bsky.feed.post/3kquoted"),
            cid: CID.fromDAGCBOR(Data("quoted".utf8))
        )
        let post = try await agent.post("with a quote", images: [image], quote: quoted)
        let embed = pds.record(at: post.uri.uriString())?.value["embed"]
        #expect(embed?["$type"] == "app.bsky.embed.recordWithMedia")
        #expect(embed?["record"]?["record"]?["uri"] == "at://did:plc:bob/app.bsky.feed.post/3kquoted")
        #expect(embed?["media"]?["images"]?.arrayValue?.count == 1)
    }

    @Test("uploadImage strips by default; uploadBlob never does")
    func uploadImageVersusUploadBlob() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()

        let stripped = try await agent.uploadImage(Data(photo), mimeType: "image/jpeg")
        let optedOut = try await agent.uploadImage(Data(photo), mimeType: "image/jpeg", stripMetadata: false)
        let raw = try await agent.uploadBlob(Data(photo), mimeType: "image/jpeg")

        let sent = uploads(pds).map(\.body)
        expectNoSecrets([UInt8](sent[0]))
        #expect(sent[1] == Data(photo))
        #expect(sent[2] == Data(photo))
        #expect(stripped.size < raw.size)
        #expect(optedOut.size == raw.size)

        await #expect(throws: BskyAgentError.self) {
            try await agent.uploadImage(Data([1, 2, 3]), mimeType: "application/pdf")
        }
        #expect(uploads(pds).count == 3)
    }

    @Test("setAvatar and setBanner upload stripped images and leave the rest of the profile alone")
    func profileImages() async throws {
        let pds = BskyFakePDS()
        let profileURI = "at://did:plc:alice/app.bsky.actor.profile/self"
        pds.seed(profileURI, ["$type": "app.bsky.actor.profile", "displayName": "Storm Petrel"])
        let agent = try await pds.server.makeAgent()

        try await agent.setAvatar(Data(photo), mimeType: "image/jpeg")
        try await agent.setBanner(Data(screenshot), mimeType: "image/png")

        let sent = uploads(pds)
        #expect(sent.count == 2)
        for request in sent {
            expectNoSecrets([UInt8](request.body))
        }
        let profile = try #require(pds.record(at: profileURI)?.value)
        #expect(profile["displayName"] == "Storm Petrel")
        #expect(profile["avatar"]?["mimeType"] == "image/jpeg")
        #expect(profile["avatar"]?["size"] == .integer(sent[0].body.count))
        #expect(profile["banner"]?["mimeType"] == "image/png")

        try await agent.setAvatar(Data(photo), mimeType: "image/jpeg", stripMetadata: false)
        #expect(uploads(pds).last?.body == Data(photo))
    }
}
