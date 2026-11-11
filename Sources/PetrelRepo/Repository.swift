import Foundation
import Petrel
import PetrelCrypto

// MARK: - Supporting types

/// How ``Repository`` establishes that a commit was signed by its account.
public enum RepositoryCommitVerification: Sendable {
    /// Check the commit signature against this key: the account's `#atproto`
    /// signing key, taken from its DID document. Either curve.
    case signingKey(ATProtoPublicKey)
    /// Ask a resolver for the key of the DID named in the commit, retrying
    /// once with a refreshed answer if the signature does not verify.
    case keyResolver(any RepositorySigningKeyResolver)
    /// Do not check the signature. The repository's structure and every block
    /// hash are still verified, but nothing ties the data to the account.
    /// Only for data whose origin is already trusted.
    case unauthenticated
}

/// Limits and tolerance for a ``Repository``.
public struct RepositoryOptions: Sendable, Equatable {
    /// Resource bounds. Defaults to ``PublicRepositoryLimits/networkScale``.
    public var limits: PublicRepositoryLimits
    /// What to tolerate in content the specification lets vary. Defaults to
    /// ``RepositoryReadPolicy/dataModel``.
    public var policy: RepositoryReadPolicy

    /// Creates options.
    public init(
        limits: PublicRepositoryLimits = .networkScale,
        policy: RepositoryReadPolicy = .dataModel
    ) {
        self.limits = limits
        self.policy = policy
    }

    /// Network-scale limits and the data-model read policy.
    public static let `default` = RepositoryOptions()
}

/// The commit a ``Repository`` is positioned at.
public struct RepositoryCommit: Sendable, Equatable {
    /// CID of the signed commit block.
    public let cid: CID
    /// The account DID.
    public let did: String
    /// The revision (`rev`).
    public let revision: PublicRepositoryTID
    /// CID of the MST root (`data`).
    public let dataCID: CID
    /// The `prev` link, or `nil` when the field is null.
    public let previousCommitCID: CID?
    /// The 64-byte signature.
    public let signature: Data
    /// The signed commit block.
    public let bytes: Data
    /// Whether the signature was checked against the account's key (or the
    /// commit was produced locally by the caller's signer).
    public let isSignatureVerified: Bool
}

/// What a full verification of a repository found.
public struct RepositoryStatistics: Sendable, Equatable {
    /// Number of records.
    public let recordCount: Int
    /// Number of MST nodes.
    public let mstNodeCount: Int
    /// Layer of the MST root.
    public let rootLayer: Int
    /// Records whose leaf link is not a blessed DAG-CBOR CID. Their links are
    /// retained; their blocks cannot be hashed or decoded by this library.
    /// Always 0 under ``RepositoryReadPolicy/strict``.
    public let unverifiableRecordCount: Int
}

/// Why a ``Repository`` operation failed.
public enum RepositoryError: Error, Sendable, Equatable {
    /// The CAR archive is malformed.
    case car(PublicRepositoryCARError)
    /// The commit object or its signature is invalid.
    case commit(PublicRepositoryCommitError)
    /// The MST or a record reachable from it is invalid.
    case tree(RepositoryMSTValidationError)
    /// The archive or store does not contain the commit block.
    case missingCommit
    /// The commit is for a different account than the caller expected.
    case didMismatch(expected: String, actual: String)
    /// The commit is version 2. Read it with
    /// ``PublicRepositoryCommitCodec/decodeLegacyV2(signedCommitBytes:expectedCommitCID:)``.
    case legacyCommitVersion
    /// A record named by the tree has no block in the store.
    case missingRecordBlock(path: String)
    /// A record block does not hash to the CID the tree names.
    case recordBlockCIDMismatch(path: String)
    /// A record block is not valid for its path under the read policy.
    case invalidRecord(path: String)
    /// The leaf link is not a blessed DAG-CBOR CID, so the record cannot be
    /// read (its link is still listed and preserved).
    case unsupportedRecordCID(path: String)
    /// A collection or record key is not valid.
    case invalidPath
    /// A write was refused.
    case write(PublicRepositoryEngineError)
    /// A write batch is malformed (too many writes, a repeated path).
    case invalidWrites(PublicRepositoryDomainError)
    /// A DID document does not carry a usable `#atproto` signing key.
    case signingKeyNotFound
}

/// One record read from a repository.
public struct RepositoryRecord: Sendable, Equatable {
    /// The record's path.
    public let path: PublicRepositoryPath
    /// CID of the record block.
    public let cid: CID
    /// The record block: canonical DAG-CBOR.
    public let bytes: Data

