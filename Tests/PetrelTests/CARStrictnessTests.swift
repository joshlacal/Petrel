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

    mutating func add(cid: CID, payload: Data) {
        blocks.append((cid, payload))
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

    // MARK: - Hostile and Multi-Byte MST Structures

    @Test("A cyclic MST throws instead of overflowing the stack")
    func cyclicMSTThrows() throws {
        var builder = TestCARBuilder()
        let recordCID = builder.add(TestCBOR.map([
            ("$type", TestCBOR.text("app.bsky.feed.post")),
            ("text", TestCBOR.text("hello")),
            ("createdAt", TestCBOR.text("2026-01-01T00:00:00.000Z")),
        ]))

        let cyclicCID = try CID(bytes: Data([0x01, 0x71, 0x12, 0x20] + [UInt8](repeating: 0xCC, count: 32)))
        let cyclicNode = TestCBOR.map([
            ("l", TestCBOR.link(cyclicCID)),
            ("e", TestCBOR.array([
                TestCBOR.map([
                    ("p", TestCBOR.uint(0)),
                    ("k", TestCBOR.bytes(Data(Self.recordKey.utf8))),
                    ("v", TestCBOR.link(recordCID)),
                ]),
            ])),
        ])
        builder.add(cid: cyclicCID, payload: cyclicNode)

        let commitCID = builder.add(TestCBOR.map([
            ("did", TestCBOR.text("did:plc:testtesttesttesttesttest")),
            ("version", TestCBOR.uint(3)),
            ("data", TestCBOR.link(cyclicCID)),
        ]))

        let archive = builder.archive(root: commitCID)
        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("An over-deep MST exceeding 128 layers throws instead of exhausting the call stack")
    func overDeepMSTThrows() throws {
        var builder = TestCARBuilder()
        let recordCID = builder.add(TestCBOR.map([
            ("$type", TestCBOR.text("app.bsky.feed.post")),
            ("text", TestCBOR.text("hello")),
            ("createdAt", TestCBOR.text("2026-01-01T00:00:00.000Z")),
        ]))

        var currentChildCID: CID?
        for i in 0 ..< 130 {
            var nodePairs: [(String, Data)] = [
                ("e", TestCBOR.array([
                    TestCBOR.map([
                        ("p", TestCBOR.uint(0)),
                        ("k", TestCBOR.bytes(Data("app.bsky.feed.post/key\(i)".utf8))),
                        ("v", TestCBOR.link(recordCID)),
                    ]),
                ])),
            ]
            if let child = currentChildCID {
                nodePairs.append(("l", TestCBOR.link(child)))
            }
            currentChildCID = builder.add(TestCBOR.map(nodePairs))
        }

        let commitCID = builder.add(TestCBOR.map([
            ("did", TestCBOR.text("did:plc:testtesttesttesttesttest")),
            ("version", TestCBOR.uint(3)),
            ("data", TestCBOR.link(currentChildCID!)),
        ]))

        let archive = builder.archive(root: commitCID)
        #expect(throws: CARReaderError.self) { try parse(archive) }
    }

    @Test("A valid multi-level tree with multi-byte UTF-8 record keys reconstructs keys correctly")
    func multiByteUTF8KeyReconstruction() throws {
        var builder = TestCARBuilder()
        let record1CID = builder.add(TestCBOR.map([
            ("$type", TestCBOR.text("app.bsky.feed.post")),
            ("text", TestCBOR.text("post 1")),
            ("createdAt", TestCBOR.text("2026-01-01T00:00:00.000Z")),
        ]))
        let record2CID = builder.add(TestCBOR.map([
            ("$type", TestCBOR.text("app.bsky.feed.post")),
            ("text", TestCBOR.text("post 2")),
            ("createdAt", TestCBOR.text("2026-01-01T00:00:00.000Z")),
        ]))
        let record3CID = builder.add(TestCBOR.map([
            ("$type", TestCBOR.text("app.bsky.feed.post")),
            ("text", TestCBOR.text("post 3")),
            ("createdAt", TestCBOR.text("2026-01-01T00:00:00.000Z")),
        ]))

        // Subtree child node
        // Key: "app.bsky.feed.post/🎉middle" (19 + 4 + 6 = 29 bytes)
        let childNodeCID = builder.add(TestCBOR.map([
            ("e", TestCBOR.array([
                TestCBOR.map([
                    ("p", TestCBOR.uint(0)),
                    ("k", TestCBOR.bytes(Data("app.bsky.feed.post/🎉middle".utf8))),
                    ("v", TestCBOR.link(record2CID)),
                ]),
            ])),
        ]))

        // Root node:
        // Entry 1: Key = "app.bsky.feed.post/🎉first" (19 + 4 + 5 = 28 bytes), t = childNodeCID
        // Entry 2: Prefix count = 23 bytes ("app.bsky.feed.post/🎉"), suffix = "last" -> Key = "app.bsky.feed.post/🎉last"
        let prefix23Bytes = Data("app.bsky.feed.post/🎉".utf8).count
        #expect(prefix23Bytes == 23)

        let rootNodeCID = builder.add(TestCBOR.map([
            ("e", TestCBOR.array([
                TestCBOR.map([
                    ("p", TestCBOR.uint(0)),
                    ("k", TestCBOR.bytes(Data("app.bsky.feed.post/🎉first".utf8))),
                    ("v", TestCBOR.link(record1CID)),
                    ("t", TestCBOR.link(childNodeCID)),
                ]),
                TestCBOR.map([
                    ("p", TestCBOR.uint(UInt64(prefix23Bytes))),
                    ("k", TestCBOR.bytes(Data("last".utf8))),
                    ("v", TestCBOR.link(record3CID)),
                ]),
            ])),
        ]))

        let commitCID = builder.add(TestCBOR.map([
            ("did", TestCBOR.text("did:plc:testtesttesttesttesttest")),
            ("version", TestCBOR.uint(3)),
            ("data", TestCBOR.link(rootNodeCID)),
        ]))

        let (stats, records) = try parse(builder.archive(root: commitCID))

        #expect(stats.recordCount == 3)
        #expect(stats.decodedCount == 3)
        #expect(stats.failedCount == 0)
        #expect(records.count == 3)
        #expect(records[0].collection == "app.bsky.feed.post")
        #expect(records[0].rkey == "🎉first")
        #expect(records[1].collection == "app.bsky.feed.post")
        #expect(records[1].rkey == "🎉middle")
        #expect(records[2].collection == "app.bsky.feed.post")
        #expect(records[2].rkey == "🎉last")
    }
}
