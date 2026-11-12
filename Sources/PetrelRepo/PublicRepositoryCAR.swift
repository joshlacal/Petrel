// CAR framing and full-repository traversal in this file follow
// bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/{car,sync/provider}.ts, used under the repository's
// MIT OR Apache-2.0 notice policy recorded in THIRD_PARTY_NOTICES.md.
// Strict canonical parsing and hostile-input limits are additions.

import Foundation
import Petrel

public protocol PublicRepositoryCARByteSink: Sendable {
    func write(_ bytes: Data) async throws
}

public protocol PublicRepositoryCARBlockStream: Sendable {
    func nextBlock() async throws -> PublicRepositoryBlock?
}

public protocol PublicRepositoryCARByteSource: Sendable {
    /// Returns at most `maximumBytes`, or nil only at end of input.
    func read(maximumBytes: Int) async throws -> Data?
}

/// Storage-neutral receiver for the strict incremental CAR parser. A sink is
/// called with at most one complete block body at a time and may durably
/// persist it before the parser requests the next frame.
public protocol PublicRepositoryCARFrameSink: Sendable {
    func receiveHeader(rootCID: CID, receivedByteCount: Int) async throws
    func receiveBlock(
        _ block: PublicRepositoryBlock,
        receivedByteCount: Int,
        frameCount: Int
    ) async throws
    func flush() async throws
}

extension PublicRepositoryCARFrameSink {
    public func flush() async throws {}
}

/// What the streaming CAR parser saw.
public struct PublicRepositoryCARParseResult: Sendable, Equatable {
    /// The first root: the commit.
    public let rootCID: CID
    /// Bytes consumed from the source.
    public let receivedByteCount: Int
    /// Block frames delivered to the sink.
    public let frameCount: Int
    /// Roots after the first. The repository specification allows them and
    /// leaves their meaning undefined; they are reported, never interpreted.
    public let additionalRootCIDs: [CID]
    /// Block frames skipped because their CID is not a blessed DAG-CBOR CID
    /// (for example a blob included in the archive). Always 0 under
    /// ``RepositoryReadPolicy/strict``, which refuses such frames instead.
    public let ignoredFrameCount: Int
}

public enum PublicRepositoryCARError: Error, Sendable, Equatable {
    case invalidChunkSize
    case invalidRootCID
    case invalidBlockCID
    case blockCIDMismatch
    case blockBodyLimitExceeded
    case byteLimitExceeded
    case blockLimitExceeded
    case malformedVarint
    case nonCanonicalVarint
    case malformedHeader
    case unsupportedVersion
    case invalidRootCount
    case malformedFrame
    case duplicateBlockConflict
    case missingCommit
    case commit(PublicRepositoryCommitError)
    case repository(RepositoryMSTValidationError)
}

public struct PublicRepositoryCARWriteResult: Sendable, Equatable {
    public let byteCount: Int
    public let blockCount: Int
}

public struct VerifiedPublicRepositoryBlockProjection: Sendable, PublicRepositoryBlockSource {
    private let storage: [CID: Data]

    fileprivate init(storage: [CID: Data]) {
        self.storage = storage
    }

    public var cids: Set<CID> { Set(storage.keys) }
    public var count: Int { storage.count }

    public func block(for cid: CID) async throws -> Data? {
        storage[cid]
    }
}

public struct VerifiedPublicRepositoryCAR: Sendable {
    public let state: PublicRepositoryState
    public let signedCommit: VerifiedPublicRepositorySignedCommit
    public let repository: ValidatedPublicRepositoryMST
    public let reachableBlocks: VerifiedPublicRepositoryBlockProjection

    fileprivate init(
        state: PublicRepositoryState,
        signedCommit: VerifiedPublicRepositorySignedCommit,
        repository: ValidatedPublicRepositoryMST,
        reachableBlocks: VerifiedPublicRepositoryBlockProjection
    ) {
        self.state = state
        self.signedCommit = signedCommit
        self.repository = repository
        self.reachableBlocks = reachableBlocks
    }
}

public enum PublicRepositoryCAR {
    public static let defaultMaximumChunkBytes = 64 * 1_024

