// This file adapts the MST node serialization and key-layer rules from
// bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/mst/{mst,util}.ts, used under the repository's
// MIT OR Apache-2.0 notice policy recorded in THIRD_PARTY_NOTICES.md.

import Crypto
import Foundation
import Petrel

public struct RepositoryMSTEntry: Sendable, Equatable {
    public let prefixLength: Int
    public let keySuffix: Data
    public let valueCID: CID
    public let rightTreeCID: CID?

    public init(prefixLength: Int, keySuffix: Data, valueCID: CID, rightTreeCID: CID?) {
        self.prefixLength = prefixLength
        self.keySuffix = keySuffix
        self.valueCID = valueCID
        self.rightTreeCID = rightTreeCID
    }
}

public struct RepositoryMSTNode: Sendable, Equatable {
    public let leftTreeCID: CID?
    public let entries: [RepositoryMSTEntry]

    public init(leftTreeCID: CID?, entries: [RepositoryMSTEntry]) {
        self.leftTreeCID = leftTreeCID
        self.entries = entries
    }
}

public struct RepositoryMSTLeaf: Sendable, Equatable {
    public let path: PublicRepositoryPath
    public let recordCID: CID
    public let rightTreeCID: CID?

    public init(path: PublicRepositoryPath, recordCID: CID, rightTreeCID: CID? = nil) {
        self.path = path
        self.recordCID = recordCID
        self.rightTreeCID = rightTreeCID
    }
}

public enum RepositoryMSTCodec {
    public static func keyDepth(for path: PublicRepositoryPath) -> Int {
        path.keyDepth
    }

    public static func keyDepth(forASCIIKey key: String) -> Int {
        keyDepth(forASCIIBytes: Data(key.utf8))
    }

    /// The repository MST is a fanout-4 search tree: each complete pair of
    /// leading zero digest bits contributes one layer.
    public static func keyDepth(forASCIIBytes bytes: Data) -> Int {
        let digest = SHA256.hash(data: bytes)
        var depth = 0
        for byte in digest {
            let zeros = byte.leadingZeroBitCount
            depth += zeros / 2
            if zeros < 8 { break }
        }
        return depth
    }

    public static func node(
        leaves: [RepositoryMSTLeaf],
        leftTreeCID: CID? = nil
    ) throws -> RepositoryMSTNode {
        var entries: [RepositoryMSTEntry] = []
        var previous = Data()
        for (index, leaf) in leaves.enumerated() {
            try PublicRepositoryCID.validate(leaf.recordCID)
            if let right = leaf.rightTreeCID {
                try PublicRepositoryCID.validate(right)
            }
            let key = leaf.path.mstKeyBytes
            if index > 0, !lexicographicallyPrecedes(previous, key) {
                throw RepositoryMSTValidationError.keysNotStrictlyIncreasing
            }
            let prefix = index == 0 ? 0 : commonPrefixLength(previous, key)
            entries.append(.init(
                prefixLength: prefix,
                keySuffix: Data(key.dropFirst(prefix)),
                valueCID: leaf.recordCID,
                rightTreeCID: leaf.rightTreeCID
            ))
            previous = key
        }
        if let leftTreeCID {
            try PublicRepositoryCID.validate(leftTreeCID)
        }
        return RepositoryMSTNode(leftTreeCID: leftTreeCID, entries: entries)
    }

    public static func reconstructedLeaves(from node: RepositoryMSTNode) throws -> [RepositoryMSTLeaf] {
        var previous = Data()
        var leaves: [RepositoryMSTLeaf] = []
        for (index, entry) in node.entries.enumerated() {
            guard entry.prefixLength >= 0,
                  entry.prefixLength <= previous.count,
                  !entry.keySuffix.isEmpty,
                  index > 0 || entry.prefixLength == 0 else {
                throw RepositoryMSTValidationError.invalidPrefixCompression
            }
            let key = Data(previous.prefix(entry.prefixLength)) + entry.keySuffix
            let expectedPrefix = index == 0 ? 0 : commonPrefixLength(previous, key)
            guard entry.prefixLength == expectedPrefix else {
                throw RepositoryMSTValidationError.invalidPrefixCompression
            }
            guard index == 0 || lexicographicallyPrecedes(previous, key) else {
                throw RepositoryMSTValidationError.keysNotStrictlyIncreasing
            }
            guard let slash = key.firstIndex(of: 0x2f),
                  !key[key.index(after: slash)...].contains(0x2f),
                  let collection = String(data: key[..<slash], encoding: .ascii),
                  let recordKey = String(data: key[key.index(after: slash)...], encoding: .ascii) else {
                throw RepositoryMSTValidationError.invalidPath
            }
            let path: PublicRepositoryPath
            do {
                path = try PublicRepositoryPath(collection: collection, recordKey: recordKey)
            } catch {
                throw RepositoryMSTValidationError.invalidPath
            }
            try PublicRepositoryCID.validate(entry.valueCID)
            if let right = entry.rightTreeCID {
                try PublicRepositoryCID.validate(right)
            }
            leaves.append(.init(path: path, recordCID: entry.valueCID, rightTreeCID: entry.rightTreeCID))
            previous = key
        }
        return leaves
    }