    private let limits: PublicRepositoryLimits
    private let policy: RepositoryReadPolicy

    init(
        path: PublicRepositoryPath, cid: CID, bytes: Data,
        limits: PublicRepositoryLimits, policy: RepositoryReadPolicy
    ) {
        self.path = path
        self.cid = cid
        self.bytes = bytes
        self.limits = limits
        self.policy = policy
    }

    /// The collection NSID.
    public var collection: String { path.collection }
    /// The record key.
    public var recordKey: String { path.recordKey }

    /// The record as Petrel's generic data-model container, the same type
    /// generated XRPC outputs use for unknown values.
    public func value() throws -> ATProtocolValueContainer {
        try RepositoryMSTValidation.decodeRecordBlock(
            bytes, for: path, limits: limits, policy: policy
        )
    }

    /// The record as a plain data-model value.
    public func record() throws -> PublicRecord {
        guard case let .object(fields) = try PublicRecordValue(dataModel: value()) else {
            throw RepositoryMSTValidationError.invalidRecordBlock
        }
        return PublicRecord(fields)
    }

    /// The record's JSON representation.
    public func json() throws -> Data {
        try record().jsonData()
    }
}

/// The blocks that prove whether a record exists at a path: the body of a
/// `com.atproto.sync.getRecord` response.
public struct RepositoryRecordProof: Sendable, Equatable {
    /// The commit the proof is relative to.
    public let commitCID: CID
    /// The path the proof is about.
    public let path: PublicRepositoryPath
    /// The record's CID, or `nil` if the proof shows the path is empty.
    public let recordCID: CID?
    /// The commit, the MST nodes on the search path, and the record if it
    /// exists, in that order.
    public let blocks: [PublicRepositoryBlock]

    /// The proof as a CAR archive whose root is the commit.
    public func car() async throws -> Data {
        try await PublicRepositoryCAR.encode(rootCID: commitCID, blocks: blocks)
    }
}

/// The outcome of checking a record proof.
public struct VerifiedRecordProof: Sendable, Equatable {
    /// The commit the proof is relative to, with its signature checked as
    /// requested.
    public let commit: RepositoryCommit
    /// The path the proof is about.
    public let path: PublicRepositoryPath
    /// The record, or `nil` if the proof shows that no record exists at the
    /// path in this commit.
    public let record: RepositoryRecord?
}

/// The order of blocks in an exported CAR archive.
public enum RepositoryCARBlockOrder: Sendable, Equatable {
    /// The specification's streamable order: the commit, then MST nodes in
    /// depth-first pre-order with each node's records interleaved in key
    /// order. Written with memory proportional to the tree's depth. A record
    /// shared by two paths is written once per path, which the format allows.
    case streamable
    /// The reference implementation's `getRepo` order: the commit, MST nodes
    /// breadth-first, then records. Holds the list of record CIDs in memory.
    case breadthFirst
    /// Every block in the store, in the order it was stored. For a store
    /// filled by one import this reproduces the imported archive byte for
    /// byte, including blocks that are not reachable from the commit.
    case stored
}

/// What ``Repository/commit(_:signer:revision:expectedCommitCID:)`` produced.
public struct RepositoryCommitResult: Sendable {
    /// The repository positioned at the new commit.
    public let repository: Repository
    /// The record operations, with previous CIDs for updates and deletes.
    public let operations: [RepositoryCommitOperation]
    /// CID of the commit this one replaced.
    public let previousCommitCID: CID
    /// MST root before the commit: `prevData` of the firehose event.
    public let previousDataCID: CID
    /// Revision of the commit this one replaced: `since` of the event.
    public let since: PublicRepositoryTID
    /// The blocks this commit added: the commit, new MST nodes, and created
    /// or updated records. Already written to the repository's store.
    public let newBlocks: [PublicRepositoryBlock]
    /// The commit's diff: ``newBlocks`` plus the unchanged MST nodes a
    /// consumer needs to verify the operations by inversion.
    public let diffBlocks: [PublicRepositoryBlock]

    /// The diff as a CAR archive whose root is the new commit: the `blocks`
    /// field of a `#commit` firehose event.
    public func diffCAR() async throws -> Data {
        try await PublicRepositoryCAR.encode(
            rootCID: repository.commit.cid,
            blocks: diffBlocks,
            limits: repository.options.limits
        )
    }
}

// MARK: - Repository

