import Foundation
import Petrel

public enum PublicRepositoryReferenceSurfaceError: Error, Sendable, Equatable {
    case invalidLimit
    case invalidCursor
    case tooManySelectors
    case missingRecord
    case missingBlock
    case invalidBinding
    case duplicatePath
    case duplicateRepository
}

public struct PublicRepositorySyncRepository: Sendable, Equatable {
    public let did: String
    public let head: CID
    public let rev: String
    public let createdAt: Date
    public let createdAtKey: Int64

    public init(did: String, head: CID, rev: String, createdAt: Date = Date(timeIntervalSince1970: 0), createdAtMilliseconds: Int64? = nil) throws {
        guard (try? DID(didString: did)) != nil else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        try PublicRepositoryCID.validate(head)
        _ = try PublicRepositoryTID(rev)
        self.did = did
        self.head = head
        self.rev = rev
        self.createdAt = createdAt
        self.createdAtKey = createdAtMilliseconds ?? Int64((createdAt.timeIntervalSince1970 * 1_000).rounded())
    }
}

public struct PublicRepositoryRecordIndexEntry: Sendable, Equatable {
    public let path: PublicRepositoryPath
    public let cid: CID

    public init(path: PublicRepositoryPath, cid: CID) throws {
        try PublicRepositoryCID.validate(cid)
        self.path = path
        self.cid = cid
    }
}

public struct PublicRepositorySyncRepoPage: Sendable, Equatable {
    public let repos: [PublicRepositorySyncRepository]
    public let cursor: String?
}

public struct PublicRepositorySyncBlockPage: Sendable, Equatable {
    public let blocks: [PublicRepositoryBlock]
    public let car: Data
}

public struct PublicRepositorySyncRecord: Sendable, Equatable {
    public let path: PublicRepositoryPath
    public let cid: CID
    public let bytes: Data
}

public struct PublicRepositorySyncRecordPage: Sendable, Equatable {
    public let records: [PublicRepositorySyncRecord]
    public let cursor: String?
}

public struct PublicRepositorySyncBlobPage: Sendable, Equatable {
    public let blobs: [PublicRepositoryMissingBlob]
    public let cursor: String?
}

public struct PublicRepositoryMissingBlob: Sendable, Equatable {
    public let cid: CID
    public let recordURI: String
}

public protocol PublicRepositoryMissingBlobStore: Sendable {
    func listMissingBlobs(accountDID: String, limit: Int, cursor: String?) async throws -> PublicRepositorySyncBlobPage
}