    public static func encode(_ node: RepositoryMSTNode) throws -> Data {
        if let left = node.leftTreeCID {
            try PublicRepositoryCID.validate(left)
        }
        _ = try reconstructedLeaves(from: node)
        return try encodeUnchecked(node)
    }

    static func encodeUnchecked(_ node: RepositoryMSTNode) throws -> Data {
        let entries: [Any] = node.entries.map { entry in
            OrderedCBORMap(entries: [
                (key: "p", value: UInt64(entry.prefixLength)),
                (key: "k", value: entry.keySuffix),
                (key: "v", value: ATProtoLink(cid: entry.valueCID)),
                (key: "t", value: entry.rightTreeCID.map { ATProtoLink(cid: $0) } ?? NSNull()),
            ])
        }
        return try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "l", value: node.leftTreeCID.map { ATProtoLink(cid: $0) } ?? NSNull()),
            (key: "e", value: entries),
        ]))
    }

    /// Decodes only the exact repository MST schema. The parser checks shortest
    /// CBOR forms and canonical map order while consuming, then re-encodes as a
    /// final byte-for-byte canonicality check.
    public static func decode(_ bytes: Data) throws -> RepositoryMSTNode {
        var parser = MSTCBORParser(bytes)
        let node = try parser.parseNode()
        guard parser.isAtEnd else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        _ = try reconstructedLeaves(from: node)
        let canonical = try encodeUnchecked(node)
        guard canonical == bytes else {
            throw RepositoryMSTValidationError.nonCanonicalNode
        }
        return node
    }

    public static func lexicographicallyPrecedes(_ lhs: Data, _ rhs: Data) -> Bool {
        let minCount = min(lhs.count, rhs.count)
        if minCount > 0 {
            let cmp: Int32 = lhs.withUnsafeBytes { lhsRaw in
                rhs.withUnsafeBytes { rhsRaw in
                    guard let lhsPtr = lhsRaw.baseAddress,
                          let rhsPtr = rhsRaw.baseAddress else {
                        return 0
                    }
                    return memcmp(lhsPtr, rhsPtr, minCount)
                }
            }
            if cmp != 0 {
                return cmp < 0
            }
        }
        return lhs.count < rhs.count
    }

    public static func commonPrefixLength(_ lhs: Data, _ rhs: Data) -> Int {
        let minCount = min(lhs.count, rhs.count)
        guard minCount > 0 else { return 0 }
        return lhs.withUnsafeBytes { lhsRaw in
            rhs.withUnsafeBytes { rhsRaw in
                guard let lhsPtr = lhsRaw.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let rhsPtr = rhsRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                if memcmp(lhsPtr, rhsPtr, minCount) == 0 {
                    return minCount
                }
                var count = 0
                while count < minCount && lhsPtr[count] == rhsPtr[count] {
                    count += 1
                }
                return count
            }
        }
    }
}

private struct MSTCBORParser {
    private let bytes: [UInt8]
    private(set) var offset = 0

    init(_ data: Data) {
        bytes = Array(data)
    }

    var isAtEnd: Bool { offset == bytes.count }