/// An account's repository at one commit: its records, the Merkle Search
/// Tree that indexes them, and the signed commit over the tree's root.
///
/// `Repository` is the one type to reach for when working with repositories.
/// It reads a `com.atproto.sync.getRepo` export and verifies it end to end,
/// looks up and enumerates records, produces and checks record proofs, applies
/// writes as new signed commits, and exports CAR archives.
///
/// A value is immutable and cheap to copy: it holds the head commit and a
/// reference to a ``RepositoryBlockStore``. Blocks are read from the store on
/// demand, so memory use is set by the store, not by the repository's size.
///
/// ```swift
/// let key = try ATProtoPublicKey(didKey: "did:key:zQ3sh…")
/// let repo = try await Repository.open(car: exportBytes, verification: .signingKey(key))
///
/// if let post = try await repo.record(collection: "app.bsky.feed.post", recordKey: "3k…") {
///     let json = try post.json()
/// }
/// ```
///
/// ## What `open` verifies
///
/// 1. CAR framing, and that every block hashes to its CID.
/// 2. The commit: canonical encoding, and its signature against the account's
///    key (unless you pass ``RepositoryCommitVerification/unauthenticated``).
/// 3. The whole tree: node encoding, key order, key depth per layer, and
///    that every record block is present, intact and a valid record.
public struct Repository: Sendable {
    /// The commit this value is positioned at.
    public let commit: RepositoryCommit
    /// Where the repository's blocks live.
    public let store: any RepositoryBlockStore
    /// The limits and read policy in force.
    public let options: RepositoryOptions
    /// Counts from the full verification done when the repository was
    /// opened. `nil` if it was opened without walking the tree.
    public let statistics: RepositoryStatistics?

    /// The account DID.
    public var did: String { commit.did }
    /// The current revision.
    public var revision: PublicRepositoryTID { commit.revision }

    init(
        commit: RepositoryCommit,
        store: any RepositoryBlockStore,
        options: RepositoryOptions,
        statistics: RepositoryStatistics?
    ) {
        self.commit = commit
        self.store = store
        self.options = options
        self.statistics = statistics
    }

    // MARK: Opening

    /// Opens and fully verifies a repository from a CAR archive in memory.
    ///
    /// - Parameters:
    ///   - car: A `com.atproto.sync.getRepo` response body.
    ///   - verification: How to authenticate the commit.
    ///   - expectedDID: If given, the commit must be for this account.
    ///   - store: Where to put the blocks. An in-memory store by default.
    ///   - options: Limits and read policy.
    /// - Throws: ``RepositoryError``, or an error from the store.
    public static func open(
        car: Data,
        verification: RepositoryCommitVerification,
        expectedDID: String? = nil,
        store: any RepositoryBlockStore = InMemoryRepositoryBlockStore(),
        options: RepositoryOptions = .default
    ) async throws -> Repository {
        try await open(
            from: DataCARByteSource(car),
            verification: verification,
            expectedDID: expectedDID,
            store: store,
            options: options
        )
    }

    /// Opens and fully verifies a repository from a CAR file, reading it as a
    /// stream.
    ///
    /// The file is never loaded whole. With a ``FileRepositoryBlockStore``
    /// the import, the verification and any later read use memory
    /// proportional to the number of blocks (for the index) and the depth of
    /// the tree, not to the size of the archive.
    ///
    /// - Parameters:
    ///   - carFile: Location of the archive.
    ///   - verification: How to authenticate the commit.
    ///   - expectedDID: If given, the commit must be for this account.
    ///   - store: Where to put the blocks.
    ///   - options: Limits and read policy.
    public static func open(
        carFile: URL,
        verification: RepositoryCommitVerification,
        expectedDID: String? = nil,
        store: any RepositoryBlockStore = InMemoryRepositoryBlockStore(),
        options: RepositoryOptions = .default
    ) async throws -> Repository {
        try await open(
            from: FileCARByteSource(url: carFile),
            verification: verification,
            expectedDID: expectedDID,
            store: store,
            options: options
        )
    }

    /// Opens and fully verifies a repository from any stream of CAR bytes,
    /// for example a network response body.
    public static func open(
        from source: any PublicRepositoryCARByteSource,
        verification: RepositoryCommitVerification,
        expectedDID: String? = nil,
        store: any RepositoryBlockStore = InMemoryRepositoryBlockStore(),
        options: RepositoryOptions = .default
    ) async throws -> Repository {
        let parsed: PublicRepositoryCARParseResult
        do {
            parsed = try await PublicRepositoryCAR.parseIncrementally(
                from: source,
                to: RepositoryStoreFrameSink(store: store),
                limits: options.limits,
                policy: options.policy
            )
        } catch let error as PublicRepositoryCARError {
            throw RepositoryError.car(error)
        }
        return try await open(
            commitCID: parsed.rootCID,
            store: store,
            verification: verification,
            expectedDID: expectedDID,
            options: options
        )
    }