    public static func canonicalUnsignedVarint(_ value: UInt64) -> Data {
        var remaining = value
        var result = Data()
        repeat {
            var byte = UInt8(remaining & 0x7f)
            remaining >>= 7
            if remaining != 0 {
                byte |= 0x80
            }
            result.append(byte)
        } while remaining != 0
        return result
    }

    /// Writes a CAR archive with one root, pulling blocks from `blocks`.
    ///
    /// Every block is checked against its CID before it is written.
    public static func write(
        rootCID: CID,
        blocks: any PublicRepositoryCARBlockStream,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits = .standard,
        maximumChunkBytes: Int = defaultMaximumChunkBytes
    ) async throws -> PublicRepositoryCARWriteResult {
        let writer = try CARFrameWriter(
            sink: sink, limits: limits, maximumChunkBytes: maximumChunkBytes
        )
        try await writer.writeHeader(rootCID: rootCID)
        while let block = try await blocks.nextBlock() {
            try await writer.writeBlock(block)
        }
        return writer.result
    }

    /// Emits the frozen full-repository ordering from the pinned TypeScript
    /// implementation: signed commit, MST nodes breadth-first, then record
    /// blocks in first-seen traversal order.
    public static func export(
        signedCommit: PreparedPublicRepositorySignedCommit,
        blocks: any PublicRepositoryBlockSource,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits = .standard,
        maximumChunkBytes: Int = defaultMaximumChunkBytes,
        policy: RepositoryReadPolicy = .strict
    ) async throws -> PublicRepositoryCARWriteResult {
        try await export(
            commitCID: signedCommit.commitCID,
            signedCommitBytes: signedCommit.signedCommitBytes,
            dataCID: signedCommit.descriptor.dataCID,
            blocks: blocks,
            to: sink,
            limits: limits,
            maximumChunkBytes: maximumChunkBytes,
            policy: policy
        )
    }

    /// Re-exports a commit that crossed the strict verification boundary,
    /// allowing persisted/imported repositories to stream after restart
    /// without forging a locally prepared value.
    public static func export(
        signedCommit: VerifiedPublicRepositorySignedCommit,
        blocks: any PublicRepositoryBlockSource,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits = .standard,
        maximumChunkBytes: Int = defaultMaximumChunkBytes,
        policy: RepositoryReadPolicy = .strict
    ) async throws -> PublicRepositoryCARWriteResult {
        try await export(
            commitCID: signedCommit.commitCID,
            signedCommitBytes: signedCommit.signedCommitBytes,
            dataCID: signedCommit.descriptor.dataCID,
            blocks: blocks,
            to: sink,
            limits: limits,
            maximumChunkBytes: maximumChunkBytes,
            policy: policy
        )
    }

    /// Re-exports durable repository truth after its canonical commit/state
    /// linkage and complete MST projection have been checked by storage.
    /// This makes no signature-authenticity claim; it preserves the exact
    /// already-signed commit bytes.
    public static func export(
        signedCommit: StructurallyValidatedPublicRepositorySignedCommit,
        blocks: any PublicRepositoryBlockSource,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits = .standard,
        maximumChunkBytes: Int = defaultMaximumChunkBytes,
        policy: RepositoryReadPolicy = .strict
    ) async throws -> PublicRepositoryCARWriteResult {
        try await export(
            commitCID: signedCommit.commitCID,
            signedCommitBytes: signedCommit.signedCommitBytes,
            dataCID: signedCommit.descriptor.dataCID,
            blocks: blocks,
            to: sink,
            limits: limits,
            maximumChunkBytes: maximumChunkBytes,
            policy: policy
        )
    }

