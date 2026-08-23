import Foundation
import Petrel

public enum PublicRepositoryDomainError: Error, Sendable, Equatable {
    case invalidCollection
    case invalidRecordKey
    case pathTooLong
    case invalidRevision
    case invalidDID
    case unsupportedCID
    case blockCIDMismatch
    case invalidRecordType
    case invalidRecordLink
    case invalidRecordInteger
    case recordNestingTooDeep
    case recordTooLarge
    case duplicateBlockConflict
    case relevantBlockBudgetExceeded
    case emptyWriteBatch
    case tooManyWrites
    case duplicateWritePath
}

/// A frozen repository-v3 `<collection>/<record-key>` path.
public struct PublicRepositoryPath: Hashable, Sendable, CustomStringConvertible {
    public static let maximumCollectionCharacters = 317
    public static let maximumRecordKeyCharacters = 512
    public static let maximumMSTKeyBytes = 1_024

    public let collection: String
    public let recordKey: String
    public let mstKey: String
    public let mstKeyBytes: Data
    public let keyDepth: Int

    public init(collection: String, recordKey: String) throws {
        guard Self.isValidCollection(collection) else {
            throw PublicRepositoryDomainError.invalidCollection
        }
        guard Self.isValidRecordKey(recordKey) else {
            throw PublicRepositoryDomainError.invalidRecordKey
        }
        let key = "\(collection)/\(recordKey)"
        let bytes = Data(key.utf8)
        guard bytes.count <= Self.maximumMSTKeyBytes else {
            throw PublicRepositoryDomainError.pathTooLong
        }
        self.collection = collection
        self.recordKey = recordKey
        self.mstKey = key
        self.mstKeyBytes = bytes
        self.keyDepth = RepositoryMSTCodec.keyDepth(forASCIIBytes: bytes)
    }

    public var description: String { mstKey }

    public static func == (lhs: PublicRepositoryPath, rhs: PublicRepositoryPath) -> Bool {
        lhs.mstKey == rhs.mstKey
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(mstKey)
    }

    /// Mirrors the human-readable validator in pinned `@atproto/syntax`.
    private static func isValidCollection(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard !bytes.isEmpty, bytes.count <= maximumCollectionCharacters else { return false }
        guard bytes.allSatisfy({ byte in
            (65...90).contains(byte) || (97...122).contains(byte)
                || (48...57).contains(byte) || byte == 45 || byte == 46
        }) else { return false }

        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 3 else { return false }
        for segment in segments {
            let segmentBytes = Array(segment.utf8)
            guard (1...63).contains(segmentBytes.count),
                  segmentBytes.first != 45,
                  segmentBytes.last != 45 else { return false }
        }
        guard let first = segments.first?.utf8.first, !(48...57).contains(first),
              let name = segments.last else { return false }
        let nameBytes = Array(name.utf8)
        guard let nameFirst = nameBytes.first,
              !(48...57).contains(nameFirst),
              !nameBytes.contains(45) else { return false }
        return true
    }

    private static func isValidRecordKey(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...maximumRecordKeyCharacters).contains(bytes.count),
              value != ".", value != ".." else { return false }
        return bytes.allSatisfy { byte in
            (65...90).contains(byte) || (97...122).contains(byte)
                || (48...57).contains(byte)
                || byte == 95 || byte == 126 || byte == 46
                || byte == 58 || byte == 45
        }
    }
}

/// Repository block CIDs are deliberately narrower than Petrel's general CID.
public enum PublicRepositoryCID {
    public static func validate(_ cid: CID) throws {
        let bytes = cid.bytes
        guard bytes.count == 36,
              bytes[bytes.startIndex] == 0x01,
              bytes[bytes.startIndex + 1] == CIDCodec.dagCBOR.rawValue,
              cid.multihash.algorithm == Multihash.sha256Code,
              cid.multihash.length == Multihash.sha256Length,
              cid.multihash.digest.count == 32 else {
            throw PublicRepositoryDomainError.unsupportedCID
        }
    }

    public static func validate(_ cid: CID, blockBytes: Data) throws {
        try validate(cid)
        guard CID.fromDAGCBOR(blockBytes) == cid else {
            throw PublicRepositoryDomainError.blockCIDMismatch
        }
    }
}

public struct PublicRepositoryState: Sendable, Equatable {
    public let did: String
    public let revision: String
    public let commitCID: CID
    public let dataCID: CID

    public init(did: String, revision: String, commitCID: CID, dataCID: CID) throws {
        guard (try? DID(didString: did)) != nil else {
            throw PublicRepositoryDomainError.invalidDID
        }
        _ = try PublicRepositoryTID(revision)
        try PublicRepositoryCID.validate(commitCID)
        try PublicRepositoryCID.validate(dataCID)
        self.did = did
        self.revision = revision
        self.commitCID = commitCID
        self.dataCID = dataCID
    }
}

public enum PublicRepositoryWrite: Sendable, Equatable {
    case create(path: PublicRepositoryPath, record: PublicRecord)
    case update(path: PublicRepositoryPath, record: PublicRecord, expectedRecordCID: CID?)
    case delete(path: PublicRepositoryPath, expectedRecordCID: CID?)

    public var path: PublicRepositoryPath {
        switch self {
        case let .create(path, _), let .update(path, _, _), let .delete(path, _):
            return path
        }
    }

    public var expectedRecordCID: CID? {
        switch self {
        case .create:
            return nil
        case let .update(_, _, expected), let .delete(_, expected):
            return expected
        }
    }
}

/// Shape-only validation performed before record encoding or MST reads.
public struct PublicRepositoryWriteBatch: Sendable, Equatable {
    public let writes: [PublicRepositoryWrite]
    public let expectedCommitCID: CID?

    public init(
        writes: [PublicRepositoryWrite],
        expectedCommitCID: CID? = nil,
        limits: PublicRepositoryLimits = .standard
    ) throws {
        guard !writes.isEmpty else { throw PublicRepositoryDomainError.emptyWriteBatch }
        guard writes.count <= limits.maximumWrites else { throw PublicRepositoryDomainError.tooManyWrites }
        var paths = Set<PublicRepositoryPath>()
        for write in writes {
            guard paths.insert(write.path).inserted else {
                throw PublicRepositoryDomainError.duplicateWritePath
            }
            if let cid = write.expectedRecordCID {
                try PublicRepositoryCID.validate(cid)
            }
        }
        if let expectedCommitCID {
            try PublicRepositoryCID.validate(expectedCommitCID)
        }
        self.writes = writes
        self.expectedCommitCID = expectedCommitCID
    }
}
