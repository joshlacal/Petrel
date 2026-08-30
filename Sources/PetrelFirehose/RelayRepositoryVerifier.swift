import Crypto
import Foundation
import Petrel
import PetrelRepo

public struct RelayVerifiedFullRepository: Sendable, Equatable {
  public let snapshot: RelayRepositorySnapshot
  public let records: [String: CID]

  public var head: RelayRepositoryHead { snapshot.head }

  fileprivate init(snapshot: RelayRepositorySnapshot) {
    self.snapshot = snapshot
    records = snapshot.records
  }
}

public enum RelayFullRepositoryVerifier {
  /// Structurally inspects a self-contained CAR so a live runner can bind the
  /// expected head before the authenticated verifier independently checks it.
  /// This makes no signature claim and must never be used as acceptance by
  /// itself.
  public static func inspect(car: Data) async throws -> RelayRepositorySnapshot {
    guard car.count <= PublicRepositoryLimits.standard.maximumCARBytes else {
      throw RelayVerifierError.repositoryCARTooLarge
    }
    let sink = RelayCARCollector()
    let parsed: PublicRepositoryCARParseResult
    do {
      parsed = try await PublicRepositoryCAR.parseIncrementally(
        from: RelayCARDataSource(car),
        to: sink
      )
    } catch {
      throw try mapRepositoryError(error)
    }
    let blocks = await sink.blocks
    guard let commitBytes = blocks[parsed.rootCID] else {
      throw RelayVerifierError.invalidRepositoryCAR
    }
    let commit: StructurallyValidatedPublicRepositorySignedCommit
    do {
      commit = try PublicRepositoryCommitCodec.structurallyValidate(
        signedCommitBytes: commitBytes,
        expectedCommitCID: parsed.rootCID
      )
    } catch {
      throw try mapRepositoryError(error)
    }
    let repository: ValidatedPublicRepositoryMST
    do {
      repository = try await RepositoryMSTValidation.validate(
        rootCID: commit.descriptor.dataCID,
        blocks: RelayDictionaryBlockSource(storage: blocks)
      )
    } catch {
      throw try mapRepositoryError(error)
    }
    let required = Set(repository.reachableMSTBlocks.keys)
      .union(repository.reachableRecordCIDs)
      .union([parsed.rootCID])
    guard required.isSubset(of: Set(blocks.keys)) else {
      throw RelayVerifierError.invalidRepositoryCAR
    }
    var records: [String: CID] = [:]
    for leaf in repository.leaves {
      guard records.updateValue(leaf.recordCID, forKey: leaf.path.mstKey) == nil else {
        throw RelayVerifierError.invalidRepositoryCAR
      }
    }
    return RelayRepositorySnapshot(
      did: commit.descriptor.did,
      revision: commit.descriptor.revision.value,
      commitCID: parsed.rootCID,
      dataCID: commit.descriptor.dataCID,
      records: records,
      mstDigest: RelayRepositoryVerificationState.mstDigest(
        repository.reachableMSTBlocks
      )
    )
  }

  public static func verify(
    car: Data,
    expected: RelayRepositoryHead,
    verifier: any PublicRepositoryCommitVerifier,
    storage: any RelayAcceptedHeadStorage,
    maximumCARBytes: Int = PublicRepositoryLimits.standard.maximumCARBytes
  ) async throws -> RelayVerifiedFullRepository {
    let state = try await RelayRepositoryVerificationState.fullSnapshot(
      car: car,
      expected: expected,
      verifier: verifier,
      storage: storage,
      maximumCARBytes: maximumCARBytes
    )
    return .init(snapshot: state.snapshot)
  }
}

/// Authenticated repository state retained only while an ephemeral relay
/// capture is being checked. Raw blocks are private and are never Codable or
/// included in the aggregate result.
public struct RelayRepositoryVerificationState: Sendable {
  public let snapshot: RelayRepositorySnapshot
  public let payloadKind: RelayRepositoryPayloadKind
  private let reachableBlocks: [CID: Data]

  private init(
    snapshot: RelayRepositorySnapshot,
    payloadKind: RelayRepositoryPayloadKind,
    reachableBlocks: [CID: Data]
  ) {
    self.snapshot = snapshot
    self.payloadKind = payloadKind
    self.reachableBlocks = reachableBlocks
  }