    private static func export(
        commitCID: CID,
        signedCommitBytes: Data,
        dataCID: CID,
        blocks: any PublicRepositoryBlockSource,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits,
        maximumChunkBytes: Int,
        policy: RepositoryReadPolicy
    ) async throws -> PublicRepositoryCARWriteResult {
        do {
            try PublicRepositoryCID.validate(
                commitCID,
                blockBytes: signedCommitBytes
            )
        } catch {
            throw PublicRepositoryCARError.blockCIDMismatch
        }

        let validated: ValidatedPublicRepositoryMST
        do {
            validated = try await RepositoryMSTValidation.validate(
                rootCID: dataCID,
                blocks: blocks,
                limits: limits,
                policy: policy
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryMSTValidationError {
            throw PublicRepositoryCARError.repository(error)
        } catch {
            throw PublicRepositoryCARError.repository(.invalidNodeSchema)
        }

        let orderedCIDs = validated.orderedBlockCIDs

        return try await write(
            rootCID: commitCID,
            blocks: RepositoryExportBlockStream(
                commit: .init(
                    cid: commitCID,
                    bytes: signedCommitBytes
                ),
                orderedCIDs: orderedCIDs,
                source: blocks
            ),
            to: sink,
            limits: limits,
            maximumChunkBytes: maximumChunkBytes
        )
    }

    /// Reads a whole repository CAR into memory, verifies the commit and
    /// validates the tree.
    ///
    /// Everything is held in memory at once. For large repositories, or to
    /// keep the blocks on disk, use ``Repository``.
    public static func importRepository(
        from source: any PublicRepositoryCARByteSource,
        verifier: any PublicRepositoryCommitVerifier,
        limits: PublicRepositoryLimits = .standard,
        policy: RepositoryReadPolicy = .strict
    ) async throws -> VerifiedPublicRepositoryCAR {
        let collectingSink = InMemoryImportFrameSink()
        let parsed = try await parseIncrementally(
            from: source, to: collectingSink, limits: limits, policy: policy
        )
        let root = parsed.rootCID
        let allBlocks = await collectingSink.blocks

        guard let commitBytes = allBlocks[root] else {
            throw PublicRepositoryCARError.missingCommit
        }
        let verifiedCommit: VerifiedPublicRepositorySignedCommit
        do {
            verifiedCommit = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: commitBytes,
                expectedCommitCID: root,
                verifier: verifier
            )
        } catch let error as PublicRepositoryCommitError {
            throw PublicRepositoryCARError.commit(error)
        } catch {
            throw PublicRepositoryCARError.commit(.invalidSchema)
        }

        let importedSource = ImportedBlockSource(storage: allBlocks)
        let repository: ValidatedPublicRepositoryMST
        do {
            repository = try await RepositoryMSTValidation.validate(
                rootCID: verifiedCommit.descriptor.dataCID,
                blocks: importedSource,
                limits: limits,
                policy: policy
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryMSTValidationError {
            throw PublicRepositoryCARError.repository(error)
        } catch {
            throw PublicRepositoryCARError.repository(.invalidNodeSchema)
        }

        var reachable: [CID: Data] = [root: commitBytes]
        for cid in repository.reachableMSTBlocks.keys {
            guard let bytes = allBlocks[cid] else {
                throw PublicRepositoryCARError.repository(.missingBlock)
            }
            reachable[cid] = bytes
        }
        for cid in repository.reachableRecordCIDs {
            guard let bytes = allBlocks[cid] else {
                throw PublicRepositoryCARError.repository(.missingRecordBlock)
            }
            reachable[cid] = bytes
        }
        let state: PublicRepositoryState
        do {
            state = try PublicRepositoryState(
                did: verifiedCommit.descriptor.did,
                revision: verifiedCommit.descriptor.revision.value,
                commitCID: root,
                dataCID: verifiedCommit.descriptor.dataCID
            )
        } catch {
            throw PublicRepositoryCARError.commit(.invalidSchema)
        }
        return VerifiedPublicRepositoryCAR(
            state: state,
            signedCommit: verifiedCommit,
            repository: repository,
            reachableBlocks: .init(storage: reachable)
        )
    }

    /// Strictly parses CARv1 framing without retaining the CAR. Duplicate
    /// policy is deliberately owned by the sink because durable staging must
    /// compare against prior frames, including frames received before restart.
    ///
    /// Framing is always strict: canonical varints, a canonical header, and
    /// every delivered block re-hashed against its CID. `policy` decides the
    /// two things the repository specification asks readers to tolerate:
    /// roots after the first, and blocks that are not repository blocks.
    public static func parseIncrementally(
        from source: any PublicRepositoryCARByteSource,
        to sink: any PublicRepositoryCARFrameSink,
        limits: PublicRepositoryLimits = .standard,
        policy: RepositoryReadPolicy = .strict
    ) async throws -> PublicRepositoryCARParseResult {
        let reader = StreamingCARInput(source: source, maximumBytes: limits.maximumCARBytes)
        let headerLength = try await reader.readCanonicalVarint()
        guard headerLength <= UInt64(StreamingCARInput.maximumHeaderBytes) else {
            throw PublicRepositoryCARError.malformedHeader
        }
        let header = try await reader.readExactly(Int(headerLength))
        let roots = try parseHeader(header, policy: policy)
        let root = roots.commit
        try await sink.receiveHeader(
            rootCID: root,
            receivedByteCount: reader.receivedByteCount
        )

        var blockCount = 0
        var ignoredCount = 0
        // A foreign block's CID may be longer than the 36 bytes of a blessed
        // one, so allow for that when it is going to be skipped anyway.
        let maximumFrameBytes = UInt64(limits.maximumRecordBlockBytes)
            + (policy.rejectsForeignCARBlocks ? 36 : 1_100)
        while let frameLength = try await reader.readCanonicalVarintOrEOF() {
            try Task.checkCancellation()
            guard blockCount + ignoredCount < limits.maximumCARBlocks else {
                throw PublicRepositoryCARError.blockLimitExceeded
            }
            guard frameLength >= 2, frameLength <= maximumFrameBytes else {
                throw PublicRepositoryCARError.blockBodyLimitExceeded
            }
            let frame = try await reader.readExactly(Int(frameLength))
            let isRepositoryBlock = frame.count > 36
                && frame.prefix(4).elementsEqual(blessedDAGCBORCIDPrefix)
            guard isRepositoryBlock else {
                // Anything else is not part of a repository: a blob, or a
                // block from another system. The specification says to
                // ignore it. It still has to be a well-formed frame.
                guard !policy.rejectsForeignCARBlocks else {
                    throw frame.count > 36
                        ? PublicRepositoryCARError.invalidBlockCID
                        : PublicRepositoryCARError.blockBodyLimitExceeded
                }
                guard RepositoryRecordBlockValidator.cidPrefixLength(in: frame) != nil else {
                    throw PublicRepositoryCARError.invalidBlockCID
                }
                ignoredCount += 1
                continue
            }
            let cidBytes = Data(frame.prefix(36))
            let cid: CID
            do {
                cid = try CID(bytes: cidBytes)
                try PublicRepositoryCID.validate(cid)
            } catch {
                throw PublicRepositoryCARError.invalidBlockCID
            }
            guard cid.bytes == cidBytes else {
                throw PublicRepositoryCARError.invalidBlockCID
            }
            let body = Data(frame.dropFirst(36))
            guard body.count <= limits.maximumRecordBlockBytes else {
                throw PublicRepositoryCARError.blockBodyLimitExceeded
            }
            do {
                try PublicRepositoryCID.validate(cid, blockBytes: body)
            } catch {
                throw PublicRepositoryCARError.blockCIDMismatch
            }
            blockCount += 1
            try await sink.receiveBlock(
                .init(cid: cid, bytes: body),
                receivedByteCount: reader.receivedByteCount,
                frameCount: blockCount
            )
        }
        try await sink.flush()
        return .init(
            rootCID: root,
            receivedByteCount: reader.receivedByteCount,
            frameCount: blockCount,
            additionalRootCIDs: roots.additional,
            ignoredFrameCount: ignoredCount
        )
    }

    /// Reads a CAR archive into a block store, one block at a time.
    ///
    /// Every block is re-hashed against its CID before it is stored. Nothing
    /// about the repository is verified; use ``Repository`` for that. This is
    /// the entry point for archives that hold only part of a tree, such as
    /// the `blocks` of a `#commit` firehose event.
    ///
    /// - Parameters:
    ///   - source: The archive bytes.
    ///   - store: Receives the blocks.
    ///   - limits: Bounds on the archive.
    ///   - policy: Whether extra roots and non-repository blocks are
    ///     tolerated (the default) or refused.
    /// - Returns: The root and frame counts.
    @discardableResult
    public static func load(
        from source: any PublicRepositoryCARByteSource,
        into store: any RepositoryBlockStore,
        limits: PublicRepositoryLimits = .networkScale,
        policy: RepositoryReadPolicy = .dataModel
    ) async throws -> PublicRepositoryCARParseResult {
        try await parseIncrementally(
            from: source,
            to: RepositoryStoreFrameSink(store: store),
            limits: limits,
            policy: policy
        )
    }

    /// Encodes a small set of blocks as one CAR archive in memory: a commit
    /// diff, or a record proof.
    ///
    /// - Parameters:
    ///   - rootCID: The single root (the commit).
    ///   - blocks: The blocks, written in the order given.
    ///   - limits: Bounds on the archive.
    public static func encode(
        rootCID: CID,
        blocks: [PublicRepositoryBlock],
        limits: PublicRepositoryLimits = .standard
    ) async throws -> Data {
        let sink = DataCARByteSink()
        _ = try await write(
            rootCID: rootCID,
            blocks: ArrayCARBlockStream(blocks),
            to: sink,
            limits: limits
        )
        return await sink.data
    }

    /// Bytes every blessed DAG-CBOR CID begins with: CIDv1, `dag-cbor`,
    /// SHA-256, 32-byte digest. The rule itself is `CID.blessedKind`; this is
    /// only the fast test for "is this frame a repository block".
    private static let blessedDAGCBORCIDPrefix: [UInt8] = [0x01, 0x71, 0x12, 0x20]

    private static func parseHeader(
        _ header: Data,
        policy: RepositoryReadPolicy
    ) throws -> (commit: CID, additional: [CID]) {
        // One blessed root is by far the common case and has a single exact
        // 58-byte encoding.
        if header.count == 58 {
            return (try parseCanonicalHeader(header), [])
        }
        var parser = CARHeaderParser(Array(header))
        let rootPayloads = try parser.parse()
        guard let first = rootPayloads.first else {
            throw PublicRepositoryCARError.invalidRootCount
        }
        guard rootPayloads.count == 1 || !policy.requiresSingleCARRoot else {
            throw PublicRepositoryCARError.invalidRootCount
        }
        let commit: CID
        do {
            commit = try CID(bytes: first)
            try PublicRepositoryCID.validate(commit)
        } catch {
            throw PublicRepositoryCARError.invalidRootCID
        }
        var additional: [CID] = []
        for payload in rootPayloads.dropFirst() {
            if let cid = try? CID(bytes: payload) {
                additional.append(cid)
            } else if !RepositoryRecordBlockValidator.isStructurallyCID(payload) {
                throw PublicRepositoryCARError.invalidRootCID
            }
        }
        return (commit, additional)
    }

    private static func parseCanonicalHeader(_ header: Data) throws -> CID {
        // The blessed CID tuple is fixed-width, making the canonical one-root
        // header a single exact 58-byte schema.
        guard header.count == 58 else {
            throw PublicRepositoryCARError.invalidRootCount
        }
        guard header[0] == 0xa2,
              header[1] == 0x65,
              header[2 ..< 7] == Data("roots".utf8),
              header[7] == 0x81,
              header[8] == 0xd8,
              header[9] == 0x2a,
              header[10] == 0x58,
              header[11] == 0x25,
              header[12] == 0x00,
              header[49] == 0x67,
              header[50 ..< 57] == Data("version".utf8) else {
            throw PublicRepositoryCARError.malformedHeader
        }
        guard header[57] == 0x01 else {
            throw PublicRepositoryCARError.unsupportedVersion
        }
        let cid: CID
        do {
            cid = try CID(bytes: Data(header[13 ..< 49]))
            try PublicRepositoryCID.validate(cid)
        } catch {
            throw PublicRepositoryCARError.invalidRootCID
        }
        let expected: Data
        do {
            expected = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
                (key: "roots", value: [ATProtoLink(cid: cid)]),
                (key: "version", value: 1),
            ]))
        } catch {
            throw PublicRepositoryCARError.malformedHeader
        }
        guard expected == header else {
            throw PublicRepositoryCARError.malformedHeader
        }
        return cid
    }
}