    mutating func parseNode() throws -> RepositoryMSTNode {
        guard try readLength(major: 5) == 2 else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        let firstKey = try readText()
        guard firstKey == "e" else {
            if firstKey == "l" { throw RepositoryMSTValidationError.nonCanonicalNode }
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        let count = try readLength(major: 4)
        guard count <= PublicRepositoryLimits.maximumPermittedMSTEntriesPerNode else {
            throw RepositoryMSTValidationError.entryLimitExceeded
        }
        var entries: [RepositoryMSTEntry] = []
        entries.reserveCapacity(count)
        for _ in 0 ..< count {
            entries.append(try parseEntry())
        }
        guard try readText() == "l" else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        return RepositoryMSTNode(leftTreeCID: try readOptionalLink(), entries: entries)
    }

    private mutating func parseEntry() throws -> RepositoryMSTEntry {
        guard try readLength(major: 5) == 4 else {
            throw RepositoryMSTValidationError.invalidEntrySchema
        }
        guard try readText() == "k" else { throw RepositoryMSTValidationError.invalidEntrySchema }
        let suffix = try readBytes()
        guard try readText() == "p" else { throw RepositoryMSTValidationError.invalidEntrySchema }
        let prefix = try readUnsigned()
        guard prefix <= UInt64(PublicRepositoryPath.maximumMSTKeyBytes) else {
            throw RepositoryMSTValidationError.invalidPrefixCompression
        }
        guard try readText() == "t" else { throw RepositoryMSTValidationError.invalidEntrySchema }
        let tree = try readOptionalLink()
        guard try readText() == "v" else { throw RepositoryMSTValidationError.invalidEntrySchema }
        let value = try readRequiredLink()
        return RepositoryMSTEntry(
            prefixLength: Int(prefix),
            keySuffix: suffix,
            valueCID: value,
            rightTreeCID: tree
        )
    }

    private mutating func readOptionalLink() throws -> CID? {
        if peek() == 0xf6 {
            offset += 1
            return nil
        }
        return try readRequiredLink()
    }

    private mutating func readRequiredLink() throws -> CID {
        guard try readLength(major: 6) == 42 else {
            throw RepositoryMSTValidationError.invalidCIDLink
        }
        let payload = try readBytes()
        guard payload.count == 37, payload.first == 0 else {
            throw RepositoryMSTValidationError.invalidCIDLink
        }
        let cid: CID
        do {
            cid = try CID(bytes: Data(payload.dropFirst()))
            try PublicRepositoryCID.validate(cid)
        } catch {
            throw RepositoryMSTValidationError.invalidCIDLink
        }
        return cid
    }

    private mutating func readText() throws -> String {
        let length = try readLength(major: 3)
        guard length <= bytes.count - offset else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        let slice = bytes[offset ..< offset + length]
        offset += length
        guard let value = String(bytes: slice, encoding: .utf8) else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        return value
    }

    private mutating func readBytes() throws -> Data {
        let length = try readLength(major: 2)
        guard length <= bytes.count - offset else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        let result = Data(bytes[offset ..< offset + length])
        offset += length
        return result
    }

    private mutating func readUnsigned() throws -> UInt64 {
        try readArgument(expectedMajor: 0)
    }

    private mutating func readLength(major: UInt8) throws -> Int {
        let argument = try readArgument(expectedMajor: major)
        guard argument <= UInt64(Int.max) else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        return Int(argument)
    }

    private mutating func readArgument(expectedMajor: UInt8) throws -> UInt64 {
        guard offset < bytes.count else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        let initial = bytes[offset]
        offset += 1
        guard initial >> 5 == expectedMajor else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        let additional = initial & 0x1f
        switch additional {
        case 0 ... 23:
            return UInt64(additional)
        case 24:
            let value = try readFixed(1)
            guard value >= 24 else { throw RepositoryMSTValidationError.nonCanonicalNode }
            return value
        case 25:
            let value = try readFixed(2)
            guard value > UInt8.max else { throw RepositoryMSTValidationError.nonCanonicalNode }
            return value
        case 26:
            let value = try readFixed(4)
            guard value > UInt16.max else { throw RepositoryMSTValidationError.nonCanonicalNode }
            return value
        case 27:
            let value = try readFixed(8)
            guard value > UInt32.max else { throw RepositoryMSTValidationError.nonCanonicalNode }
            return value
        default:
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
    }

    private mutating func readFixed(_ count: Int) throws -> UInt64 {
        guard count <= bytes.count - offset else {
            throw RepositoryMSTValidationError.invalidNodeSchema
        }
        var result: UInt64 = 0
        for byte in bytes[offset ..< offset + count] {
            result = (result << 8) | UInt64(byte)
        }
        offset += count
        return result
    }

    private func peek() -> UInt8? {
        offset < bytes.count ? bytes[offset] : nil
    }
}
