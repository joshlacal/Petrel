import Foundation
import Petrel

/// A place repository blocks are read from and written to.
///
/// A store holds blocks keyed by CID and nothing else: no notion of a head
/// commit, no garbage collection. ``Repository`` reads through it lazily, so a
/// store decides how much of a repository is in memory at once.
///
/// Two implementations ship with the library:
///
/// - ``InMemoryRepositoryBlockStore`` keeps every block in a dictionary.
/// - ``FileRepositoryBlockStore`` keeps block bodies in one file on disk and
///   only a CID-to-offset index in memory.
///
/// Conform your own type to put blocks in a database. A store must return
/// exactly the bytes it was given; callers re-hash blocks they read.
public protocol RepositoryBlockStore: PublicRepositoryBlockSource {
    /// Stores `block`. Storing a CID that is already present is a no-op.
    ///
    /// - Throws: ``RepositoryBlockStoreError/blockCIDMismatch`` if the bytes
    ///   do not hash to the CID, ``RepositoryBlockStoreError/unsupportedCID``
    ///   if the CID is not a blessed DAG-CBOR CID.
    func put(_ block: PublicRepositoryBlock) async throws

    /// Whether a block with this CID is present.
    func contains(_ cid: CID) async throws -> Bool

    /// The number of distinct blocks held.
    func blockCount() async throws -> Int

    /// Every CID held, in the order the blocks were first stored.
    ///
    /// The order is what lets an imported archive be written back out byte
    /// for byte. It materializes one CID per block, so prefer
    /// ``Repository/exportCAR(to:order:)`` for large repositories.
    func storedCIDs() async throws -> [CID]

    /// Makes every stored block durable, if the store buffers writes.
    func flush() async throws
}

public extension RepositoryBlockStore {
    /// Stores several blocks.
    func put(_ blocks: [PublicRepositoryBlock]) async throws {
        for block in blocks {
            try await put(block)
        }
    }

    func flush() async throws {}
}

/// Why a block store refused an operation.
public enum RepositoryBlockStoreError: Error, Sendable, Equatable {
    /// The block's bytes do not hash to its CID.
    case blockCIDMismatch
    /// Only blessed DAG-CBOR blocks (commits, MST nodes, records) are stored.
    case unsupportedCID
    /// The store's configured byte capacity would be exceeded.
    case capacityExceeded
    /// The backing file could not be opened, read or written.
    case io(String)
    /// The backing file exists but is not a well-formed block file.
    case corruptStore
}

// MARK: - In memory

/// A block store that keeps everything in memory.
///
/// There is no size limit unless you give one. Use it for repositories that
/// comfortably fit in RAM, for tests, and as the scratch store of a commit.
///
/// ```swift
/// let store = InMemoryRepositoryBlockStore()
/// let repo = try await Repository.create(did: did, signer: keypair, store: store)
/// ```
public actor InMemoryRepositoryBlockStore: RepositoryBlockStore {
    private var storage: [CID: Data] = [:]
    private var order: [CID] = []
    private var byteCount = 0
    private let maximumBytes: Int?

    /// Creates an empty store.
    ///
    /// - Parameter maximumBytes: Refuse to hold more than this many bytes of
    ///   block bodies. `nil` (the default) means no limit.
    public init(maximumBytes: Int? = nil) {
        self.maximumBytes = maximumBytes
    }

    /// The total size of the block bodies held.
    public var storedByteCount: Int { byteCount }

    public func block(for cid: CID) async throws -> Data? {
        storage[cid]
    }

    public func put(_ block: PublicRepositoryBlock) async throws {
        if storage[block.cid] != nil { return }
        try RepositoryBlockStoreValidation.check(block)
        let (next, overflow) = byteCount.addingReportingOverflow(block.bytes.count)
        guard !overflow, maximumBytes.map({ next <= $0 }) ?? true else {
            throw RepositoryBlockStoreError.capacityExceeded
        }
        storage[block.cid] = block.bytes
        order.append(block.cid)
        byteCount = next
    }

    public func contains(_ cid: CID) async throws -> Bool {
        storage[cid] != nil
    }

    public func blockCount() async throws -> Int {
        storage.count
    }

    public func storedCIDs() async throws -> [CID] {
        order
    }
}