  public static func fullSnapshot(
    car: Data,
    expected: RelayRepositoryHead,
    verifier: any PublicRepositoryCommitVerifier,
    storage: any RelayAcceptedHeadStorage,
    maximumCARBytes: Int = PublicRepositoryLimits.standard.maximumCARBytes
  ) async throws -> Self {
    do {
      if let accepted = try await storage.loadAcceptedHead(for: expected.did) {
        let acceptedTID = try PublicRepositoryTID(accepted.revision)
        let expectedTID = try PublicRepositoryTID(expected.revision)
        guard acceptedTID < expectedTID else {
          throw RelayVerifierError.revisionRollback
        }
      }
    } catch let error as RelayVerifierError {
      throw error
    } catch {
      throw RelayVerifierError.storageFailure
    }
    let verified = try await verifyCAR(
      car,
      expectedRoot: expected.commitCID,
      previousBlocks: [:],
      requireSelfContainedRepository: true,
      verifier: verifier,
      maximumCARBytes: maximumCARBytes
    )
    try verifyHead(verified.snapshot.head, expected: expected)
    do {
      try await storage.saveAcceptedHead(verified.snapshot.head)
    } catch {
      throw RelayVerifierError.storageFailure
    }
    return .init(
      snapshot: verified.snapshot,
      payloadKind: .fullSnapshot,
      reachableBlocks: verified.reachableBlocks
    )
  }

  public static func activationSync(
    _ event: RelaySyncEvent,
    verifier: any PublicRepositoryCommitVerifier,
    storage: any RelayAcceptedHeadStorage
  ) async throws -> Self {
    do {
      if let accepted = try await storage.loadAcceptedHead(for: event.did) {
        let acceptedTID = try PublicRepositoryTID(accepted.revision)
        let eventTID = try PublicRepositoryTID(event.rev)
        guard acceptedTID < eventTID else {
          throw RelayVerifierError.revisionRollback
        }
      }
    } catch let error as RelayVerifierError {
      throw error
    } catch {
      throw RelayVerifierError.storageFailure
    }
    let verified = try await verifyCommitAnnouncement(event, verifier: verifier)
    guard verified.commit.descriptor.did == event.did else {
      throw RelayVerifierError.repositoryDIDMismatch
    }
    guard verified.commit.descriptor.revision.value == event.rev else {
      throw RelayVerifierError.commitRevisionMismatch
    }
    let emptyCID: CID
    do {
      emptyCID = try CID.parse(PublicRepositoryGenesisCodec.canonicalEmptyMSTCID)
    } catch {
      throw RelayVerifierError.invalidRepositoryCAR
    }
    guard verified.commit.descriptor.dataCID == emptyCID else {
      throw RelayVerifierError.invalidRepositoryCAR
    }
    let mstBlocks = [emptyCID: PublicRepositoryGenesisCodec.canonicalEmptyMST]
    let snapshot = RelayRepositorySnapshot(
      did: event.did,
      revision: event.rev,
      commitCID: verified.commit.commitCID,
      dataCID: emptyCID,
      records: [:],
      mstDigest: mstDigest(mstBlocks)
    )
    do {
      try await storage.saveAcceptedHead(snapshot.head)
    } catch {
      throw RelayVerifierError.storageFailure
    }
    return .init(
      snapshot: snapshot,
      payloadKind: .commitAnnouncement,
      reachableBlocks: [
        verified.commit.commitCID: verified.commit.signedCommitBytes,
        emptyCID: PublicRepositoryGenesisCodec.canonicalEmptyMST,
      ]
    )
  }

  public func synchronizing(
    _ event: RelaySyncEvent,
    verifier: any PublicRepositoryCommitVerifier,
    storage: any RelayAcceptedHeadStorage
  ) async throws -> Self {
    do {
      if let accepted = try await storage.loadAcceptedHead(for: event.did) {
        let acceptedTID = try PublicRepositoryTID(accepted.revision)
        let eventTID = try PublicRepositoryTID(event.rev)
        if acceptedTID > eventTID {
          throw RelayVerifierError.revisionRollback
        }
        if acceptedTID == eventTID {
          guard accepted.commitCID == snapshot.commitCID,
                accepted.dataCID == snapshot.dataCID else {
            throw RelayVerifierError.revisionRollback
          }
        }
      }
    } catch let error as RelayVerifierError {
      throw error
    } catch {
      throw RelayVerifierError.storageFailure
    }
    let verified = try await Self.verifyCommitAnnouncement(event, verifier: verifier)
    guard verified.commit.descriptor.did == event.did,
          event.did == snapshot.did else {
      throw RelayVerifierError.repositoryDIDMismatch
    }
    guard verified.commit.descriptor.revision.value == event.rev,
          event.rev == snapshot.revision else {
      throw RelayVerifierError.commitRevisionMismatch
    }
    guard verified.commit.commitCID == snapshot.commitCID else {
      throw RelayVerifierError.commitCIDMismatch
    }
    guard verified.commit.descriptor.dataCID == snapshot.dataCID else {
      throw RelayVerifierError.finalDataCIDMismatch
    }
    do {
      try await storage.saveAcceptedHead(snapshot.head)
    } catch {
      throw RelayVerifierError.storageFailure
    }
    return .init(
      snapshot: snapshot,
      payloadKind: .commitAnnouncement,
      reachableBlocks: reachableBlocks
    )
  }

