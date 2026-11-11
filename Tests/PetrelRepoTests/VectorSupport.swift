import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// Loads vendored vector files from `Tests/PetrelRepoTests/Vectors`.
enum Vectors {
    struct Missing: Error, CustomStringConvertible {
        let path: String
        var description: String { "missing vector file Vectors/\(path)" }
    }

    static func url(_ path: String) throws -> URL {
        guard let base = Bundle.module.url(forResource: "Vectors", withExtension: nil) else {
            throw Missing(path: path)
        }
        let url = base.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Missing(path: path)
        }
        return url
    }

    static func data(_ path: String) throws -> Data {
        try Data(contentsOf: url(path))
    }

    static func decode<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
        try JSONDecoder().decode(type, from: data(path))
    }

}

/// Splits vendored JSON into the exact bytes of its parts, without
/// re-serializing them. The data-model vectors distinguish `123` from
/// `123.0`; passing them through a general JSON library would erase that.
enum RawJSON {
    struct Malformed: Error {}

    /// The raw bytes of each element of a JSON array.
    static func elements(ofArray data: Data) throws -> [Data] {
        try children(of: Array(data), open: UInt8(ascii: "["), close: UInt8(ascii: "]")).map(\.value)
    }

    /// The keys and raw value bytes of a JSON object, in file order.
    static func members(ofObject data: Data) throws -> [(key: String, value: Data)] {
        try children(of: Array(data), open: UInt8(ascii: "{"), close: UInt8(ascii: "}"))
            .map { (key: $0.key ?? "", value: $0.value) }
    }

    /// The raw value of one member, or `nil` if the object has no such key.
    static func member(_ name: String, of data: Data) throws -> Data? {
        try members(ofObject: data).first { $0.key == name }?.value
    }

    /// The decoded text of a raw JSON string with no escapes.
    static func string(_ data: Data) throws -> String {
        let bytes = Array(data)
        guard bytes.count >= 2, bytes.first == UInt8(ascii: "\""), bytes.last == UInt8(ascii: "\""),
              !bytes.contains(UInt8(ascii: "\\")) else {
            throw Malformed()
        }
        return String(decoding: bytes[1 ..< bytes.count - 1], as: UTF8.self)
    }

    private static func children(
        of bytes: [UInt8], open: UInt8, close: UInt8
    ) throws -> [(key: String?, value: Data)] {
        var offset = 0
        func skipWhitespace() {
            while offset < bytes.count, [0x20, 0x09, 0x0a, 0x0d].contains(bytes[offset]) { offset += 1 }
        }
        func endOfString(from start: Int) throws -> Int {
            var index = start + 1
            while index < bytes.count {
                if bytes[index] == UInt8(ascii: "\\") {
                    index += 2
                } else if bytes[index] == UInt8(ascii: "\"") {
                    return index + 1
                } else {
                    index += 1
                }
            }
            throw Malformed()
        }
        func endOfValue(from start: Int) throws -> Int {
            switch bytes[start] {
            case UInt8(ascii: "\""):
                return try endOfString(from: start)
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                var depth = 0
                var index = start
                while index < bytes.count {
                    switch bytes[index] {
                    case UInt8(ascii: "\""):
                        index = try endOfString(from: index)
                        continue
                    case UInt8(ascii: "{"), UInt8(ascii: "["):
                        depth += 1
                    case UInt8(ascii: "}"), UInt8(ascii: "]"):
                        depth -= 1
                        if depth == 0 { return index + 1 }
                    default:
                        break
                    }
                    index += 1
                }
                throw Malformed()
            default:
                var index = start
                while index < bytes.count,
                      ![0x2c, 0x5d, 0x7d, 0x20, 0x09, 0x0a, 0x0d].contains(bytes[index]) {
                    index += 1
                }
                return index
            }
        }

        skipWhitespace()
        guard offset < bytes.count, bytes[offset] == open else { throw Malformed() }
        offset += 1
        var result: [(key: String?, value: Data)] = []
        while true {
            skipWhitespace()
            guard offset < bytes.count else { throw Malformed() }
            if bytes[offset] == close { return result }
            var key: String?
            if open == UInt8(ascii: "{") {
                let end = try endOfString(from: offset)
                key = try string(Data(bytes[offset ..< end]))
                offset = end
                skipWhitespace()
                guard offset < bytes.count, bytes[offset] == UInt8(ascii: ":") else { throw Malformed() }
                offset += 1
                skipWhitespace()
            }
            guard offset < bytes.count else { throw Malformed() }
            let end = try endOfValue(from: offset)
            result.append((key, Data(bytes[offset ..< end])))
            offset = end
            skipWhitespace()
            if offset < bytes.count, bytes[offset] == UInt8(ascii: ",") { offset += 1 }
        }
    }
}

/// A scratch directory removed when the value is deinitialized.
final class ScratchDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("petrel-repo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func file(_ name: String) -> URL { url.appendingPathComponent(name) }
}

/// An independent, bottom-up MST builder used as an oracle and to make large
/// trees quickly. It shares no code with `RepositoryMST`: it partitions a
/// sorted key list by key depth, layer by layer, and encodes each node with
/// the public codec.
enum BulkMST {
    struct Entry {
        let path: PublicRepositoryPath
        let recordCID: CID
    }

    /// Builds the tree for `entries` (sorted by key) and returns its root.
    static func build(
        _ entries: [Entry],
        options: RepositoryMSTOptions = .strict,
        emit: (PublicRepositoryBlock) async throws -> Void
    ) async throws -> CID {
        guard let top = entries.map(\.path.keyDepth).max() else {
            let bytes = PublicRepositoryGenesisCodec.canonicalEmptyMST
            let cid = CID.fromDAGCBOR(bytes)
            try await emit(.init(cid: cid, bytes: bytes))
            return cid
        }
        return try await node(entries[...], layer: top, options: options, emit: emit)
    }

    private static func node(
        _ entries: ArraySlice<Entry>,
        layer: Int,
        options: RepositoryMSTOptions,
        emit: (PublicRepositoryBlock) async throws -> Void
    ) async throws -> CID {
        var leaves: [RepositoryMSTLeaf] = []
        var leftTreeCID: CID?
        var runStart = entries.startIndex
        var pending: Entry?

        func closeRun(upTo end: Int) async throws {
            let run = entries[runStart ..< end]
            let subtree = run.isEmpty
                ? nil
                : try await node(run, layer: layer - 1, options: options, emit: emit)
            if let previous = pending {
                leaves.append(.init(path: previous.path, recordCID: previous.recordCID, rightTreeCID: subtree))
            } else {
                leftTreeCID = subtree
            }
        }

        for index in entries.indices where entries[index].path.keyDepth == layer {
            try await closeRun(upTo: index)
            pending = entries[index]
            runStart = index + 1
        }
        try await closeRun(upTo: entries.endIndex)

        let encoded = try RepositoryMSTCodec.encode(
            RepositoryMSTCodec.node(leaves: leaves, leftTreeCID: leftTreeCID, options: options),
            options: options
        )
        let cid = CID.fromDAGCBOR(encoded)
        try await emit(.init(cid: cid, bytes: encoded))
        return cid
    }
}

extension PublicRecord {
    /// A small valid record of the given collection.
    static func sample(_ collection: String, text: String) -> PublicRecord {
        ["$type": .string(collection), "text": .string(text)]
    }
}