/// Push-style CAR v1 writer: a header, then block frames, each checked
/// against its CID and against the archive limits as it is written.
final class CARFrameWriter {
    private let sink: any PublicRepositoryCARByteSink
    private let limits: PublicRepositoryLimits
    private let maximumChunkBytes: Int
    private var total = 0
    private var count = 0

    init(
        sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits,
        maximumChunkBytes: Int = PublicRepositoryCAR.defaultMaximumChunkBytes
    ) throws {
        guard maximumChunkBytes > 0 else {
            throw PublicRepositoryCARError.invalidChunkSize
        }
        self.sink = sink
        self.limits = limits
        self.maximumChunkBytes = maximumChunkBytes
    }

    var result: PublicRepositoryCARWriteResult {
        PublicRepositoryCARWriteResult(byteCount: total, blockCount: count)
    }

    func writeHeader(rootCID: CID) async throws {
        do {
            try PublicRepositoryCID.validate(rootCID)
        } catch {
            throw PublicRepositoryCARError.invalidRootCID
        }
        let header: Data
        do {
            header = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
                (key: "roots", value: [ATProtoLink(cid: rootCID)]),
                (key: "version", value: 1),
            ]))
        } catch {
            throw PublicRepositoryCARError.malformedHeader
        }
        try await writeSegment(PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(header.count)))
        try await writeSegment(header)
    }

    func writeBlock(_ block: PublicRepositoryBlock) async throws {
        try Task.checkCancellation()
        guard count < limits.maximumCARBlocks else {
            throw PublicRepositoryCARError.blockLimitExceeded
        }
        do {
            try PublicRepositoryCID.validate(block.cid)
        } catch {
            throw PublicRepositoryCARError.invalidBlockCID
        }
        do {
            try PublicRepositoryCID.validate(block.cid, blockBytes: block.bytes)
        } catch {
            throw PublicRepositoryCARError.blockCIDMismatch
        }
        guard block.bytes.count <= limits.maximumRecordBlockBytes else {
            throw PublicRepositoryCARError.blockBodyLimitExceeded
        }
        let cidBytes = block.cid.bytes
        let (frameLength, overflow) = cidBytes.count.addingReportingOverflow(block.bytes.count)
        guard !overflow else {
            throw PublicRepositoryCARError.byteLimitExceeded
        }
        try await writeSegment(PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(frameLength)))
        try await writeSegment(cidBytes)
        try await writeSegment(block.bytes)
        count += 1
    }

    private func writeSegment(_ bytes: Data) async throws {
        let (nextTotal, overflow) = total.addingReportingOverflow(bytes.count)
        guard !overflow, nextTotal <= limits.maximumCARBytes else {
            throw PublicRepositoryCARError.byteLimitExceeded
        }
        var offset = 0
        while offset < bytes.count {
            try Task.checkCancellation()
            let end = min(bytes.count, offset + maximumChunkBytes)
            try await sink.write(Data(bytes[(bytes.startIndex + offset) ..< (bytes.startIndex + end)]))
            offset = end
        }
        total = nextTotal
    }
}