// MARK: - File backed

/// A block store that keeps block bodies in a file.
///
/// Memory use is the index only: one entry (CID, offset, length) per block,
/// independent of how large the blocks are. That is what makes it possible to
/// import, verify and re-export a multi-gigabyte repository without holding
/// it in RAM.
///
/// The file is a sequence of CAR-style frames, `varint(length) ‖ CID ‖ bytes`,
/// with no header. Opening an existing file rebuilds the index by scanning
/// those frames, so a store survives a restart. Writes are appended through a
/// buffer; call ``flush()`` (``Repository`` does after each import and
/// commit) before relying on the file's contents from another process.
///
/// ```swift
/// let store = try FileRepositoryBlockStore(url: scratchDirectory.appending(path: "blocks"))
/// let repo = try await Repository.open(
///     carFile: exportURL, verification: .signingKey(key), store: store
/// )
/// ```
public actor FileRepositoryBlockStore: RepositoryBlockStore {
    private struct Location {
        let offset: UInt64
        let length: Int
    }

    private static let flushThreshold = 1 << 20

    /// The backing file.
    public nonisolated let url: URL
    // Opened from a URL, so Foundation closes the descriptor when the handle
    // is deallocated.
    private let handle: FileHandle
    private var index: [CID: Location] = [:]
    private var order: [CID] = []
    /// Bytes of the file that are on disk.
    private var flushedLength: UInt64
    /// Appended frames not yet written to disk; logically at `flushedLength`.
    private var pending = Data()

    /// Opens the block file at `url`, creating it if it does not exist.
    ///
    /// - Parameters:
    ///   - url: Location of the block file.
    ///   - verifyingExistingBlocks: Re-hash every block already in the file
    ///     while rebuilding the index. Defaults to `true`; pass `false` to
    ///     reopen a large file this process wrote and trusts.
    /// - Throws: ``RepositoryBlockStoreError``.
    public init(url: URL, verifyingExistingBlocks: Bool = true) throws {
        self.url = url
        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) {
            guard manager.createFile(atPath: url.path, contents: nil) else {
                throw RepositoryBlockStoreError.io("cannot create \(url.lastPathComponent)")
            }
        }
        do {
            handle = try FileHandle(forUpdating: url)
        } catch {
            throw RepositoryBlockStoreError.io("cannot open \(url.lastPathComponent)")
        }
        let scan = try Self.scan(handle: handle, verifying: verifyingExistingBlocks)
        index = scan.index
        order = scan.order
        flushedLength = scan.length
    }

    public func block(for cid: CID) async throws -> Data? {
        guard let location = index[cid] else { return nil }
        if location.offset >= flushedLength {
            let start = Int(location.offset - flushedLength)
            guard start + location.length <= pending.count else {
                throw RepositoryBlockStoreError.corruptStore
            }
            let base = pending.startIndex
            return Data(pending[(base + start) ..< (base + start + location.length)])
        }
        do {
            try handle.seek(toOffset: location.offset)
            guard let bytes = try handle.read(upToCount: location.length),
                  bytes.count == location.length else {
                throw RepositoryBlockStoreError.corruptStore
            }
            return bytes
        } catch let error as RepositoryBlockStoreError {
            throw error
        } catch {
            throw RepositoryBlockStoreError.io("read failed")
        }
    }

    public func put(_ block: PublicRepositoryBlock) async throws {
        if index[block.cid] != nil { return }
        try RepositoryBlockStoreValidation.check(block)
        let cidBytes = block.cid.bytes
        let prefix = PublicRepositoryCAR.canonicalUnsignedVarint(
            UInt64(cidBytes.count + block.bytes.count)
        )
        let frameStart = flushedLength + UInt64(pending.count)
        pending.append(prefix)
        pending.append(cidBytes)
        pending.append(block.bytes)
        index[block.cid] = Location(
            offset: frameStart + UInt64(prefix.count + cidBytes.count),
            length: block.bytes.count
        )
        order.append(block.cid)
        if pending.count >= Self.flushThreshold {
            try writePending()
        }
    }

    public func contains(_ cid: CID) async throws -> Bool {
        index[cid] != nil
    }

    public func blockCount() async throws -> Int {
        index.count
    }

    public func storedCIDs() async throws -> [CID] {
        order
    }

    public func flush() async throws {
        try writePending()
        do {
            try handle.synchronize()
        } catch {
            throw RepositoryBlockStoreError.io("sync failed")
        }
    }

    private func writePending() throws {
        guard !pending.isEmpty else { return }
        do {
            try handle.seek(toOffset: flushedLength)
            try handle.write(contentsOf: pending)
        } catch {
            throw RepositoryBlockStoreError.io("write failed")
        }
        flushedLength += UInt64(pending.count)
        pending.removeAll(keepingCapacity: true)
    }

    private struct ScanResult {
        var index: [CID: Location] = [:]
        var order: [CID] = []
        var length: UInt64 = 0
    }

    /// Rebuilds the index from an existing block file, reading it in chunks.
    private static func scan(handle: FileHandle, verifying: Bool) throws -> ScanResult {
        var result = ScanResult()
        let total: UInt64
        do {
            total = try handle.seekToEnd()
            try handle.seek(toOffset: 0)
        } catch {
            throw RepositoryBlockStoreError.io("cannot size block file")
        }
        var position: UInt64 = 0
        var buffer = Data()
        var bufferStart: UInt64 = 0

        func ensure(_ count: Int) throws -> Bool {
            while buffer.count - Int(position - bufferStart) < count {
                let consumed = Int(position - bufferStart)
                if consumed > 0 {
                    buffer.removeFirst(consumed)
                    bufferStart = position
                }
                let chunk: Data?
                do {
                    chunk = try handle.read(upToCount: max(1 << 20, count))
                } catch {
                    throw RepositoryBlockStoreError.io("read failed")
                }
                guard let chunk, !chunk.isEmpty else { return false }
                buffer.append(chunk)
            }
            return true
        }

        func take(_ count: Int) -> Data {
            let start = buffer.startIndex + Int(position - bufferStart)
            position += UInt64(count)
            return Data(buffer[start ..< start + count])
        }

        while position < total {
            var frameLength: UInt64 = 0
            var shift: UInt64 = 0
            while true {
                guard try ensure(1), shift < 63 else {
                    throw RepositoryBlockStoreError.corruptStore
                }
                let byte = take(1)[0]
                frameLength |= UInt64(byte & 0x7f) << shift
                if byte & 0x80 == 0 { break }
                shift += 7
            }
            guard frameLength > 36, frameLength <= UInt64(Int.max),
                  position + frameLength <= total,
                  try ensure(Int(frameLength)) else {
                throw RepositoryBlockStoreError.corruptStore
            }
            let cidBytes = take(36)
            let bodyOffset = position
            let body = take(Int(frameLength) - 36)
            guard let cid = try? CID(bytes: cidBytes), cid.blessedKind == .dagCBOR else {
                throw RepositoryBlockStoreError.corruptStore
            }
            if verifying, !cid.matchesContent(body) {
                throw RepositoryBlockStoreError.corruptStore
            }
            if result.index[cid] == nil {
                result.index[cid] = Location(offset: bodyOffset, length: body.count)
                result.order.append(cid)
            }
        }
        result.length = total
        return result
    }
}

