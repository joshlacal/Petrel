import Foundation
@testable import Petrel
import Testing

/// Minimal CBOR writer. The production encoder rejects the malformed shapes these
/// tests need, so fixtures are assembled byte by byte.
private enum TestCBOR {
    static func header(major: UInt8, argument: UInt64) -> Data {
        let prefix = major << 5
        var result = Data()
        switch argument {
        case 0 ..< 24:
            result.append(prefix | UInt8(argument))
        case 24 ... UInt64(UInt8.max):
            result.append(prefix | 24)
            result.append(UInt8(argument))
        case (UInt64(UInt8.max) + 1) ... UInt64(UInt16.max):
            result.append(prefix | 25)
            var value = UInt16(argument).bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt16>.size))
        case (UInt64(UInt16.max) + 1) ... UInt64(UInt32.max):
            result.append(prefix | 26)
            var value = UInt32(argument).bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt32>.size))
        default:
            result.append(prefix | 27)
            var value = argument.bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt64>.size))
        }
        return result
    }

    static func uint(_ value: UInt64) -> Data {
        header(major: 0, argument: value)
    }

    static func negative(_ value: Int64) -> Data {
        header(major: 1, argument: UInt64(-1 - value))
    }

    static func bytes(_ value: Data) -> Data {
        header(major: 2, argument: UInt64(value.count)) + value
    }

    static func text(_ value: String) -> Data {
        let utf8 = Data(value.utf8)
        return header(major: 3, argument: UInt64(utf8.count)) + utf8
    }

    static func array(_ items: [Data]) -> Data {
        items.reduce(header(major: 4, argument: UInt64(items.count))) { $0 + $1 }
    }

    static func map(_ pairs: [(String, Data)]) -> Data {
        pairs.reduce(header(major: 5, argument: UInt64(pairs.count))) { $0 + text($1.0) + $1.1 }
    }

    static func link(_ cid: CID) -> Data {
        header(major: 6, argument: 42) + bytes(Data([0x00]) + cid.bytes)
    }
}

/// Assembles CAR v1 archives from hand-built blocks.
private struct TestCARBuilder {
    private var blocks: [(cid: CID, payload: Data)] = []

    static func varint(_ value: Int) -> Data {
        var remaining = UInt64(value)
        var result = Data()
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            result.append(byte)
        } while remaining != 0
        return result
    }

    mutating func add(_ payload: Data) -> CID {
        let cid = CID.fromDAGCBOR(payload)
        blocks.append((cid, payload))
        return cid
    }

    func archive(root: CID) -> Data {
        let header = TestCBOR.map([
            ("roots", TestCBOR.array([TestCBOR.link(root)])),
            ("version", TestCBOR.uint(1)),
        ])

        var result = Self.varint(header.count) + header
        for block in blocks {
            let framed = block.cid.bytes + block.payload
            result += Self.varint(framed.count) + framed
        }
        return result
    }
}

@Suite("CAR and MST structural strictness")
struct CARStrictnessTests {
    private static let recordKey = "app.bsky.feed.post/3kabcdefghij"

    /// Builds a single-record repository whose MST root entry is `entryOverride`
    /// (defaulting to a well-formed entry) and returns the archive bytes.
    private func archive(
        entryOverride: ((CID) -> Data)? = nil,
        rootNodeOverride: ((Data) -> Data)? = nil,
        recordType: String = "app.bsky.feed.post"
    ) -> Data {
        var builder = TestCARBuilder()

        let recordCID = builder.add(TestCBOR.map([
            ("$type", TestCBOR.text(recordType)),
            ("text", TestCBOR.text("hello")),
            ("createdAt", TestCBOR.text("2026-01-01T00:00:00.000Z")),
        ]))

        let entry = entryOverride?(recordCID) ?? TestCBOR.map([
            ("p", TestCBOR.uint(0)),
            ("k", TestCBOR.bytes(Data(Self.recordKey.utf8))),
            ("v", TestCBOR.link(recordCID)),
        ])

        let defaultRootNode = TestCBOR.map([("e", TestCBOR.array([entry]))])
        let rootNodeCID = builder.add(rootNodeOverride?(entry) ?? defaultRootNode)

        let commitCID = builder.add(TestCBOR.map([
            ("did", TestCBOR.text("did:plc:testtesttesttesttesttest")),
            ("version", TestCBOR.uint(3)),
            ("data", TestCBOR.link(rootNodeCID)),
        ]))

        return builder.archive(root: commitCID)
    }