private actor RepositoryExportBlockStream: PublicRepositoryCARBlockStream {
    private var commit: PublicRepositoryBlock?
    private let orderedCIDs: [CID]
    private let source: any PublicRepositoryBlockSource
    private var index = 0

    init(
        commit: PublicRepositoryBlock,
        orderedCIDs: [CID],
        source: any PublicRepositoryBlockSource
    ) {
        self.commit = commit
        self.orderedCIDs = orderedCIDs
        self.source = source
    }

    func nextBlock() async throws -> PublicRepositoryBlock? {
        if let commit {
            self.commit = nil
            return commit
        }
        guard index < orderedCIDs.count else { return nil }
        let cid = orderedCIDs[index]
        defer { index += 1 }
        guard let bytes = try await source.block(for: cid) else {
            throw PublicRepositoryCARError.repository(.missingBlock)
        }
        return PublicRepositoryBlock(cid: cid, bytes: bytes)
    }
}

/// Yields a fixed list of blocks.
private actor ArrayCARBlockStream: PublicRepositoryCARBlockStream {
    private let blocks: [PublicRepositoryBlock]
    private var index = 0

    init(_ blocks: [PublicRepositoryBlock]) {
        self.blocks = blocks
    }

    func nextBlock() async throws -> PublicRepositoryBlock? {
        guard index < blocks.count else { return nil }
        defer { index += 1 }
        return blocks[index]
    }
}