/// A bounded, storage-neutral implementation of the reference sync/repo
/// enumeration semantics. The HTTP adapters can map these projections to the
/// generated wire types without granting a caller an unbounded block or blob
/// query.
public actor PublicRepositoryReferenceSurface {
    private let accountDID: String
    private let repositories: [PublicRepositorySyncRepository]
    private let blocks: [CID: Data]
    private let records: [PublicRepositoryPath: CID]
    private let maximumPageSize: Int

    public init(
        did: String,
        revision: String,
        blocks: [PublicRepositoryBlock],
        records: [PublicRepositoryRecordIndexEntry],
        blobs: [CID] = [],
        repositories: [PublicRepositorySyncRepository]? = nil,
        blobRevisions: [CID: String] = [:],
        missingBlobStore: (any PublicRepositoryMissingBlobStore)? = nil,
        maximumPageSize: Int = 100
    ) throws {
        guard (1...1_000).contains(maximumPageSize) else { throw PublicRepositoryReferenceSurfaceError.invalidLimit }
        let map = try PublicRepositoryBlockMap(blocks: blocks)
        guard (try? DID(didString: did)) != nil else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        self.accountDID = did
        let candidateRepositories = repositories ?? []
        guard Set(candidateRepositories.map(\.did)).count == candidateRepositories.count else { throw PublicRepositoryReferenceSurfaceError.duplicateRepository }
        self.repositories = candidateRepositories.sorted {
            let lhs = $0.createdAtKey
            let rhs = $1.createdAtKey
            return lhs == rhs ? $0.did < $1.did : lhs < rhs
        }
        self.blocks = Dictionary(uniqueKeysWithValues: map.cids.compactMap { cid in map.block(for: cid).map { (cid, $0) } })
        var recordMap: [PublicRepositoryPath: CID] = [:]
        for entry in records {
            guard recordMap.updateValue(entry.cid, forKey: entry.path) == nil else { throw PublicRepositoryReferenceSurfaceError.duplicatePath }
        }
        self.records = recordMap
        self.maximumPageSize = maximumPageSize
        let blobSet = Set(blobs)
        for cid in blobSet { try PublicRepositoryCID.validate(cid) }
        for (cid, revision) in blobRevisions {
            _ = try PublicRepositoryTID(revision)
            guard blobSet.contains(cid) else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        }
        self.blobCIDs = blobSet
        self.blobRevisions = blobRevisions
        self.missingBlobStore = missingBlobStore
    }

    private let blobCIDs: Set<CID>
    private let blobRevisions: [CID: String]
    private let missingBlobStore: (any PublicRepositoryMissingBlobStore)?

    public func listRepos(limit: Int = 100, cursor: String? = nil, reverse: Bool = false) throws -> PublicRepositorySyncRepoPage {
        guard (1...maximumPageSize).contains(limit) else { throw PublicRepositoryReferenceSurfaceError.invalidLimit }
        let decodedCursor = try decodeRepoCursor(cursor)
        let ordered = reverse ? Array(repositories.reversed()) : repositories
        let values = ordered.filter { repo in
            guard let cursor = decodedCursor else { return true }
            let t = repo.createdAtKey
            if t == cursor.0 { return reverse ? repo.did < cursor.1 : repo.did > cursor.1 }
            return reverse ? t < cursor.0 : t > cursor.0
        }.prefix(limit)
        let page = Array(values)
        let next = page.count == limit && page.last != nil && ordered.contains(where: { repo in
            let boundary = page.last!
            let t = repo.createdAtKey
            let bt = boundary.createdAtKey
            return t == bt ? (reverse ? repo.did < boundary.did : repo.did > boundary.did) : (reverse ? t < bt : t > bt)
        }) ? encodeRepoCursor(page.last!) : nil
        return .init(repos: page, cursor: next)
    }

    public func getBlocks(_ cids: [CID], limit: Int = 100) async throws -> PublicRepositorySyncBlockPage {
        guard cids.count <= 10_000 else { throw PublicRepositoryReferenceSurfaceError.tooManySelectors }
        guard cids.count <= limit else { throw PublicRepositoryReferenceSurfaceError.invalidLimit }
        for cid in cids { try PublicRepositoryCID.validate(cid) }
        _ = try validatedLimit(limit)
        var found: [PublicRepositoryBlock] = []
        for cid in cids {
            guard let bytes = blocks[cid] else { throw PublicRepositoryReferenceSurfaceError.missingBlock }
            if !found.contains(where: { $0.cid == cid }) { found.append(.init(cid: cid, bytes: bytes)) }
        }
        guard let first = found.first else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        let sink = CollectingCARSink()
        _ = try await PublicRepositoryCAR.write(rootCID: first.cid, blocks: ArrayBlockStream(blocks: found), to: sink)
        return .init(blocks: found, car: await sink.data())
    }

    public func getRecord(path: PublicRepositoryPath) throws -> PublicRepositorySyncRecord {
        guard let cid = records[path], let bytes = blocks[cid] else { throw PublicRepositoryReferenceSurfaceError.missingRecord }
        return .init(path: path, cid: cid, bytes: bytes)
    }

    public func listRecords(collection: String, limit: Int = 100, cursor: String? = nil, reverse: Bool = false) throws -> PublicRepositorySyncRecordPage {
        guard (try? PublicRepositoryPath(collection: collection, recordKey: "_")) != nil else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        let decodedCursor = try decodeCursor(cursor)
        if let decodedCursor {
            guard let separator = decodedCursor.firstIndex(of: "/"), String(decodedCursor[..<separator]) == collection,
                  let key = try? PublicRepositoryPath(collection: collection, recordKey: String(decodedCursor[decodedCursor.index(after: separator)...])),
                  key.mstKey == decodedCursor else { throw PublicRepositoryReferenceSurfaceError.invalidCursor }
        }
        let ordered = records.keys.sorted { reverse ? $0.mstKey > $1.mstKey : $0.mstKey < $1.mstKey }
        let candidates = ordered
            .filter { path in
                guard path.collection == collection else { return false }
                return decodedCursor.map { reverse ? path.mstKey < $0 : path.mstKey > $0 } ?? true
            }
        let selected = Array(candidates.prefix(try validatedLimit(limit)))
        var page: [PublicRepositorySyncRecord] = []
        for path in selected {
            guard let cid = records[path], let bytes = blocks[cid] else { throw PublicRepositoryReferenceSurfaceError.missingBlock }
            page.append(.init(path: path, cid: cid, bytes: bytes))
        }
        let boundary = page.last?.path.mstKey ?? ""
        let next = page.count == limit && ordered.contains(where: { $0.collection == collection && (reverse ? $0.mstKey < boundary : $0.mstKey > boundary) }) ? encodeCursor(boundary) : nil
        return .init(records: page, cursor: next)
    }

    public func listBlobs(limit: Int = 100, since: String? = nil, cursor: String? = nil, reverse: Bool = false) throws -> PublicRepositorySyncBlobPage {
        if let since { _ = try PublicRepositoryTID(since) }
        let decodedCursor = try decodeCursor(cursor)
        if let decodedCursor { guard let cid = try? CID.parse(decodedCursor), (try? PublicRepositoryCID.validate(cid)) != nil, cid.string == decodedCursor else { throw PublicRepositoryReferenceSurfaceError.invalidCursor } }
        let values = blobCIDs.sorted { reverse ? $0.description > $1.description : $0.description < $1.description }.filter { cid in
            let afterCursor = decodedCursor.map { reverse ? cid.description < $0 : cid.description > $0 } ?? true
            let afterRevision: Bool
            if let since {
                afterRevision = blobRevisions[cid].map { $0 > since } ?? false
            } else {
                afterRevision = true
            }
            return afterCursor && afterRevision
        }
        let page = Array(values.prefix(try validatedLimit(limit)))
        let boundary = page.last?.description ?? ""
        let next = page.count == limit && values.contains(where: { reverse ? $0.description < boundary : $0.description > boundary }) ? encodeCursor(boundary) : nil
        return .init(blobs: page.map { .init(cid: $0, recordURI: "") }, cursor: next)
    }

    public func listMissingBlobs(accountDID: String, limit: Int = 100, cursor: String? = nil) async throws -> PublicRepositorySyncBlobPage {
        guard accountDID == self.accountDID, (try? DID(didString: accountDID)) != nil else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        _ = try validatedLimit(limit)
        guard let missingBlobStore else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        let page = try await missingBlobStore.listMissingBlobs(accountDID: accountDID, limit: limit, cursor: cursor)
        guard page.blobs.count <= limit, Set(page.blobs.map(\.cid)).count == page.blobs.count else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        for blob in page.blobs {
            try PublicRepositoryCID.validate(blob.cid)
            let authority = blob.recordURI.dropFirst(5)
            guard blob.recordURI.hasPrefix("at://"), blob.recordURI.utf8.count <= 2_048,
                  let authorityEnd = authority.firstIndex(of: "/"),
                  String(authority[..<authorityEnd]) == self.accountDID,
                  authority.distance(from: authorityEnd, to: authority.endIndex) > 1 else { throw PublicRepositoryReferenceSurfaceError.invalidBinding }
        }
        if let next = page.cursor { _ = try decodeCursor(next) }
        return page
    }

    private func pageRange(count: Int, limit: Int, cursor: String?) throws -> Range<Int> {
        _ = try validatedLimit(limit)
        let start: Int
        if let cursor {
            guard let parsed = Int(cursor), parsed >= 0, parsed <= count else { throw PublicRepositoryReferenceSurfaceError.invalidCursor }
            start = parsed
        } else { start = 0 }
        return start ..< min(start + limit, count)
    }

    private func validatedLimit(_ limit: Int) throws -> Int {
        guard (1...maximumPageSize).contains(limit) else { throw PublicRepositoryReferenceSurfaceError.invalidLimit }
        return limit
    }

    private func encodeCursor(_ value: String) -> String {
        Data(value.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private func decodeCursor(_ cursor: String?) throws -> String? {
        guard let cursor else { return nil }
        guard !cursor.isEmpty, cursor.utf8.count <= 2_048, cursor.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { throw PublicRepositoryReferenceSurfaceError.invalidCursor }
        var value = cursor.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let data = Data(base64Encoded: value), let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty else { throw PublicRepositoryReferenceSurfaceError.invalidCursor }
        return decoded
    }

    private func encodeRepoCursor(_ repo: PublicRepositorySyncRepository) -> String {
        encodeCursor("\(repo.createdAtKey)|\(repo.did)")
    }

    private func decodeRepoCursor(_ cursor: String?) throws -> (Int64, String)? {
        guard let value = try decodeCursor(cursor), let separator = value.firstIndex(of: "|"), let millis = Int64(value[..<separator]), !value[value.index(after: separator)...].isEmpty else {
            if cursor == nil { return nil }
            throw PublicRepositoryReferenceSurfaceError.invalidCursor
        }
        let did = String(value[value.index(after: separator)...])
        guard (try? DID(didString: did)) != nil else { throw PublicRepositoryReferenceSurfaceError.invalidCursor }
        return (millis, did)
    }

    private func nextCursor(end: Int, count: Int) -> String? { end < count ? String(end) : nil }
}

private actor CollectingCARSink: PublicRepositoryCARByteSink {
    private var bytes = Data()
    func write(_ bytes: Data) async throws { self.bytes.append(bytes) }
    func data() -> Data { bytes }
}

private actor ArrayBlockStream: PublicRepositoryCARBlockStream {
    private var blocks: [PublicRepositoryBlock]
    private var index = 0
    init(blocks: [PublicRepositoryBlock]) { self.blocks = blocks }
    func nextBlock() async throws -> PublicRepositoryBlock? {
        guard index < blocks.count else { return nil }
        defer { index += 1 }
        return blocks[index]
    }
}