    /// Opens a repository whose blocks are already in a store.
    ///
    /// - Parameters:
    ///   - commitCID: The head commit.
    ///   - store: The store holding the commit, the tree and the records.
    ///   - verification: How to authenticate the commit.
    ///   - expectedDID: If given, the commit must be for this account.
    ///   - options: Limits and read policy.
    ///   - verifiesTree: Walk and check the whole tree and every record
    ///     (the default). Pass `false` only to reopen a store this process
    ///     already verified; reads still re-hash each block they touch.
    public static func open(
        commitCID: CID,
        store: any RepositoryBlockStore,
        verification: RepositoryCommitVerification,
        expectedDID: String? = nil,
        options: RepositoryOptions = .default,
        verifiesTree: Bool = true
    ) async throws -> Repository {
        guard let commitBytes = try await store.block(for: commitCID) else {
            throw RepositoryError.missingCommit
        }
        let commit = try await verifiedCommit(
            bytes: commitBytes,
            cid: commitCID,
            verification: verification,
            expectedDID: expectedDID
        )
        let unverified = Repository(commit: commit, store: store, options: options, statistics: nil)
        guard verifiesTree else { return unverified }
        let statistics = try await unverified.verify()
        return Repository(commit: commit, store: store, options: options, statistics: statistics)
    }

    /// Creates a new, empty repository: an empty tree and a signed first
    /// commit, written to `store`.
    ///
    /// - Parameters:
    ///   - did: The account DID.
    ///   - signer: The account's signing key, on either curve.
    ///   - store: Where to put the blocks.
    ///   - revision: The first revision. The current time by default.
    ///   - options: Limits and read policy.
    public static func create(
        did: String,
        signer: any ATProtoSigner,
        store: any RepositoryBlockStore = InMemoryRepositoryBlockStore(),
        revision: PublicRepositoryTID? = nil,
        options: RepositoryOptions = .default
    ) async throws -> Repository {
        let emptyTree = PublicRepositoryGenesisCodec.canonicalEmptyMST
        let dataCID = CID.fromDAGCBOR(emptyTree)
        let prepared: PreparedPublicRepositorySignedCommit
        do {
            prepared = try await PublicRepositoryCommitCodec.prepare(
                did: did,
                revision: try (revision ?? PublicRepositoryTID.next(after: nil)).value,
                dataCID: dataCID,
                signer: signer
            )
        } catch let error as PublicRepositoryCommitError {
            throw RepositoryError.commit(error)
        }
        try await store.put(PublicRepositoryBlock(cid: dataCID, bytes: emptyTree))
        try await store.put(PublicRepositoryBlock(
            cid: prepared.commitCID, bytes: prepared.signedCommitBytes
        ))
        try await store.flush()
        return Repository(
            commit: RepositoryCommit(
                cid: prepared.commitCID,
                did: prepared.descriptor.did,
                revision: prepared.descriptor.revision,
                dataCID: dataCID,
                previousCommitCID: nil,
                signature: prepared.signature,
                bytes: prepared.signedCommitBytes,
                isSignatureVerified: true
            ),
            store: store,
            options: options,
            statistics: RepositoryStatistics(
                recordCount: 0, mstNodeCount: 1, rootLayer: 0, unverifiableRecordCount: 0
            )
        )
    }

    /// Extracts an account's repository signing key from its DID document.
    ///
    /// The key is the verification method whose `id` ends in `#atproto`, as
    /// the DID specification for atproto defines. Both the `Multikey` form
    /// and the two legacy `EcdsaSecp256…VerificationKey2019` forms are read.
    ///
    /// - Parameters:
    ///   - json: The DID document, as served by the PLC directory or a
    ///     `did:web` host.
    ///   - did: The account DID; the document's `id` must equal it.
    /// - Throws: ``RepositoryError/signingKeyNotFound``.
    public static func signingKey(fromDIDDocument json: Data, did: String) throws -> ATProtoPublicKey {
        guard let document = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              document["id"] as? String == did,
              let methods = document["verificationMethod"] as? [[String: Any]] else {
            throw RepositoryError.signingKeyNotFound
        }
        for method in methods {
            guard let id = method["id"] as? String,
                  id == "#atproto" || id == "\(did)#atproto",
                  let type = method["type"] as? String,
                  let multibase = method["publicKeyMultibase"] as? String else {
                continue
            }
            if let controller = method["controller"] as? String, controller != did {
                continue
            }
            do {
                return try ATProtoPublicKey(
                    verificationMethodType: type, publicKeyMultibase: multibase
                )
            } catch {
                throw RepositoryError.signingKeyNotFound
            }
        }
        throw RepositoryError.signingKeyNotFound
    }

