// CARReader.swift
// Petrel
//
// Reads CAR v1 (Content Addressable aRchive) files.
// Spec: https://ipld.io/specs/transport/car/carv1/

import Foundation
import SwiftCBOR

// MARK: - CARReaderError

public enum CARReaderError: LocalizedError {
    case invalidHeader(String)
    case invalidVarint
    case unexpectedEOF
    case invalidCID(String)
    case blockNotFound(String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHeader(msg): return "Invalid CAR header: \(msg)"
        case .invalidVarint: return "Invalid varint encoding"
        case .unexpectedEOF: return "Unexpected end of data"
        case let .invalidCID(msg): return "Invalid CID: \(msg)"
        case let .blockNotFound(key): return "Block not found for key: \(key)"
        case let .decodingFailed(msg): return "Decoding failed: \(msg)"
        }
    }
}

// MARK: - CARReader

public class CARReader {
    // MARK: - Types

    public struct BlockLocation {
        public let dataOffset: Int
        public let dataLength: Int
    }

    // MARK: - Properties

    private let data: Data
    private var offset: Int = 0

    /// Internal raw byte-keyed index mapping raw CID bytes → block location in the data
    private(set) var rawBlockIndex: [Data: BlockLocation] = [:]

    /// Maps CID hex string → block location in the data (public compatibility view)
    public var blockIndex: [String: BlockLocation] {
        Dictionary(uniqueKeysWithValues: rawBlockIndex.map { (key, value) in
            (key.hexEncodedString(), value)
        })
    }

    /// CID roots from the CAR header
    public private(set) var roots: [CID] = []

    // MARK: - Init

    public init(data: Data) throws {
        self.data = data
        try parseHeader()
        try indexBlocks()
    }