    private func parse(_ archive: Data) throws -> (CARRepository.Stats, [CARRepository.Record]) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("petrel-car-test-\(UUID().uuidString).car")
        try archive.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var records: [CARRepository.Record] = []
        let stats = try CARRepository.parse(fileURL: url) { records.append($0) }
        return (stats, records)
    }

    // MARK: - Well-formed input

    @Test("A well-formed repository still parses")
    func wellFormedArchiveParses() throws {
        let (stats, records) = try parse(archive())

        #expect(stats.blockCount == 3)
        #expect(stats.recordCount == 1)
        #expect(stats.decodedCount == 1)
        #expect(stats.failedCount == 0)
        #expect(records.count == 1)
        #expect(records.first?.collection == "app.bsky.feed.post")
        #expect(records.first?.rkey == "3kabcdefghij")
    }

    @Test("An MST node with no entries is not corruption")
    func emptyEntriesArrayParses() throws {
        let archive = archive(rootNodeOverride: { _ in
            TestCBOR.map([("e", TestCBOR.array([]))])
        })

        let (stats, records) = try parse(archive)

        #expect(stats.recordCount == 0)
        #expect(records.isEmpty)
    }

    @Test("Records with no matching Lexicon type are reported as downgraded")
    func unknownRecordTypeIsCountedAsDowngraded() throws {
        let (stats, _) = try parse(archive(recordType: "com.example.notALexicon"))

        #expect(stats.decodedCount == 1)
        #expect(stats.downgradedCount == 1)
        #expect(stats.failedCount == 0)
    }

    // MARK: - MST structure

    @Test("A missing entries array throws")
    func missingEntriesArrayThrows() throws {
        let archive = archive(rootNodeOverride: { _ in
            TestCBOR.map([("l", Data([0xF6]))])
        })

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A non-map element in the entries array throws")
    func nonMapEntryElementThrows() throws {
        let archive = archive(rootNodeOverride: { entry in
            TestCBOR.map([("e", TestCBOR.array([entry, TestCBOR.text("not an entry")]))])
        })

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A missing prefix count throws instead of defaulting to zero")
    func missingPrefixCountThrows() throws {
        let archive = archive { recordCID in
            TestCBOR.map([
                ("k", TestCBOR.bytes(Data(Self.recordKey.utf8))),
                ("v", TestCBOR.link(recordCID)),
            ])
        }

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A non-integer prefix count throws")
    func nonIntegerPrefixCountThrows() throws {
        let archive = archive { recordCID in
            TestCBOR.map([
                ("p", TestCBOR.text("0")),
                ("k", TestCBOR.bytes(Data(Self.recordKey.utf8))),
                ("v", TestCBOR.link(recordCID)),
            ])
        }

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A negative prefix count throws")
    func negativePrefixCountThrows() throws {
        let archive = archive { recordCID in
            TestCBOR.map([
                ("p", TestCBOR.negative(-1)),
                ("k", TestCBOR.bytes(Data(Self.recordKey.utf8))),
                ("v", TestCBOR.link(recordCID)),
            ])
        }

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A prefix count longer than the previous key throws")
    func overlongPrefixCountThrows() throws {
        let archive = archive { recordCID in
            TestCBOR.map([
                ("p", TestCBOR.uint(4)),
                ("k", TestCBOR.bytes(Data(Self.recordKey.utf8))),
                ("v", TestCBOR.link(recordCID)),
            ])
        }

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A missing key suffix throws instead of dropping the record")
    func missingKeySuffixThrows() throws {
        let archive = archive { recordCID in
            TestCBOR.map([
                ("p", TestCBOR.uint(0)),
                ("v", TestCBOR.link(recordCID)),
            ])
        }

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A key suffix that is not valid UTF-8 throws")
    func invalidUTF8KeySuffixThrows() throws {
        let archive = archive { recordCID in
            TestCBOR.map([
                ("p", TestCBOR.uint(0)),
                ("k", TestCBOR.bytes(Data([0xFF, 0xFE, 0xFD]))),
                ("v", TestCBOR.link(recordCID)),
            ])
        }

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A missing value CID throws instead of dropping the record")
    func missingValueCIDThrows() throws {
        let archive = archive { _ in
            TestCBOR.map([
                ("p", TestCBOR.uint(0)),
                ("k", TestCBOR.bytes(Data(Self.recordKey.utf8))),
            ])
        }

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    // MARK: - Block framing

    @Test("A truncated archive throws instead of indexing as a partial one")
    func truncatedArchiveThrows() throws {
        let complete = archive()
        let truncated = complete.prefix(complete.count - 8)

        #expect(throws: CARReaderError.self) { try parse(Data(truncated)) }
    }

    @Test("A truncated block-length varint throws instead of ending the scan")
    func truncatedVarintThrows() throws {
        // 0x81 sets the continuation bit with no byte following it.
        let archive = archive() + Data([0x81])

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A block length that overruns the archive throws")
    func overlongBlockLengthThrows() throws {
        var archive = archive()
        archive += TestCARBuilder.varint(4096)
        archive += Data(repeating: 0x00, count: 16)

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A zero-length block throws")
    func zeroLengthBlockThrows() throws {
        let archive = archive() + Data([0x00])

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A CID that overruns its own block throws")
    func cidOverrunningBlockThrows() throws {
        // A four-byte block claiming a 32-byte multihash digest.
        let block = Data([0x01, 0x71, 0x12, 0x20])
        let archive = archive() + TestCARBuilder.varint(block.count) + block

        #expect(throws: CARReaderError.self) { try parse(archive) }
    }
}
