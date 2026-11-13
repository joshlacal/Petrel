import Foundation
import Petrel
import PetrelCrypto
@testable import PetrelFirehose
@testable import PetrelRepo
import Testing

/// A decoded `#commit` or `#sync` event verifies in one call.
///
/// Each event is produced the way a PDS would: a real repository commit (secp256k1), its diff
/// CAR, encoded into a wire frame and decoded by the relay frame decoder. Every time is fixed.
@Suite("Relay event verification")
struct RelayCommitVerificationTests {
  private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  private let posts = "app.bsky.feed.post"
  /// 2030-01-01T00:00:00Z: the time every test commit is signed at.
  private let signedAt = Date(timeIntervalSince1970: 1_893_456_000)

  private func path(_ key: String) throws -> PublicRepositoryPath {
    try PublicRepositoryPath(collection: posts, recordKey: key)
  }

  private func record(_ text: String) -> PublicRecord {
    ["$type": .string(posts), "text": .string(text)]
  }

  private func wireOps(_ operations: [RepositoryCommitOperation]) -> [PublicFirehoseRepoOp] {
    operations.map { operation in
      switch operation {
      case let .create(path, cid):
        PublicFirehoseRepoOp(action: .create, path: path.mstKey, cid: cid.string, prev: nil)
      case let .update(path, cid, previous):
        PublicFirehoseRepoOp(action: .update, path: path.mstKey, cid: cid.string, prev: previous.string)
      case let .delete(path, previous):
        PublicFirehoseRepoOp(action: .delete, path: path.mstKey, cid: nil, prev: previous.string)
      }
    }
  }

  /// A repository with two records, then a commit that updates one, deletes the other and
  /// creates a third: every action on the wire.
  private func commitResult(signer: K256Keypair) async throws -> RepositoryCommitResult {
    let empty = try await Repository.create(
      did: did, signer: signer, revision: try PublicRepositoryTID.next(after: nil, now: signedAt - 120)
    )
    let first: [PublicRepositoryWrite] = [
      .create(path: try path("a"), record: record("a")),
      .create(path: try path("b"), record: record("b")),
    ]
    let base = try await empty.commit(
      first, signer: signer, revision: try PublicRepositoryTID.next(after: nil, now: signedAt - 60)
    ).repository
    let second: [PublicRepositoryWrite] = [
      .update(path: try path("a"), record: record("a2"), expectedRecordCID: nil),
      .delete(path: try path("b"), expectedRecordCID: nil),
      .create(path: try path("c"), record: record("c")),
    ]
    return try await base.commit(
      second, signer: signer, revision: try PublicRepositoryTID.next(after: nil, now: signedAt)
    )
  }

  private func decodedCommit(
    _ result: RepositoryCommitResult,
    operations: [RepositoryCommitOperation]? = nil,
    prevData: CID?? = .none
  ) async throws -> RelayCommitEvent {
    let previous: CID? = prevData ?? result.previousDataCID
    let material = PublicFirehoseCommitMaterial(
      did: did,
      rev: result.repository.commit.revision.value,
      since: result.since.value,
      commitCID: result.repository.commit.cid.string,
      prevDataCID: previous?.string,
      ops: wireOps(operations ?? result.operations),
      time: "2030-01-01T00:00:00.000Z"
    )
    let frame = try FirehoseFrameEncoder.commitFrame(
      seq: 7, material: material, diffCAR: try await result.diffCAR()
    )
    guard case let .commit(event) = try RelayFrameDecoder.decode(frame) else {
      Issue.record("not a #commit")
      throw CancellationError()
    }
    return event
  }

  @Test("a decoded #commit with create, update and delete verifies, and its records are the account's")
  func commitVerifies() async throws {
    let signer = K256Keypair.generate()
    let result = try await commitResult(signer: signer)
    let event = try await decodedCommit(result)
    let keys = FixedRepositorySigningKey(signer.publicKey)

    let verified = try await event.verify(keyResolver: keys, now: signedAt)
    #expect(verified.commit.commitCID == result.repository.commit.cid)
    #expect(verified.operations == result.operations)
    #expect(try event.repositoryOperations() == result.operations)
    let records = try event.records()
    #expect(records.count == 3)
  }