    // MARK: Verifying

    /// Walks the whole tree and checks every node and every record.
    ///
    /// ``open(car:verification:expectedDID:store:options:)`` does this once.
    /// Call it again to re-check a store that may have changed underneath
    /// the repository. Memory use is proportional to the tree's depth.
    @discardableResult
    public func verify() async throws -> RepositoryStatistics {
        var unverifiable = 0
        let summary = try await walk(range: .all) { leaf in
            guard leaf.recordCID.blessedKind == .dagCBOR else {
                unverifiable += 1
                return
            }
            _ = try await self.loadRecord(at: leaf.path, cid: leaf.recordCID)
        }
        return RepositoryStatistics(
            recordCount: summary.recordCount,
            mstNodeCount: summary.nodeCount,
            rootLayer: summary.rootLayer,
            unverifiableRecordCount: unverifiable
        )
    }

    // MARK: Reading

    /// The CID of the record at a path, or `nil` if there is none.
    ///
    /// Reads only the MST nodes on the path to the key.
    public func recordCID(collection: String, recordKey: String) async throws -> CID? {
        let path = try Self.path(collection: collection, recordKey: recordKey)
        do {
            return try await RepositoryMSTProof.membership(
                rootCID: commit.dataCID,
                path: path,
                blocks: store,
                limits: options.limits,
                options: options.policy.mstOptions
            )
        } catch let error as RepositoryMSTValidationError {
            throw RepositoryError.tree(error)
        }
    }

    /// The record at a path, or `nil` if there is none.
    public func record(collection: String, recordKey: String) async throws -> RepositoryRecord? {
        let path = try Self.path(collection: collection, recordKey: recordKey)
        guard let cid = try await recordCID(collection: collection, recordKey: recordKey) else {
            return nil
        }
        return try await loadRecord(at: path, cid: cid)
    }

    /// Calls `body` with every record, in key order: collections in byte
    /// order, record keys in byte order within each.
    ///
    /// - Parameters:
    ///   - collection: Only this collection. All collections if `nil`.
    ///   - body: Receives each record. Records whose leaf link is not a
    ///     blessed DAG-CBOR CID are skipped; use
    ///     ``forEachRecordReference(collection:_:)`` to see their links.
    public func forEachRecord(
        collection: String? = nil,
        _ body: (RepositoryRecord) async throws -> Void
    ) async throws {
        try await walk(range: try Self.range(collection: collection)) { leaf in
            guard leaf.recordCID.blessedKind == .dagCBOR else { return }
            try await body(self.loadRecord(at: leaf.path, cid: leaf.recordCID))
        }
    }

    /// Calls `body` with the path and CID of every record, in key order,
    /// without reading any record block.
    public func forEachRecordReference(
        collection: String? = nil,
        _ body: (PublicRepositoryPath, CID) async throws -> Void
    ) async throws {
        try await walk(range: try Self.range(collection: collection)) { leaf in
            try await body(leaf.path, leaf.recordCID)
        }
    }

    /// Every record of one collection, in record-key order.
    ///
    /// Convenient for small collections. For large ones prefer
    /// ``forEachRecord(collection:_:)``, which does not accumulate.
    public func records(collection: String) async throws -> [RepositoryRecord] {
        var result: [RepositoryRecord] = []
        try await forEachRecord(collection: collection) { result.append($0) }
        return result
    }

    /// The collections that have at least one record, in byte order.
    public func collections() async throws -> [String] {
        var result: [String] = []
        try await forEachRecordReference { path, _ in
            if result.last != path.collection { result.append(path.collection) }
        }
        return result
    }

    /// The repository's MST, for operations this type does not wrap.
    public func tree() throws -> RepositoryMST {
        try RepositoryMST.load(
            rootCID: commit.dataCID,
            blocks: store,
            limits: options.limits,
            options: options.policy.mstOptions
        )
    }

    // MARK: Proofs