/// Strict parser for a CARv1 header with any number of roots:
/// `{"roots": [link, ...], "version": 1}` in canonical DAG-CBOR.
private struct CARHeaderParser {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    /// Returns the binary CID of each root, in order.
    mutating func parse() throws -> [Data] {
        guard try readLength(major: 5) == 2, try readText() == "roots" else {
            throw PublicRepositoryCARError.malformedHeader
        }
        let count = try readLength(major: 4)
        // Each root occupies at least four bytes, which bounds the count by
        // the header size before anything is allocated.
        guard count <= (bytes.count - offset) / 4 else {
            throw PublicRepositoryCARError.malformedHeader
        }
        var roots: [Data] = []
        roots.reserveCapacity(count)
        for _ in 0 ..< count {
            guard try readLength(major: 6) == 42 else {
                throw PublicRepositoryCARError.malformedHeader
            }
            let length = try readLength(major: 2)
            guard length > 1, length <= bytes.count - offset, bytes[offset] == 0 else {
                throw PublicRepositoryCARError.invalidRootCID
            }
            roots.append(Data(bytes[(offset + 1) ..< (offset + length)]))
            offset += length
        }
        guard try readText() == "version" else {
            throw PublicRepositoryCARError.malformedHeader
        }
        guard try readLength(major: 0) == 1 else {
            throw PublicRepositoryCARError.unsupportedVersion
        }
        guard offset == bytes.count else {
            throw PublicRepositoryCARError.malformedHeader
        }
        return roots
    }

