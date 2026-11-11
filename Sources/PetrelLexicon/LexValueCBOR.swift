import Foundation
import Petrel
import PetrelCore

// MARK: - DAG-CBOR

public extension LexValue {
    /// Encodes the value as canonical DAG-CBOR (DRISL): map keys sorted by
    /// length then bytes, shortest integer forms, links as tag 42.
    ///
    /// The bytes are produced by PetrelCore's `DAGCBOR` encoder, the same one
    /// the repository and firehose code uses, so a record hashed here gets the
    /// CID a PDS computes for it.
    ///
    /// - Throws: `DAGCBORError` if encoding fails.
    func dagCBOR() throws -> Data {
        try DAGCBOR.encodeValue(cborTree())
    }

    /// The CID (`dag-cbor`, SHA-256) of ``dagCBOR()``.
    func cid() throws -> CID {
        try CID.fromDAGCBOR(dagCBOR())
    }

    /// Decodes strict DAG-CBOR (DRISL).
    ///
    /// Rejected: indefinite lengths, non-minimal integer or length encodings,
    /// floats, `undefined` and other simple values, tags other than 42,
    /// non-string or unsorted or repeated map keys, invalid UTF-8, integers
    /// outside 64 signed bits, trailing bytes, and (as in JSON) a malformed
    /// `$type`, a malformed blob, or an unblessed CID.
    ///
    /// - Throws: ``LexValueError``.
    init(dagCBOR data: Data, options: ParseOptions = .standard) throws {
        var decoder = LexCBORDecoder(bytes: [UInt8](data), options: options)
        self = try decoder.decodeDocument()
    }

    /// The untyped tree `DAGCBOR.encodeValue` consumes.
    private func cborTree() -> Any {
        switch self {
        case .null:
            return NSNull()
        case let .boolean(flag):
            return flag
        case let .integer(number):
            return number
        case let .string(string):
            return string
        case let .bytes(data):
            return data
        case let .cidLink(cid):
            return CIDAsLink(cid: cid, representation: .link)
        case let .array(items):
            return items.map { $0.cborTree() }
        case let .object(fields):
            return fields.mapValues { $0.cborTree() }
        }
    }
}

/// A strict DAG-CBOR reader that builds ``LexValue`` directly.
///
/// PetrelCore's public decoding surface works on SwiftCBOR's `CBOR` enum;
/// reading the bytes here keeps `PetrelLexicon` free of that dependency and
/// lets every rejection carry a JSON-pointer path.
struct LexCBORDecoder {
    let bytes: [UInt8]
    let options: LexValue.ParseOptions
    var offset = 0

    mutating func decodeDocument() throws -> LexValue {
        guard !bytes.isEmpty else {
            throw malformed("empty input", path: "")
        }
        let value = try decodeItem(path: "", depth: 0)
        guard offset == bytes.count else {
            throw malformed("\(bytes.count - offset) trailing byte(s) after the value", path: "")
        }
        return value
    }

    private func malformed(_ message: String, path: String) -> LexValueError {
        LexValueError(.malformedCBOR, path: path, message)
    }

    private mutating func readHead(path: String) throws -> (major: UInt8, argument: UInt64) {
        guard offset < bytes.count else {
            throw malformed("unexpected end of input", path: path)
        }
        let initial = bytes[offset]
        let major = initial >> 5
        let info = initial & 0x1F
        offset += 1
        switch info {
        case 0 ..< 24:
            return (major, UInt64(info))
        case 24, 25, 26, 27:
            let width = 1 << Int(info - 24)
            guard bytes.count - offset >= width else {
                throw malformed("unexpected end of input", path: path)
            }
            var argument: UInt64 = 0
            for index in 0 ..< width {
                argument = argument << 8 | UInt64(bytes[offset + index])
            }
            offset += width
            let minimum: UInt64 = info == 24 ? 24 : (info == 25 ? 0x100 : (info == 26 ? 0x10000 : 0x1_0000_0000))
            // Major type 7 uses the additional bytes for floats and simple
            // values, none of which are allowed; reject those before the
            // canonical-length check so the message is the useful one.
            if major != 7, argument < minimum {
                throw malformed("non-canonical (over-long) integer or length encoding", path: path)
            }
            return (major, argument)
        default:
            throw malformed(info == 31 ? "indefinite-length items are not allowed" : "reserved additional information \(info)", path: path)
        }
    }

