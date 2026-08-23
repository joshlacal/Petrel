// CAR framing and full-repository traversal in this file follow
// bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/{car,sync/provider}.ts, used under the repository's
// MIT OR Apache-2.0 notice policy recorded in THIRD_PARTY_NOTICES.md.
// Strict canonical parsing and hostile-input limits are Swan-specific.

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

public struct PublicRepositoryCARParseResult: Sendable, Equatable {
    public let rootCID: CID
    public let receivedByteCount: Int
    public let frameCount: Int
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

    public static func write(
        rootCID: CID,
        blocks: any PublicRepositoryCARBlockStream,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits = .standard,
        maximumChunkBytes: Int = defaultMaximumChunkBytes
    ) async throws -> PublicRepositoryCARWriteResult {
        guard maximumChunkBytes > 0 else {
            throw PublicRepositoryCARError.invalidChunkSize
        }
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

        var total = 0
        var count = 0
        try await writeSegment(
            canonicalUnsignedVarint(UInt64(header.count)),
            to: sink,
            total: &total,
            maximumTotal: limits.maximumCARBytes,
            maximumChunkBytes: maximumChunkBytes
        )
        try await writeSegment(
            header,
            to: sink,
            total: &total,
            maximumTotal: limits.maximumCARBytes,
            maximumChunkBytes: maximumChunkBytes
        )

        while let block = try await blocks.nextBlock() {
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
            let (frameLength, overflow) = block.cid.bytes.count.addingReportingOverflow(block.bytes.count)
            guard !overflow else {
                throw PublicRepositoryCARError.byteLimitExceeded
            }
            try await writeSegment(
                canonicalUnsignedVarint(UInt64(frameLength)),
                to: sink,
                total: &total,
                maximumTotal: limits.maximumCARBytes,
                maximumChunkBytes: maximumChunkBytes
            )
            try await writeSegment(
                block.cid.bytes,
                to: sink,
                total: &total,
                maximumTotal: limits.maximumCARBytes,
                maximumChunkBytes: maximumChunkBytes
            )
            try await writeSegment(
                block.bytes,
                to: sink,
                total: &total,
                maximumTotal: limits.maximumCARBytes,
                maximumChunkBytes: maximumChunkBytes
            )
            count += 1
        }
        return PublicRepositoryCARWriteResult(byteCount: total, blockCount: count)
    }

    /// Emits the frozen full-repository ordering from the pinned TypeScript
    /// implementation: signed commit, MST nodes breadth-first, then record
    /// blocks in first-seen traversal order.
    public static func export(
        signedCommit: PreparedPublicRepositorySignedCommit,
        blocks: any PublicRepositoryBlockSource,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits = .standard,
        maximumChunkBytes: Int = defaultMaximumChunkBytes
    ) async throws -> PublicRepositoryCARWriteResult {
        try await export(
            commitCID: signedCommit.commitCID,
            signedCommitBytes: signedCommit.signedCommitBytes,
            dataCID: signedCommit.descriptor.dataCID,
            blocks: blocks,
            to: sink,
            limits: limits,
            maximumChunkBytes: maximumChunkBytes
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
        maximumChunkBytes: Int = defaultMaximumChunkBytes
    ) async throws -> PublicRepositoryCARWriteResult {
        try await export(
            commitCID: signedCommit.commitCID,
            signedCommitBytes: signedCommit.signedCommitBytes,
            dataCID: signedCommit.descriptor.dataCID,
            blocks: blocks,
            to: sink,
            limits: limits,
            maximumChunkBytes: maximumChunkBytes
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
        maximumChunkBytes: Int = defaultMaximumChunkBytes
    ) async throws -> PublicRepositoryCARWriteResult {
        try await export(
            commitCID: signedCommit.commitCID,
            signedCommitBytes: signedCommit.signedCommitBytes,
            dataCID: signedCommit.descriptor.dataCID,
            blocks: blocks,
            to: sink,
            limits: limits,
            maximumChunkBytes: maximumChunkBytes
        )
    }

    private static func export(
        commitCID: CID,
        signedCommitBytes: Data,
        dataCID: CID,
        blocks: any PublicRepositoryBlockSource,
        to sink: any PublicRepositoryCARByteSink,
        limits: PublicRepositoryLimits,
        maximumChunkBytes: Int
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
                limits: limits
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

    public static func importRepository(
        from source: any PublicRepositoryCARByteSource,
        verifier: any PublicRepositoryCommitVerifier,
        limits: PublicRepositoryLimits = .standard
    ) async throws -> VerifiedPublicRepositoryCAR {
        let collectingSink = InMemoryImportFrameSink()
        let parsed = try await parseIncrementally(
            from: source, to: collectingSink, limits: limits
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
                limits: limits
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
    public static func parseIncrementally(
        from source: any PublicRepositoryCARByteSource,
        to sink: any PublicRepositoryCARFrameSink,
        limits: PublicRepositoryLimits = .standard
    ) async throws -> PublicRepositoryCARParseResult {
        let reader = StreamingCARInput(source: source, maximumBytes: limits.maximumCARBytes)
        let headerLength = try await reader.readCanonicalVarint()
        guard headerLength <= UInt64(StreamingCARInput.maximumHeaderBytes) else {
            throw PublicRepositoryCARError.malformedHeader
        }
        let header = try await reader.readExactly(Int(headerLength))
        let root = try parseCanonicalHeader(header)
        try await sink.receiveHeader(
            rootCID: root,
            receivedByteCount: reader.receivedByteCount
        )

        var blockCount = 0
        while let frameLength = try await reader.readCanonicalVarintOrEOF() {
            try Task.checkCancellation()
            guard blockCount < limits.maximumCARBlocks else {
                throw PublicRepositoryCARError.blockLimitExceeded
            }
            guard frameLength > 36,
                  frameLength <= UInt64(36 + limits.maximumRecordBlockBytes) else {
                throw PublicRepositoryCARError.blockBodyLimitExceeded
            }
            let cidBytes = try await reader.readExactly(36)
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
            let body = try await reader.readExactly(Int(frameLength) - 36)
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
            frameCount: blockCount
        )
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

    private static func writeSegment(
        _ bytes: Data,
        to sink: any PublicRepositoryCARByteSink,
        total: inout Int,
        maximumTotal: Int,
        maximumChunkBytes: Int
    ) async throws {
        let (nextTotal, overflow) = total.addingReportingOverflow(bytes.count)
        guard !overflow, nextTotal <= maximumTotal else {
            throw PublicRepositoryCARError.byteLimitExceeded
        }
        var offset = 0
        while offset < bytes.count {
            try Task.checkCancellation()
            let end = min(bytes.count, offset + maximumChunkBytes)
            try await sink.write(Data(bytes[offset ..< end]))
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
        let result = Data(buffer[offset ..< offset + count])
        offset += count
        compactIfNeeded()
        return result
    }

    private var availableBytes: Int { buffer.count - offset }

    private func readByteOrEOF() async throws -> UInt8? {
        while availableBytes == 0 {
            guard try await fill(maximumBytes: 1) else { return nil }
        }
        let byte = buffer[offset]
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
            buffer.removeFirst(offset)
            offset = 0
        }
    }
}