    public convenience init(fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL, options: .alwaysMapped)
        try self.init(data: data)
    }

    // MARK: - Varint

    /// Reads an unsigned LEB128 varint from the current offset.
    @discardableResult
    public func readVarint() throws -> Int {
        var result: UInt64 = 0
        var shift: UInt64 = 0

        while offset < data.count {
            let byte = data[offset]
            offset += 1

            result |= UInt64(byte & 0x7F) << shift

            if byte & 0x80 == 0 {
                guard result <= UInt64(Int.max) else {
                    throw CARReaderError.invalidVarint
                }
                return Int(result)
            }

            shift += 7
            if shift > 63 {
                throw CARReaderError.invalidVarint
            }
        }

        throw CARReaderError.unexpectedEOF
    }

    // MARK: - Header

    private func parseHeader() throws {
        let headerLength = try readVarint()

        guard offset + headerLength <= data.count else {
            throw CARReaderError.unexpectedEOF
        }

        let headerData = data[offset ..< (offset + headerLength)]
        offset += headerLength

        guard let cbor = try? CBOR.decode([UInt8](headerData)) else {
            throw CARReaderError.invalidHeader("Failed to decode CBOR header")
        }

        guard case let .map(map) = cbor else {
            throw CARReaderError.invalidHeader("Header is not a CBOR map")
        }

        // Check version
        if let versionCBOR = map[.utf8String("version")] {
            switch versionCBOR {
            case let .unsignedInt(v):
                guard v == 1 else {
                    throw CARReaderError.invalidHeader("Unsupported CAR version: \(v)")
                }
            default:
                throw CARReaderError.invalidHeader("Invalid version field type")
            }
        }

        // Parse roots
        if let rootsCBOR = map[.utf8String("roots")] {
            guard case let .array(rootArray) = rootsCBOR else {
                throw CARReaderError.invalidHeader("Roots is not an array")
            }

            for rootItem in rootArray {
                if case let .tagged(tag, value) = rootItem, tag.rawValue == 42 {
                    // Tag 42 CID link
                    if case let .byteString(bytes) = value, bytes.count > 1, bytes[0] == 0x00 {
                        let cidBytes = Data(bytes.dropFirst())
                        let cid = try CID(bytes: cidBytes)
                        roots.append(cid)
                    }
                } else if case let .byteString(bytes) = rootItem {
                    // Raw CID bytes
                    let cid = try CID(bytes: Data(bytes))
                    roots.append(cid)
                }
            }
        }
    }

    // MARK: - Block Indexing

    /// Indexes every block in the CAR body.
    ///
    /// The only clean end of the archive is a block that ends exactly on `data.count`;
    /// the loop condition detects it. Every other framing violation — a truncated length
    /// prefix, a length that runs past the end, a CID that does not fit inside its own
    /// block — is corruption and throws, so a truncated archive can never be indexed as a
    /// smaller but seemingly intact one.
    private func indexBlocks() throws {
        while offset < data.count {
            let totalLength = try readVarint()

            guard totalLength > 0 else {
                throw CARReaderError.invalidVarint
            }
            guard offset + totalLength <= data.count else {
                throw CARReaderError.unexpectedEOF
            }

            let blockDataStart = offset
            let blockEnd = blockDataStart + totalLength

            // Parse CID from block: version + codec + multihash(algo + length + digest)
            let cidStart = offset

            guard offset < blockEnd else { throw CARReaderError.unexpectedEOF }
            let version = data[offset]
            offset += 1

            if version == 0x12 {
                // CIDv0 (starts with sha2-256 multihash directly) — rare but handle it
                // sha2-256: code=0x12, length=0x20, then 32 bytes digest
                guard offset < blockEnd else { throw CARReaderError.unexpectedEOF }
                let hashLen = data[offset]
                offset += 1
                let digestLen = Int(hashLen)
                guard offset + digestLen <= blockEnd else { throw CARReaderError.unexpectedEOF }
                offset += digestLen

                let cidData = data[cidStart ..< offset]
                let dataOffset = offset
                let dataLength = totalLength - (offset - blockDataStart)
                rawBlockIndex[Data(cidData)] = BlockLocation(dataOffset: dataOffset, dataLength: dataLength)
                offset = blockEnd
                continue
            }

            // CIDv1
            guard offset < blockEnd else { throw CARReaderError.unexpectedEOF }
            // Skip the one-byte codec. The full CID bytes are retained below.
            offset += 1

            // Multihash: algorithm + length + digest
            guard offset < blockEnd else { throw CARReaderError.unexpectedEOF }
            // Skip the one-byte hash algorithm. The full CID bytes are retained below.
            offset += 1

            guard offset < blockEnd else { throw CARReaderError.unexpectedEOF }
            let hashLen = data[offset]
            offset += 1

            let digestLen = Int(hashLen)
            guard offset + digestLen <= blockEnd else { throw CARReaderError.unexpectedEOF }
            offset += digestLen

            let cidData = data[cidStart ..< offset]
            let dataOffset = offset
            let dataLength = totalLength - (offset - blockDataStart)
            rawBlockIndex[Data(cidData)] = BlockLocation(dataOffset: dataOffset, dataLength: dataLength)

            offset = blockEnd
        }
    }

    // MARK: - Block Access

    /// Retrieves and decodes the CBOR block for a given CID bytes key.
    public func decodeBlock(for cidBytes: Data) throws -> Any? {
        guard let location = rawBlockIndex[cidBytes] else {
            throw CARReaderError.blockNotFound(cidBytes.hexEncodedString())
        }

        let blockData = data[location.dataOffset ..< (location.dataOffset + location.dataLength)]

        guard let cbor = try? CBOR.decode([UInt8](blockData)) else {
            throw CARReaderError.decodingFailed("Failed to decode CBOR for block \(cidBytes.hexEncodedString())")
        }

        return try DAGCBOR.decodeCBORItem(cbor)
    }

    /// Retrieves and decodes the CBOR block for a given CID.
    public func decodeBlock(for cid: CID) throws -> Any? {
        try decodeBlock(for: cid.bytes)
    }

    /// Retrieves and decodes the CBOR block for a given CID hex string key (compatibility entry point).
    public func decodeBlock(for key: String) throws -> Any? {
        if let hexData = Data(hexString: key), let location = rawBlockIndex[hexData] {
            let blockData = data[location.dataOffset ..< (location.dataOffset + location.dataLength)]
            guard let cbor = try? CBOR.decode([UInt8](blockData)) else {
                throw CARReaderError.decodingFailed("Failed to decode CBOR for block \(key)")
            }
            return try DAGCBOR.decodeCBORItem(cbor)
        }
        throw CARReaderError.blockNotFound(key)
    }

    /// Returns raw block data for a given CID bytes key.
    public func rawBlockData(for cidBytes: Data) throws -> Data {
        guard let location = rawBlockIndex[cidBytes] else {
            throw CARReaderError.blockNotFound(cidBytes.hexEncodedString())
        }
        return Data(data[location.dataOffset ..< (location.dataOffset + location.dataLength)])
    }

    /// Returns raw block data for a given CID.
    public func rawBlockData(for cid: CID) throws -> Data {
        try rawBlockData(for: cid.bytes)
    }

    /// Returns raw block data for a given CID hex string key (compatibility entry point).
    public func rawBlockData(for key: String) throws -> Data {
        if let hexData = Data(hexString: key), let location = rawBlockIndex[hexData] {
            return Data(data[location.dataOffset ..< (location.dataOffset + location.dataLength)])
        }
        throw CARReaderError.blockNotFound(key)
    }

    /// Returns the CID hex string for a CID struct by encoding its bytes into a single preallocated buffer.
    public static func cidHex(from cid: CID) -> String {
        cid.bytes.hexEncodedString()
    }
}

// MARK: - Fast Hex Helpers

extension Data {
    func hexEncodedString() -> String {
        let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)
        var buffer = [UInt8](repeating: 0, count: count * 2)
        for (i, byte) in enumerated() {
            buffer[i * 2] = hexDigits[Int(byte >> 4)]
            buffer[i * 2 + 1] = hexDigits[Int(byte & 0x0F)]
        }
        return String(decoding: buffer, as: UTF8.self)
    }

    init?(hexString: String) {
        let utf8 = Array(hexString.utf8)
        guard utf8.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: utf8.count / 2)
        for i in stride(from: 0, to: utf8.count, by: 2) {
            guard let hi = Self.hexNibble(utf8[i]),
                  let lo = Self.hexNibble(utf8[i + 1]) else {
                return nil
            }
            data.append((hi << 4) | lo)
        }
        self = data
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            return byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            return byte - UInt8(ascii: "A") + 10
        default:
            return nil
        }
    }
}