    private mutating func readLength(_ argument: UInt64, path: String) throws -> Int {
        guard argument <= UInt64(bytes.count - offset) else {
            throw malformed("declared length \(argument) exceeds the remaining input", path: path)
        }
        return Int(argument)
    }

    private mutating func readText(length argument: UInt64, path: String) throws -> String {
        let length = try readLength(argument, path: path)
        let slice = bytes[offset ..< offset + length]
        offset += length
        guard let text = String(validatingUTF8Bytes: Array(slice)) else {
            throw malformed("text string is not valid UTF-8", path: path)
        }
        return text
    }

    /// Decodes one item. Containers and links are handled by their own
    /// functions so the recursive path keeps a small stack frame per level.
    private mutating func decodeItem(path: String, depth: Int) throws -> LexValue {
        let start = offset
        let (major, argument) = try readHead(path: path)
        switch major {
        case 0:
            guard argument <= UInt64(Int64.max) else {
                throw LexValueError(.integerOutOfRange, path: path, "\(argument) does not fit in a signed 64-bit integer")
            }
            return .integer(Int64(argument))
        case 1:
            guard argument <= UInt64(Int64.max) else {
                throw LexValueError(.integerOutOfRange, path: path, "-1 - \(argument) does not fit in a signed 64-bit integer")
            }
            return .integer(-1 - Int64(argument))
        case 2:
            return try .bytes(readBytes(length: argument, path: path))
        case 3:
            return try .string(readText(length: argument, path: path))
        case 4:
            return try decodeArray(count: argument, path: path, depth: depth)
        case 5:
            return try decodeMap(count: argument, path: path, depth: depth)
        case 6:
            return try decodeLink(tag: argument, path: path)
        default:
            return try decodeSimple(bytes[start], path: path)
        }
    }

    private mutating func readBytes(length argument: UInt64, path: String) throws -> Data {
        let length = try readLength(argument, path: path)
        let data = Data(bytes[offset ..< offset + length])
        offset += length
        return data
    }

    private func decodeSimple(_ initial: UInt8, path: String) throws -> LexValue {
        switch initial {
        case 0xF4: return .boolean(false)
        case 0xF5: return .boolean(true)
        case 0xF6: return .null
        case 0xF9, 0xFA, 0xFB:
            throw LexValueError(.floatNotAllowed, path: path, "floats are not part of the data model")
        default:
            throw malformed("unsupported simple value 0x\(String(initial, radix: 16))", path: path)
        }
    }

    private mutating func decodeArray(count argument: UInt64, path: String, depth: Int) throws -> LexValue {
        guard depth < options.maximumDepth else {
            throw LexValueError(.depthLimitExceeded, path: path, "value nests deeper than \(options.maximumDepth)")
        }
        // Every element takes at least one byte.
        let count = try readLength(argument, path: path)
        var items: [LexValue] = []
        items.reserveCapacity(count)
        for index in 0 ..< count {
            try items.append(decodeItem(path: LexPath.appending(path, index), depth: depth + 1))
        }
        return .array(items)
    }