    /// Builds the proof that a record exists at a path, or that none does.
    ///
    /// The result is what a server returns from
    /// `com.atproto.sync.getRecord`: the signed commit, the MST nodes on the
    /// path to the key, and the record block if the key is present.
    public func recordProof(collection: String, recordKey: String) async throws -> RepositoryRecordProof {
        let path = try Self.path(collection: collection, recordKey: recordKey)
        let found: (nodes: [PublicRepositoryBlock], recordCID: CID?)
        do {
            found = try await RepositoryMSTProof.pathBlocks(
                rootCID: commit.dataCID,
                path: path,
                blocks: store,
                limits: options.limits,
                options: options.policy.mstOptions
            )
        } catch let error as RepositoryMSTValidationError {
            throw RepositoryError.tree(error)
        }
        var blocks = [PublicRepositoryBlock(cid: commit.cid, bytes: commit.bytes)]
        blocks.append(contentsOf: found.nodes)
        if let recordCID = found.recordCID {
            let record = try await loadRecord(at: path, cid: recordCID)
            blocks.append(PublicRepositoryBlock(cid: record.cid, bytes: record.bytes))
        }
        return RepositoryRecordProof(
            commitCID: commit.cid,
            path: path,
            recordCID: found.recordCID,
            blocks: blocks
        )
    }

    /// Checks a record proof: the body of a `com.atproto.sync.getRecord`
    /// response.
    ///
    /// The proof is accepted only if the commit is for `did` and is signed
    /// as `verification` requires, and every MST node from the commit's root
    /// to the key is present and hashes to the link that names it. A proof
    /// with a node missing throws; it is never read as "no such record".
    ///
    /// - Parameters:
    ///   - car: The proof archive.
    ///   - did: The account the record is claimed to belong to.
    ///   - collection: The record's collection.
    ///   - recordKey: The record's key.
    ///   - verification: How to authenticate the commit.
    ///   - options: Limits and read policy.
    /// - Returns: The record, or a result whose `record` is `nil` when the
    ///   proof shows the path is empty in this commit.
    public static func verifyRecordProof(
        car: Data,
        did: String,
        collection: String,
        recordKey: String,
        verification: RepositoryCommitVerification,
        options: RepositoryOptions = .default
    ) async throws -> VerifiedRecordProof {
        let path = try Self.path(collection: collection, recordKey: recordKey)
        let store = InMemoryRepositoryBlockStore()
        let parsed: PublicRepositoryCARParseResult
        do {
            parsed = try await PublicRepositoryCAR.parseIncrementally(
                from: DataCARByteSource(car),
                to: RepositoryStoreFrameSink(store: store),
                limits: options.limits,
                policy: options.policy
            )
        } catch let error as PublicRepositoryCARError {
            throw RepositoryError.car(error)
        }
        // A proof holds only part of the tree, so the tree is not walked.
        let repository = try await open(
            commitCID: parsed.rootCID,
            store: store,
            verification: verification,
            expectedDID: did,
            options: options,
            verifiesTree: false
        )
        let record = try await repository.record(collection: collection, recordKey: recordKey)
        return VerifiedRecordProof(commit: repository.commit, path: path, record: record)
    }

    // MARK: Writing