enum RepositoryBlockStoreValidation {
    static func check(_ block: PublicRepositoryBlock) throws {
        guard block.cid.blessedKind == .dagCBOR else {
            throw RepositoryBlockStoreError.unsupportedCID
        }
        guard block.cid.matchesContent(block.bytes) else {
            throw RepositoryBlockStoreError.blockCIDMismatch
        }
    }
}

// MARK: - CAR byte sources and sinks

/// Reads a CAR archive that is already in memory.
public actor DataCARByteSource: PublicRepositoryCARByteSource {
    private let data: Data
    private var offset: Int

    /// Creates a source over `data`.
    public init(_ data: Data) {
        self.data = data
        offset = data.startIndex
    }

    public func read(maximumBytes: Int) async throws -> Data? {
        guard offset < data.endIndex else { return nil }
        let end = min(data.endIndex, offset + max(1, maximumBytes))
        defer { offset = end }
        return Data(data[offset ..< end])
    }
}

/// Reads a CAR archive from a file without loading it into memory.
public actor FileCARByteSource: PublicRepositoryCARByteSource {
    private let handle: FileHandle

    /// Opens `url` for reading.
    ///
    /// - Throws: ``RepositoryBlockStoreError/io(_:)`` if the file cannot be
    ///   opened.
    public init(url: URL) throws {
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw RepositoryBlockStoreError.io("cannot open \(url.lastPathComponent)")
        }
    }

    public func read(maximumBytes: Int) async throws -> Data? {
        let chunk: Data?
        do {
            chunk = try handle.read(upToCount: max(1, maximumBytes))
        } catch {
            throw RepositoryBlockStoreError.io("read failed")
        }
        guard let chunk, !chunk.isEmpty else { return nil }
        return chunk
    }
}