    private mutating func readText() throws -> String {
        let length = try readLength(major: 3)
        guard length <= bytes.count - offset,
              let text = String(bytes: bytes[offset ..< offset + length], encoding: .utf8) else {
            throw PublicRepositoryCARError.malformedHeader
        }
        offset += length
        return text
    }

    /// Reads a canonical (shortest-form) CBOR argument of the given major
    /// type. A header is at most 1,024 bytes, so two-byte arguments suffice.
    private mutating func readLength(major: UInt8) throws -> Int {
        guard offset < bytes.count, bytes[offset] >> 5 == major else {
            throw PublicRepositoryCARError.malformedHeader
        }
        let info = bytes[offset] & 0x1f
        offset += 1
        switch info {
        case 0 ... 23:
            return Int(info)
        case 24:
            guard offset < bytes.count, bytes[offset] >= 24 else {
                throw PublicRepositoryCARError.malformedHeader
            }
            defer { offset += 1 }
            return Int(bytes[offset])
        case 25:
            guard bytes.count - offset >= 2 else {
                throw PublicRepositoryCARError.malformedHeader
            }
            let value = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
            guard value > 255 else {
                throw PublicRepositoryCARError.malformedHeader
            }
            offset += 2
            return value
        default:
            throw PublicRepositoryCARError.malformedHeader
        }
    }
}

private struct ImportedBlockSource: PublicRepositoryBlockSource {
    let storage: [CID: Data]

    func block(for cid: CID) async throws -> Data? {
        storage[cid]
    }
}

private actor InMemoryImportFrameSink: PublicRepositoryCARFrameSink {
    private(set) var blocks: [CID: Data] = [:]
    private var rootCID: CID?

    func receiveHeader(rootCID: CID, receivedByteCount _: Int) async throws {
        if let existing = self.rootCID, existing != rootCID {
            throw PublicRepositoryCARError.malformedHeader
        }
        self.rootCID = rootCID
    }

    func receiveBlock(
        _ block: PublicRepositoryBlock,
        receivedByteCount _: Int,
        frameCount _: Int
    ) async throws {
        if let existing = blocks[block.cid] {
            guard existing == block.bytes else {
                throw PublicRepositoryCARError.duplicateBlockConflict
            }
        } else {
            blocks[block.cid] = block.bytes
        }
    }
}