    private mutating func decodeMap(count argument: UInt64, path: String, depth: Int) throws -> LexValue {
        guard depth < options.maximumDepth else {
            throw LexValueError(.depthLimitExceeded, path: path, "value nests deeper than \(options.maximumDepth)")
        }
        guard argument <= UInt64((bytes.count - offset) / 2) else {
            throw malformed("declared map size \(argument) exceeds the remaining input", path: path)
        }
        let count = Int(argument)
        var fields: [String: LexValue] = [:]
        fields.reserveCapacity(count)
        var previousKey: ArraySlice<UInt8>?
        for _ in 0 ..< count {
            let keyStart = offset
            let (keyMajor, keyArgument) = try readHead(path: path)
            guard keyMajor == 3 else {
                throw malformed("map keys must be text strings", path: path)
            }
            let key = try readText(length: keyArgument, path: path)
            // The encoded key (head + bytes) sorts length-first, so
            // comparing the encoded forms is the DAG-CBOR order.
            let encodedKey = bytes[keyStart ..< offset]
            if let previousKey {
                let ordered = previousKey.count != encodedKey.count
                    ? previousKey.count < encodedKey.count
                    : previousKey.lexicographicallyPrecedes(encodedKey)
                guard ordered else {
                    throw malformed("map keys are repeated or not in canonical order", path: path)
                }
            }
            previousKey = encodedKey
            fields[key] = try decodeItem(path: LexPath.appending(path, key), depth: depth + 1)
        }
        return try LexValue.normalizedObject(fields, path: path, options: options, fromJSON: false)
    }

    private mutating func decodeLink(tag argument: UInt64, path: String) throws -> LexValue {
        guard argument == 42 else {
            throw malformed("unsupported tag \(argument); only tag 42 (CID link) is allowed", path: path)
        }
        let (innerMajor, innerArgument) = try readHead(path: path)
        guard innerMajor == 2 else {
            throw LexValueError(.malformedLink, path: path, "tag 42 must wrap a byte string")
        }
        let length = try readLength(innerArgument, path: path)
        guard length > 1, bytes[offset] == 0x00 else {
            throw LexValueError(.malformedLink, path: path, "tag 42 payload must start with the 0x00 multibase prefix")
        }
        let cidBytes = Data(bytes[(offset + 1) ..< (offset + length)])
        offset += length
        guard let cid = try? CID(bytes: cidBytes) else {
            throw LexValueError(.invalidCID, path: path, "tag 42 payload is not a CIDv1")
        }
        if options.requireBlessedCIDs, !LexCID.isBlessed(cid) {
            throw LexValueError(.invalidCID, path: path, "link is not a blessed CID (v1, dag-cbor or raw, sha-256)")
        }
        return .cidLink(cid)
    }
}

extension String {
    /// Strict UTF-8 decoding: `nil` instead of U+FFFD repair.
    init?(validatingUTF8Bytes bytes: [UInt8]) {
        var decoder = UTF8()
        var iterator = bytes.makeIterator()
        var scalars = String.UnicodeScalarView()
        while true {
            switch decoder.decode(&iterator) {
            case let .scalarValue(scalar):
                scalars.append(scalar)
            case .emptyInput:
                self = String(scalars)
                return
            case .error:
                return nil
            }
        }
    }
}

// MARK: - Bridges from Petrel's typed values

public extension LexValue {
    /// Converts any `Encodable` value (a generated record struct, an XRPC
    /// input, a dictionary…) by encoding it to JSON and running the strict
    /// parser over the result, so a typed value is held to the same rules as
    /// wire data.
    ///
    /// - Throws: ``LexValueError`` with code
    ///   ``LexValueError/Code/encodingFailed`` if the value cannot be encoded,
    ///   or any error of ``init(json:options:)``.
    init(encoding value: some Encodable, options: ParseOptions = .standard) throws {
        let json: Data
        do {
            json = try JSONCoders.encode(value)
        } catch {
            throw LexValueError(.encodingFailed, path: "", "value could not be encoded to JSON: \(error)")
        }
        try self.init(json: json, options: options)
    }

    /// Converts Petrel's loosely typed `ATProtocolValueContainer`.
    ///
    /// The container accepts some data the data model forbids (for example a
    /// `$type` that is `null`); this conversion is where that data is caught.
    ///
    /// - Throws: ``LexValueError``.
    init(_ container: ATProtocolValueContainer, options: ParseOptions = .standard) throws {
        try self.init(encoding: container, options: options)
    }
}