/// Collects a CAR archive in memory.
public actor DataCARByteSink: PublicRepositoryCARByteSink {
    /// The bytes written so far.
    public private(set) var data = Data()

    /// Creates an empty sink.
    public init() {}

    public func write(_ bytes: Data) async throws {
        data.append(bytes)
    }
}

/// Writes a CAR archive to a file as it is produced.
public actor FileCARByteSink: PublicRepositoryCARByteSink {
    private let handle: FileHandle

    /// Creates (or truncates) `url` and opens it for writing.
    ///
    /// - Throws: ``RepositoryBlockStoreError/io(_:)`` if the file cannot be
    ///   created.
    public init(url: URL) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw RepositoryBlockStoreError.io("cannot create \(url.lastPathComponent)")
        }
        do {
            handle = try FileHandle(forWritingTo: url)
        } catch {
            throw RepositoryBlockStoreError.io("cannot open \(url.lastPathComponent)")
        }
    }

    public func write(_ bytes: Data) async throws {
        do {
            try handle.write(contentsOf: bytes)
        } catch {
            throw RepositoryBlockStoreError.io("write failed")
        }
    }

    /// Flushes file data to disk.
    public func synchronize() async throws {
        do {
            try handle.synchronize()
        } catch {
            throw RepositoryBlockStoreError.io("sync failed")
        }
    }
}

/// Feeds parsed CAR frames straight into a block store, so an import never
/// holds more than one block outside the store.
actor RepositoryStoreFrameSink: PublicRepositoryCARFrameSink {
    private let store: any RepositoryBlockStore
    private(set) var rootCID: CID?

    init(store: any RepositoryBlockStore) {
        self.store = store
    }

    func receiveHeader(rootCID: CID, receivedByteCount _: Int) async throws {
        self.rootCID = rootCID
    }

    func receiveBlock(
        _ block: PublicRepositoryBlock,
        receivedByteCount _: Int,
        frameCount _: Int
    ) async throws {
        // The parser has already hashed the block; a second identical frame
        // is a no-op in the store, which is the duplicate tolerance the
        // repository specification asks for.
        try await store.put(block)
    }

    func flush() async throws {
        try await store.flush()
    }
}