private final class StreamingCARInput {
    static let maximumHeaderBytes = 1_024
    static let readChunkBytes = 64 * 1_024

    private let source: any PublicRepositoryCARByteSource
    private let maximumBytes: Int
    private var buffer = Data()
    private var offset = 0
    private var receivedBytes = 0
    private var reachedEnd = false

    init(source: any PublicRepositoryCARByteSource, maximumBytes: Int) {
        self.source = source
        self.maximumBytes = maximumBytes
    }

    var receivedByteCount: Int { receivedBytes }

    func readCanonicalVarint() async throws -> UInt64 {
        guard let value = try await readCanonicalVarintOrEOF() else {
            throw PublicRepositoryCARError.malformedVarint
        }
        return value
    }

    func readCanonicalVarintOrEOF() async throws -> UInt64? {
        guard let first = try await readByteOrEOF() else { return nil }
        var encoded = Data([first])
        var value = UInt64(first & 0x7f)
        var shift: UInt64 = 7
        var byte = first
        while byte & 0x80 != 0 {
            guard encoded.count < 10, shift < 64 else {
                throw PublicRepositoryCARError.malformedVarint
            }
            guard let next = try await readByteOrEOF() else {
                throw PublicRepositoryCARError.malformedVarint
            }
            byte = next
            encoded.append(byte)
            let portion = UInt64(byte & 0x7f)
            guard shift < 63 || portion <= 1 else {
                throw PublicRepositoryCARError.malformedVarint
            }
            value |= portion << shift
            shift += 7
        }
        guard PublicRepositoryCAR.canonicalUnsignedVarint(value) == encoded else {
            throw PublicRepositoryCARError.nonCanonicalVarint
        }
        return value
    }

    func readExactly(_ count: Int) async throws -> Data {
        guard count >= 0 else {
            throw PublicRepositoryCARError.malformedFrame
        }
        while availableBytes < count {
            guard try await fill(maximumBytes: min(Self.readChunkBytes, count - availableBytes)) else {
                throw PublicRepositoryCARError.malformedFrame
            }
        }
        let start = buffer.startIndex + offset
        let result = Data(buffer[start ..< start + count])
        offset += count
        compactIfNeeded()
        return result
    }

    private var availableBytes: Int { buffer.count - offset }

    private func readByteOrEOF() async throws -> UInt8? {
        while availableBytes == 0 {
            guard try await fill(maximumBytes: 1) else { return nil }
        }
        let byte = buffer[buffer.startIndex + offset]
        offset += 1
        compactIfNeeded()
        return byte
    }

    private func fill(maximumBytes requested: Int) async throws -> Bool {
        guard !reachedEnd else { return false }
        let remaining = maximumBytes - receivedBytes
        if remaining == 0 {
            guard let overflow = try await source.read(maximumBytes: 1) else {
                reachedEnd = true
                return false
            }
            guard !overflow.isEmpty, overflow.count <= 1 else {
                throw PublicRepositoryCARError.malformedFrame
            }
            throw PublicRepositoryCARError.byteLimitExceeded
        }
        let requested = max(1, min(requested, remaining))
        guard let chunk = try await source.read(maximumBytes: requested) else {
            reachedEnd = true
            return false
        }
        guard !chunk.isEmpty, chunk.count <= requested else {
            throw PublicRepositoryCARError.malformedFrame
        }
        let (newTotal, overflow) = receivedBytes.addingReportingOverflow(chunk.count)
        guard !overflow, newTotal <= maximumBytes else {
            throw PublicRepositoryCARError.byteLimitExceeded
        }
        if offset == buffer.count {
            buffer = chunk
            offset = 0
        } else {
            buffer.append(chunk)
        }
        receivedBytes = newTotal
        return true
    }

    private func compactIfNeeded() {
        if offset == buffer.count {
            buffer.removeAll(keepingCapacity: true)
            offset = 0
        } else if offset >= Self.readChunkBytes {
            buffer = Data(buffer[(buffer.startIndex + offset)...])
            offset = 0
        }
    }
}