    /// Applies record writes and signs a new commit.
    ///
    /// The new blocks are written to the repository's store and the returned
    /// result carries a `Repository` positioned at the new commit. This value
    /// is unchanged and still describes the previous commit.
    ///
    /// An empty `writes` array produces a new commit over the unchanged tree,
    /// which is what an account publishes after rotating its signing key.
    ///
    /// - Parameters:
    ///   - writes: Creates, updates and deletes. A path may appear once.
    ///   - signer: The account's signing key, on either curve.
    ///   - revision: The new revision. By default the current time, or one
    ///     microsecond after the current revision if the clock has not
    ///     advanced past it; revisions never repeat or go backwards.
    ///   - expectedCommitCID: Refuse to write unless the repository is at
    ///     this commit (compare-and-swap).
    /// - Throws: ``RepositoryError``.
    public func commit(
        _ writes: [PublicRepositoryWrite],
        signer: any ATProtoSigner,
        revision: PublicRepositoryTID? = nil,
        expectedCommitCID: CID? = nil
    ) async throws -> RepositoryCommitResult {
        let batch: PublicRepositoryWriteBatch
        let state: PublicRepositoryState
        let nextRevision: PublicRepositoryTID
        do {
            batch = writes.isEmpty
                ? try .empty(expectedCommitCID: expectedCommitCID)
                : try PublicRepositoryWriteBatch(
                    writes: writes,
                    expectedCommitCID: expectedCommitCID,
                    limits: options.limits
                )
            state = try PublicRepositoryState(
                did: commit.did,
                revision: commit.revision.value,
                commitCID: commit.cid,
                dataCID: commit.dataCID
            )
            nextRevision = try revision ?? PublicRepositoryTID.next(after: commit.revision)
        } catch let error as PublicRepositoryDomainError {
            throw RepositoryError.invalidWrites(error)
        }

        let mutation: PreparedPublicRepositoryMutation
        do {
            mutation = try await PublicRepositoryEngine.apply(
                repositoryDID: commit.did,
                currentState: state,
                blocks: store,
                revision: nextRevision.value,
                batch: batch,
                limits: options.limits,
                signer: ATProtoRepositoryCommitSigner(signer),
                mstOptions: options.policy.mstOptions
            )
        } catch let error as PublicRepositoryEngineError {
            throw RepositoryError.write(error)
        }

        let newBlocks = mutation.newBlocks.orderedBlocks
        try await store.put(newBlocks)
        try await store.flush()

        // The commit leads the diff, as it must lead a CAR slice.
        let commitBlock = PublicRepositoryBlock(
            cid: mutation.signedCommit.commitCID,
            bytes: mutation.signedCommit.signedCommitBytes
        )
        let diffBlocks = [commitBlock]
            + mutation.relevantBlocks.orderedBlocks.filter { $0.cid != commitBlock.cid }

        let recordDelta = mutation.recordResults.reduce(0) { total, result in
            switch result.action {
            case .create: return total + 1
            case .delete: return total - 1
            case .update: return total
            }
        }
        let next = Repository(
            commit: RepositoryCommit(
                cid: mutation.signedCommit.commitCID,
                did: commit.did,
                revision: mutation.signedCommit.descriptor.revision,
                dataCID: mutation.signedCommit.descriptor.dataCID,
                previousCommitCID: nil,
                signature: mutation.signedCommit.signature,
                bytes: mutation.signedCommit.signedCommitBytes,
                isSignatureVerified: true
            ),
            store: store,
            options: options,
            // Node count and root layer are not tracked across writes; call
            // `verify()` for fresh figures.
            statistics: statistics.map {
                RepositoryStatistics(
                    recordCount: $0.recordCount + recordDelta,
                    mstNodeCount: $0.mstNodeCount,
                    rootLayer: $0.rootLayer,
                    unverifiableRecordCount: $0.unverifiableRecordCount
                )
            }
        )
        return RepositoryCommitResult(
            repository: next,
            operations: mutation.operations,
            previousCommitCID: commit.cid,
            previousDataCID: mutation.previousDataCID,
            since: commit.revision,
            newBlocks: newBlocks,
            diffBlocks: diffBlocks
        )
    }

    // MARK: Exporting

    /// Writes the repository as a CAR archive.
    ///
    /// - Parameters:
    ///   - sink: Receives the archive bytes as they are produced.
    ///   - order: Block order. ``RepositoryCARBlockOrder/streamable`` by
    ///     default, which needs the least memory.
    /// - Returns: The number of bytes and blocks written.
    @discardableResult
    public func exportCAR(
        to sink: any PublicRepositoryCARByteSink,
        order: RepositoryCARBlockOrder = .streamable
    ) async throws -> PublicRepositoryCARWriteResult {
        do {
            switch order {
            case .streamable:
                let writer = try CARFrameWriter(sink: sink, limits: options.limits)
                try await writer.writeHeader(rootCID: commit.cid)
                try await writer.writeBlock(PublicRepositoryBlock(cid: commit.cid, bytes: commit.bytes))
                try await walk(range: .all, onNode: { try await writer.writeBlock($0) }) { leaf in
                    guard leaf.recordCID.blessedKind == .dagCBOR else { return }
                    let record = try await self.loadRecord(at: leaf.path, cid: leaf.recordCID)
                    try await writer.writeBlock(PublicRepositoryBlock(cid: record.cid, bytes: record.bytes))
                }
                return writer.result
            case .breadthFirst:
                let structural = try PublicRepositoryCommitCodec.structurallyValidate(
                    signedCommitBytes: commit.bytes,
                    expectedCommitCID: commit.cid
                )
                return try await PublicRepositoryCAR.export(
                    signedCommit: structural,
                    blocks: store,
                    to: sink,
                    limits: options.limits,
                    policy: options.policy
                )
            case .stored:
                let writer = try CARFrameWriter(sink: sink, limits: options.limits)
                try await writer.writeHeader(rootCID: commit.cid)
                for cid in try await store.storedCIDs() {
                    guard let bytes = try await store.block(for: cid) else {
                        throw RepositoryError.tree(.missingBlock)
                    }
                    try await writer.writeBlock(PublicRepositoryBlock(cid: cid, bytes: bytes))
                }
                return writer.result
            }
        } catch let error as PublicRepositoryCARError {
            throw RepositoryError.car(error)
        } catch let error as PublicRepositoryCommitError {
            throw RepositoryError.commit(error)
        }
    }

