import Foundation
import Petrel
import PetrelRepo

public extension RelayRepoOp {
  /// This operation in the form `RepositoryCommitDiff` checks.
  ///
  /// - Parameter keySyntax: How strictly `path` is parsed. `.repositoryPath`, the default,
  ///   requires a collection NSID and a record key, as every repository does.
  /// - Throws: `RepositoryCommitDiffError/malformedOperation(path:)` when the path does not
  ///   parse, a create or update has no `cid`, or an update or delete has no `prev`.
  func repositoryOperation(
    keySyntax: RepositoryMSTKeySyntax = .repositoryPath
  ) throws -> RepositoryCommitOperation {
    let parsed: PublicRepositoryPath
    do {
      parsed = try PublicRepositoryPath(mstKey: path, syntax: keySyntax)
    } catch {
      throw RepositoryCommitDiffError.malformedOperation(path: path)
    }
    switch (action, cid, prev) {
    case let (.create, cid?, _):
      return .create(path: parsed, cid: cid)
    case let (.update, cid?, previous?):
      return .update(path: parsed, cid: cid, previous: previous)
    case let (.delete, nil, previous?):
      return .delete(path: parsed, previous: previous)
    default:
      throw RepositoryCommitDiffError.malformedOperation(path: path)
    }
  }
}

public extension RelayCommitEvent {
  /// The event's operations in the form `RepositoryCommitDiff` checks.
  ///
  /// - Parameter keySyntax: How strictly each path is parsed.
  /// - Throws: `RepositoryCommitDiffError/malformedOperation(path:)`.
  func repositoryOperations(
    keySyntax: RepositoryMSTKeySyntax = .repositoryPath
  ) throws -> [RepositoryCommitOperation] {
    try ops.map { try $0.repositoryOperation(keySyntax: keySyntax) }
  }

  /// Verifies this `#commit` event from its own fields, as the sync specification asks a
  /// consumer to before it trusts the operations.
  ///
  /// This is
  /// `RepositoryCommitDiff/verifyCommitEvent(blocks:commitCID:did:revision:operations:previousDataCID:keyResolver:limits:policy:now:maximumClockSkew:)`
  /// applied to the event: the revision is not in the future, the commit in `blocks` is signed
  /// by the key `keyResolver` returns for `repo` (with one refresh on failure), its revision is
  /// `rev`, the operations invert the new tree to `prevData`, and every created or updated
  /// record block is present and matches its CID. A verified event's ``RelayCommitEvent/records()`` are
  /// authentic.
  ///
  /// - Parameters:
  ///   - keyResolver: Looks up the account's signing key. For a live firehose, a
  ///     `CachingServiceAuthKeyResolver` over `IdentityResolver`.
  ///   - limits: Bounds on the operations, the archive, the tree and record size.
  ///   - policy: How strictly record content is checked.
  ///   - now: The consumer's current time.
  ///   - maximumClockSkew: How far ahead of `now` the revision may be, in seconds.
  /// - Throws: `RepositoryCommitDiffError`; `RepositoryCommitDiffError/missingPreviousData`
  ///   for an event without `prevData`.
  @discardableResult
  func verify(
    keyResolver: any RepositorySigningKeyResolver,
    limits: PublicRepositoryLimits = .standard,
    policy: RepositoryReadPolicy = .dataModel,
    now: Date = Date(),
    maximumClockSkew: TimeInterval = 300
  ) async throws -> VerifiedRepositoryCommitDiff {
    guard let prevDataCID else {
      throw RepositoryCommitDiffError.missingPreviousData
    }
    return try await RepositoryCommitDiff.verifyCommitEvent(
      blocks: blocks,
      commitCID: commitCID,
      did: repo,
      revision: rev,
      operations: try repositoryOperations(),
      previousDataCID: prevDataCID,
      keyResolver: keyResolver,
      limits: limits,
      policy: policy,
      now: now,
      maximumClockSkew: maximumClockSkew
    )
  }
}

public extension RelaySyncEvent {
  /// Verifies this `#sync` event: the commit in `blocks` is signed by the key `keyResolver`
  /// returns for `did`, its revision is `rev`, and `rev` is not in the future.
  ///
  /// This is
  /// `RepositoryCommitDiff/verifySyncEvent(blocks:did:revision:keyResolver:limits:now:maximumClockSkew:)`
  /// applied to the event. The returned commit's data CID is the tree root to fetch.
  ///
  /// - Parameters:
  ///   - keyResolver: Looks up the account's signing key.
  ///   - limits: Bounds on the archive.
  ///   - now: The consumer's current time.
  ///   - maximumClockSkew: How far ahead of `now` the revision may be, in seconds.
  /// - Throws: `RepositoryCommitDiffError`.
  @discardableResult
  func verify(
    keyResolver: any RepositorySigningKeyResolver,
    limits: PublicRepositoryLimits = .standard,
    now: Date = Date(),
    maximumClockSkew: TimeInterval = 300
  ) async throws -> VerifiedPublicRepositorySignedCommit {
    try await RepositoryCommitDiff.verifySyncEvent(
      blocks: blocks,
      did: did,
      revision: rev,
      keyResolver: keyResolver,
      limits: limits,
      now: now,
      maximumClockSkew: maximumClockSkew
    )
  }
}
