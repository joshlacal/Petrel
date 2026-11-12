import Foundation
import Petrel
import PetrelRepo
import Testing

@Suite("Block stores and CAR byte adapters")
struct RepositoryBlockStoreTests {
    private func block(_ text: String) -> PublicRepositoryBlock {
        // A one-entry DAG-CBOR map {"t": text}.
        let utf8 = Array(text.utf8)
        precondition(utf8.count < 24)
        let bytes = Data([0xa1, 0x61, 0x74, 0x60 + UInt8(utf8.count)] + utf8)
        return PublicRepositoryBlock(cid: CID.fromDAGCBOR(bytes), bytes: bytes)
    }

    private func exercise(_ store: any RepositoryBlockStore) async throws {
        let blocks = ["a", "b", "c"].map(block)
        #expect(try await store.blockCount() == 0)
        try await store.put(blocks)
        try await store.put(blocks[1])
        #expect(try await store.blockCount() == 3)
        #expect(try await store.storedCIDs() == blocks.map(\.cid))
        for block in blocks {
            #expect(try await store.block(for: block.cid) == block.bytes)
            #expect(try await store.contains(block.cid))
        }
        let absent = self.block("absent")
        #expect(try await store.block(for: absent.cid) == nil)
        #expect(try await !store.contains(absent.cid))

        // A block whose bytes do not match its CID, and a non-repository
        // CID, are refused.
        await #expect(throws: RepositoryBlockStoreError.blockCIDMismatch) {
            try await store.put(PublicRepositoryBlock(cid: absent.cid, bytes: blocks[0].bytes))
        }
        let raw = Data("blob".utf8)
        await #expect(throws: RepositoryBlockStoreError.unsupportedCID) {
            try await store.put(PublicRepositoryBlock(cid: CID.fromBlob(raw), bytes: raw))
        }
        #expect(try await store.blockCount() == 3)
    }

    @Test("in-memory store")
    func inMemory() async throws {
        try await exercise(InMemoryRepositoryBlockStore())
        let capped = InMemoryRepositoryBlockStore(maximumBytes: 8)
        try await capped.put(block("a"))
        await #expect(throws: RepositoryBlockStoreError.capacityExceeded) {
            try await capped.put(self.block("bbbbbbbb"))
        }
    }

    @Test("file-backed store: buffered and flushed reads, reopen, corruption")
    func fileBacked() async throws {
        let scratch = try ScratchDirectory()
        let url = scratch.file("blocks")
        do {
            let store = try FileRepositoryBlockStore(url: url)
            try await exercise(store)
            // Reads are served from the write buffer before a flush and
            // from the file after it.
            let late = block("late")
            try await store.put(late)
            #expect(try await store.block(for: late.cid) == late.bytes)
            try await store.flush()
            #expect(try await store.block(for: late.cid) == late.bytes)
            #expect(try await store.block(for: block("a").cid) == block("a").bytes)
        }

        // Reopening rebuilds the same index, in the same order.
        let reopened = try FileRepositoryBlockStore(url: url)
        #expect(try await reopened.blockCount() == 4)
        #expect(try await reopened.storedCIDs() == ["a", "b", "c", "late"].map { block($0).cid })
        #expect(try await reopened.block(for: block("c").cid) == block("c").bytes)
        // Appending after a reopen keeps earlier blocks intact.
        try await reopened.put(block("more"))
        try await reopened.flush()
        #expect(try await FileRepositoryBlockStore(url: url).blockCount() == 5)

        // A flipped byte in a stored block is caught when the file is
        // opened with verification, and a truncated file is always caught.
        var bytes = try Data(contentsOf: url)
        bytes[bytes.count - 1] ^= 0x01
        try bytes.write(to: scratch.file("flipped"))
        #expect(throws: RepositoryBlockStoreError.corruptStore) {
            try FileRepositoryBlockStore(url: scratch.file("flipped"))
        }
        try bytes.dropLast(3).write(to: scratch.file("truncated"))
        #expect(throws: RepositoryBlockStoreError.corruptStore) {
            try FileRepositoryBlockStore(url: scratch.file("truncated"), verifyingExistingBlocks: false)
        }
    }

    @Test("a file-backed store with more data than its write buffer")
    func fileBackedLarge() async throws {
        let scratch = try ScratchDirectory()
        let store = try FileRepositoryBlockStore(url: scratch.file("blocks"))
        // 3,000 blocks of ~1 KB cross the 1 MiB buffer several times.
        var blocks: [PublicRepositoryBlock] = []
        for index in 0 ..< 3_000 {
            var bytes = Data([0xa1, 0x61, 0x74, 0x59, 0x03, 0xe8])
            bytes.append(Data(repeating: UInt8(index % 251), count: 996))
            bytes.append(contentsOf: withUnsafeBytes(of: UInt32(index).bigEndian) { Array($0) })
            blocks.append(.init(cid: CID.fromDAGCBOR(bytes), bytes: bytes))
        }
        try await store.put(blocks)
        for index in [0, 1, 1_023, 1_024, 2_047, 2_999] {
            #expect(try await store.block(for: blocks[index].cid) == blocks[index].bytes)
        }
        try await store.flush()
        let reopened = try FileRepositoryBlockStore(url: scratch.file("blocks"))
        #expect(try await reopened.storedCIDs() == blocks.map(\.cid))
        #expect(try await reopened.block(for: blocks[2_999].cid) == blocks[2_999].bytes)
    }

    @Test("data and file byte sources and sinks carry the same bytes")
    func byteAdapters() async throws {
        let scratch = try ScratchDirectory()
        let payload = Data((0 ..< 200_000).map { UInt8(truncatingIfNeeded: $0 &* 31) })

        let fileSink = try FileCARByteSink(url: scratch.file("payload"))
        let dataSink = DataCARByteSink()
        for start in stride(from: 0, to: payload.count, by: 7_919) {
            let chunk = payload[start ..< min(start + 7_919, payload.count)]
            try await fileSink.write(Data(chunk))
            try await dataSink.write(Data(chunk))
        }
        try await fileSink.synchronize()
        #expect(await dataSink.data == payload)
        #expect(try Data(contentsOf: scratch.file("payload")) == payload)

        func drain(_ source: any PublicRepositoryCARByteSource) async throws -> Data {
            var result = Data()
            while let chunk = try await source.read(maximumBytes: 4_096) {
                #expect(!chunk.isEmpty && chunk.count <= 4_096)
                result.append(chunk)
            }
            return result
        }
        #expect(try await drain(DataCARByteSource(payload)) == payload)
        // A slice with a non-zero start index reads correctly too.
        #expect(try await drain(DataCARByteSource(payload.dropFirst(1_000))) == payload.dropFirst(1_000))
        #expect(try await drain(FileCARByteSource(url: scratch.file("payload"))) == payload)
        #expect(throws: RepositoryBlockStoreError.self) {
            try FileCARByteSource(url: scratch.file("does-not-exist"))
        }
    }
}