    /// The repository as a CAR archive in memory.
    public func exportCAR(order: RepositoryCARBlockOrder = .streamable) async throws -> Data {
        let sink = DataCARByteSink()
        try await exportCAR(to: sink, order: order)
        return await sink.data
    }

    // MARK: Internals

    private static func path(collection: String, recordKey: String) throws -> PublicRepositoryPath {
        do {
            return try PublicRepositoryPath(collection: collection, recordKey: recordKey)
        } catch {
            throw RepositoryError.invalidPath
        }
    }

    private static func range(collection: String?) throws -> RepositoryMSTWalker.KeyRange {
        guard let collection else { return .all }
        // Validate the NSID by building a path with a placeholder key.
        _ = try path(collection: collection, recordKey: "self")
        return .collection(collection)
    }

    @discardableResult
    private func walk(
        range: RepositoryMSTWalker.KeyRange,
        onNode: ((PublicRepositoryBlock) async throws -> Void)? = nil,
        _ onLeaf: (RepositoryMSTLeaf) async throws -> Void
    ) async throws -> RepositoryMSTWalkSummary {
        do {
            return try await RepositoryMSTWalker.walk(
                rootCID: commit.dataCID,
                blocks: store,
                limits: options.limits,
                options: options.policy.mstOptions,
                range: range,
                onNode: onNode
            ) { leaf in
                try await onLeaf(leaf)
                return true
            }
        } catch let error as RepositoryMSTValidationError {
            throw RepositoryError.tree(error)
        }
    }

    /// Reads one record block, re-hashes it, and checks it is a valid record
    /// for its path.
    private func loadRecord(at path: PublicRepositoryPath, cid: CID) async throws -> RepositoryRecord {
        guard cid.blessedKind == .dagCBOR else {
            throw RepositoryError.unsupportedRecordCID(path: path.mstKey)
        }
        guard let bytes = try await store.block(for: cid) else {
            throw RepositoryError.missingRecordBlock(path: path.mstKey)
        }
        guard cid.matchesContent(bytes) else {
            throw RepositoryError.recordBlockCIDMismatch(path: path.mstKey)
        }
        do {
            try RepositoryMSTValidation.validateRecordBlock(
                bytes, for: path, limits: options.limits, policy: options.policy
            )
        } catch {
            throw RepositoryError.invalidRecord(path: path.mstKey)
        }
        return RepositoryRecord(
            path: path, cid: cid, bytes: bytes,
            limits: options.limits, policy: options.policy
        )
    }

    private static func verifiedCommit(
        bytes: Data,
        cid: CID,
        verification: RepositoryCommitVerification,
        expectedDID: String?
    ) async throws -> RepositoryCommit {
        do {
            guard try PublicRepositoryCommitCodec.commitVersion(ofSignedCommitBytes: bytes) == 3 else {
                throw RepositoryError.legacyCommitVersion
            }
            let descriptor: PublicRepositoryCommitDescriptor
            let signature: Data
            let isVerified: Bool
            switch verification {
            case let .signingKey(key):
                let verified = try PublicRepositoryCommitCodec.verify(
                    signedCommitBytes: bytes, expectedCommitCID: cid, publicKey: key
                )
                (descriptor, signature, isVerified) = (verified.descriptor, verified.signature, true)
            case let .keyResolver(resolver):
                let verified = try await PublicRepositoryCommitCodec.verify(
                    signedCommitBytes: bytes, expectedCommitCID: cid, keyResolver: resolver
                )
                (descriptor, signature, isVerified) = (verified.descriptor, verified.signature, true)
            case .unauthenticated:
                let structural = try PublicRepositoryCommitCodec.structurallyValidate(
                    signedCommitBytes: bytes, expectedCommitCID: cid
                )
                (descriptor, signature, isVerified) = (structural.descriptor, structural.signature, false)
            }
            if let expectedDID, expectedDID != descriptor.did {
                throw RepositoryError.didMismatch(expected: expectedDID, actual: descriptor.did)
            }
            return RepositoryCommit(
                cid: cid,
                did: descriptor.did,
                revision: descriptor.revision,
                dataCID: descriptor.dataCID,
                previousCommitCID: descriptor.previousCommitCID,
                signature: signature,
                bytes: bytes,
                isSignatureVerified: isVerified
            )
        } catch let error as PublicRepositoryCommitError {
            throw RepositoryError.commit(error)
        }
    }
}