  public func applying(
    commit event: RelayCommitEvent,
    verifier: any PublicRepositoryCommitVerifier,
    storage: any RelayAcceptedHeadStorage
  ) async throws -> Self {
    do {
      if let accepted = try await storage.loadAcceptedHead(for: event.repo) {
        let acceptedTID = try PublicRepositoryTID(accepted.revision)
        let eventTID = try PublicRepositoryTID(event.rev)
        guard acceptedTID < eventTID else {
          throw RelayVerifierError.revisionRollback
        }
      }
    } catch let error as RelayVerifierError {
      throw error
    } catch {
      throw RelayVerifierError.storageFailure
    }
    guard event.blocks.count <= FirehoseFrameLimits.maximumCommitBlocksBytes else {
      throw RelayVerifierError.commitBlocksTooLarge
    }
    let verified = try await Self.verifyCAR(
      event.blocks,
      expectedRoot: event.commitCID,
      previousBlocks: reachableBlocks,
      requireSelfContainedRepository: false,
      verifier: verifier,
      maximumCARBytes: FirehoseFrameLimits.maximumCommitBlocksBytes
    )
    try RelayCommitSemanticVerifier.verify(
      event: event,
      previous: snapshot,
      current: verified.snapshot
    )
    do {
      try await storage.saveAcceptedHead(verified.snapshot.head)
    } catch {
      throw RelayVerifierError.storageFailure
    }
    return .init(
      snapshot: verified.snapshot,
      payloadKind: .commitDiff,
      reachableBlocks: verified.reachableBlocks
    )
  }
  private static func verifyCAR(
    _ car: Data,
    expectedRoot: CID?,
    previousBlocks: [CID: Data],
    requireSelfContainedRepository: Bool,
    verifier: any PublicRepositoryCommitVerifier,
    maximumCARBytes: Int
  ) async throws -> (snapshot: RelayRepositorySnapshot, reachableBlocks: [CID: Data]) {
    guard maximumCARBytes > 0, car.count <= maximumCARBytes else {
      throw RelayVerifierError.repositoryCARTooLarge
    }
    let sink = RelayCARCollector()
    let parsed: PublicRepositoryCARParseResult
    do {
      parsed = try await PublicRepositoryCAR.parseIncrementally(
        from: RelayCARDataSource(car),
        to: sink
      )
    } catch {
      throw try mapRepositoryError(error)
    }
    if let expectedRoot, parsed.rootCID != expectedRoot {
      throw RelayVerifierError.commitCIDMismatch
    }
    let root = parsed.rootCID
    let diffBlocks = await sink.blocks
    guard let commitBytes = diffBlocks[root] else {
      throw RelayVerifierError.invalidRepositoryCAR
    }
    var merged = previousBlocks
    for (cid, bytes) in diffBlocks {
      if let existing = merged[cid], existing != bytes {
        throw RelayVerifierError.invalidRepositoryCAR
      }
      merged[cid] = bytes
    }
    let commit: VerifiedPublicRepositorySignedCommit
    do {
      commit = try await PublicRepositoryCommitCodec.verify(
        signedCommitBytes: commitBytes,
        expectedCommitCID: root,
        verifier: verifier
      )
    } catch {
      throw try mapRepositoryError(error)
    }
    let blockSource = RelayDictionaryBlockSource(storage: merged)
    let repository: ValidatedPublicRepositoryMST
    do {
      repository = try await RepositoryMSTValidation.validate(
        rootCID: commit.descriptor.dataCID,
        blocks: blockSource
      )
    } catch {
      throw try mapRepositoryError(error)
    }
    if requireSelfContainedRepository {
      let required = Set(repository.reachableMSTBlocks.keys)
        .union(repository.reachableRecordCIDs)
        .union([root])
      guard required.isSubset(of: Set(diffBlocks.keys)) else {
        throw RelayVerifierError.invalidRepositoryCAR
      }
    }
    var records: [String: CID] = [:]
    for leaf in repository.leaves {
      guard records.updateValue(leaf.recordCID, forKey: leaf.path.mstKey) == nil else {
        throw RelayVerifierError.invalidRepositoryCAR
      }
    }
    var reachable: [CID: Data] = [root: commitBytes]
    for cid in Set(repository.reachableMSTBlocks.keys).union(repository.reachableRecordCIDs) {
      guard let bytes = merged[cid] else { throw RelayVerifierError.invalidRepositoryCAR }
      reachable[cid] = bytes
    }
    let snapshot = RelayRepositorySnapshot(
      did: commit.descriptor.did,
      revision: commit.descriptor.revision.value,
      commitCID: root,
      dataCID: commit.descriptor.dataCID,
      records: records,
      mstDigest: mstDigest(repository.reachableMSTBlocks)
    )
    return (snapshot, reachable)
  }