  @Test("a #commit that misstates what changed, or omits prevData, does not verify")
  func commitTampering() async throws {
    let signer = K256Keypair.generate()
    let result = try await commitResult(signer: signer)
    let keys = FixedRepositorySigningKey(signer.publicKey)

    // An operation left out: the inversion no longer reaches prevData.
    let partial = try await decodedCommit(result, operations: Array(result.operations.dropLast()))
    await #expect(throws: RepositoryCommitDiffError.self) {
      try await partial.verify(keyResolver: keys, now: self.signedAt)
    }

    // A prevData that is not the tree before the commit.
    let wrongPrev = try await decodedCommit(result, prevData: .some(result.repository.commit.dataCID))
    await #expect(throws: RepositoryCommitDiffError.self) {
      try await wrongPrev.verify(keyResolver: keys, now: self.signedAt)
    }

    // No prevData: pre-sync-1.1 events cannot be inverted.
    let legacy = try await decodedCommit(result, prevData: .some(nil))
    await #expect(throws: RepositoryCommitDiffError.missingPreviousData) {
      try await legacy.verify(keyResolver: keys, now: self.signedAt)
    }

    // Another account's key.
    let event = try await decodedCommit(result)
    await #expect(throws: RepositoryCommitDiffError.commit(.invalidSignature)) {
      try await event.verify(
        keyResolver: FixedRepositorySigningKey(K256Keypair.generate().publicKey), now: self.signedAt
      )
    }

    // A revision more than five minutes ahead of the consumer's clock.
    await #expect(throws: RepositoryCommitDiffError.revisionInFuture(revision: event.rev)) {
      try await event.verify(keyResolver: keys, now: self.signedAt - 3_600)
    }
  }

  @Test("an operation the wire form cannot express as a repository change is malformed")
  func malformedOperations() throws {
    let cid = try CID.parse("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
    let malformed: [RelayRepoOp] = [
      RelayRepoOp(action: .create, path: "\(posts)/a", cid: nil, prev: nil),
      RelayRepoOp(action: .update, path: "\(posts)/a", cid: cid, prev: nil),
      RelayRepoOp(action: .delete, path: "\(posts)/a", cid: nil, prev: nil),
      RelayRepoOp(action: .delete, path: "\(posts)/a", cid: cid, prev: cid),
      RelayRepoOp(action: .create, path: "not a path", cid: cid, prev: nil),
    ]
    for op in malformed {
      #expect(throws: RepositoryCommitDiffError.malformedOperation(path: op.path)) {
        _ = try op.repositoryOperation()
      }
    }
  }

  @Test("a decoded #sync verifies its commit, and refuses a future rev or another key")
  func syncVerifies() async throws {
    let signer = K256Keypair.generate()
    let result = try await commitResult(signer: signer)
    let commit = result.repository.commit
    let car = try await PublicFirehoseDiffCAR.commitOnly(commitCID: commit.cid, commitBytes: commit.bytes)
    let frame = try FirehoseFrameEncoder.syncFrame(
      seq: 8,
      material: PublicFirehoseSyncMaterial(
        did: did, rev: commit.revision.value, commitCID: commit.cid.string,
        time: "2030-01-01T00:00:00.000Z"
      ),
      commitCAR: car
    )
    guard case let .sync(event) = try RelayFrameDecoder.decode(frame) else {
      Issue.record("not a #sync")
      return
    }

    let verified = try await event.verify(
      keyResolver: FixedRepositorySigningKey(signer.publicKey), now: signedAt
    )
    #expect(verified.descriptor.dataCID == commit.dataCID)
    await #expect(throws: RepositoryCommitDiffError.revisionInFuture(revision: event.rev)) {
      try await event.verify(
        keyResolver: FixedRepositorySigningKey(signer.publicKey), now: self.signedAt - 3_600
      )
    }
    await #expect(throws: RepositoryCommitDiffError.commit(.invalidSignature)) {
      try await event.verify(
        keyResolver: FixedRepositorySigningKey(K256Keypair.generate().publicKey), now: self.signedAt
      )
    }
  }
}