  private static func verifyCommitAnnouncement(
    _ event: RelaySyncEvent,
    verifier: any PublicRepositoryCommitVerifier
  ) async throws -> (commit: VerifiedPublicRepositorySignedCommit, bytes: Data) {
    guard event.blocks.count <= FirehoseFrameLimits.maximumSyncBlocksBytes else {
      throw RelayVerifierError.syncBlocksTooLarge
    }
    let sink = RelayCARCollector()
    let parsed: PublicRepositoryCARParseResult
    do {
      parsed = try await PublicRepositoryCAR.parseIncrementally(
        from: RelayCARDataSource(event.blocks),
        to: sink
      )
    } catch {
      throw try mapRepositoryError(error)
    }
    let blocks = await sink.blocks
    guard parsed.frameCount == 1,
          blocks.count == 1,
          let bytes = blocks[parsed.rootCID] else {
      throw RelayVerifierError.invalidRepositoryCAR
    }
    do {
      let commit = try await PublicRepositoryCommitCodec.verify(
        signedCommitBytes: bytes,
        expectedCommitCID: parsed.rootCID,
        verifier: verifier
      )
      return (commit, bytes)
    } catch {
      throw try mapRepositoryError(error)
    }
  }

  private static func verifyHead(
    _ actual: RelayRepositoryHead,
    expected: RelayRepositoryHead
  ) throws {
    guard actual.did == expected.did else { throw RelayVerifierError.repositoryDIDMismatch }
    guard actual.revision == expected.revision else {
      throw RelayVerifierError.commitRevisionMismatch
    }
    guard actual.commitCID == expected.commitCID else {
      throw RelayVerifierError.commitCIDMismatch
    }
    guard actual.dataCID == expected.dataCID else {
      throw RelayVerifierError.finalDataCIDMismatch
    }
  }

  fileprivate static func mstDigest(_ blocks: [CID: Data]) -> String {
    var input = Data()
    for cid in blocks.keys.sorted(by: { $0.string < $1.string }) {
      input.append(cid.bytes)
      input.append(blocks[cid]!)
    }
    return "sha256:\(hex(SHA256.hash(data: input)))"
  }
}

public enum RelayRepositoryDigest {
  public static func projection(_ records: [String: CID]) -> String {
    var input = Data()
    for path in records.keys.sorted() {
      input.append(Data(path.utf8))
      input.append(0)
      input.append(records[path]!.bytes)
    }
    return "sha256:\(hex(SHA256.hash(data: input)))"
  }
}

private func mapRepositoryError(_ error: Error) throws -> RelayVerifierError {
  if error is CancellationError {
    throw CancellationError()
  }
  if let error = error as? PublicRepositoryCommitError, error == .invalidSignature {
    return .invalidCommitSignature
  }
  if let error = error as? PublicRepositoryCARError {
    if case .commit(.invalidSignature) = error { return .invalidCommitSignature }
  }
  return .invalidRepositoryCAR
}

private func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
  digest.map { String(format: "%02x", $0) }.joined()
}

private actor RelayCARDataSource: PublicRepositoryCARByteSource {
  private let data: Data
  private var offset = 0

  init(_ data: Data) {
    self.data = data
  }

  func read(maximumBytes: Int) async throws -> Data? {
    guard offset < data.count else { return nil }
    let end = min(data.count, offset + maximumBytes)
    defer { offset = end }
    return Data(data[offset ..< end])
  }
}

private actor RelayCARCollector: PublicRepositoryCARFrameSink {
  private(set) var blocks: [CID: Data] = [:]
  private var root: CID?

  func receiveHeader(rootCID: CID, receivedByteCount _: Int) async throws {
    guard root == nil || root == rootCID else {
      throw PublicRepositoryCARError.malformedHeader
    }
    root = rootCID
  }

  func receiveBlock(
    _ block: PublicRepositoryBlock,
    receivedByteCount _: Int,
    frameCount _: Int
  ) async throws {
    if let existing = blocks[block.cid], existing != block.bytes {
      throw PublicRepositoryCARError.duplicateBlockConflict
    }
    blocks[block.cid] = block.bytes
  }
}

private struct RelayDictionaryBlockSource: PublicRepositoryBlockSource {
  let storage: [CID: Data]

  func block(for cid: CID) async throws -> Data? { storage[cid] }
}
