import Foundation
import Petrel

public enum RelayVerifierError: String, Error, Sendable, Equatable, Codable {
  case truncatedFrame
  case invalidCBOR
  case nonCanonicalCBOR
  case invalidCIDLink
  case trailingFrameBytes
  case frameTooLarge
  case invalidFrameHeader
  case unknownEventKind
  case invalidEventBody
  case sequenceOutOfRange
  case commitBlocksTooLarge
  case syncBlocksTooLarge
  case tooManyOperations
  case invalidRepositoryOperation
  case invalidAccountStatus
  case duplicateSequence
  case sequenceGap
  case reconnectCursorOutOfBounds
  case offlineCommitCountMismatch
  case lifecycleOrderMismatch
  case repositoryDIDMismatch
  case commitRevisionMismatch
  case commitCIDMismatch
  case sinceRevisionMismatch
  case previousDataCIDMismatch
  case repositoryDeltaMismatch
  case sinceObservedNotProven
  case repositoryCARTooLarge
  case invalidRepositoryCAR
  case invalidCommitSignature
  case finalRevisionMismatch
  case finalCommitCIDMismatch
  case finalDataCIDMismatch
  case finalProjectionMismatch
  case finalMSTMismatch
  case invalidCaptureManifest
  case missingFinalRepository
}

public enum RelayRepoAction: String, Sendable, Equatable, Codable {
  case create
  case update
  case delete
}

public struct RelayRepoOp: Sendable, Equatable {
  public let action: RelayRepoAction
  public let path: String
  public let cid: CID?
  public let prev: CID?

  public init(action: RelayRepoAction, path: String, cid: CID?, prev: CID?) {
    self.action = action
    self.path = path
    self.cid = cid
    self.prev = prev
  }
}

public struct RelayIdentityEvent: Sendable, Equatable {
  public let seq: Int64
  public let did: String
  public let time: String
  public let handle: String?

  public init(seq: Int64, did: String, time: String, handle: String?) {
    self.seq = seq
    self.did = did
    self.time = time
    self.handle = handle
  }
}

public struct RelayAccountEvent: Sendable, Equatable {
  public let seq: Int64
  public let did: String
  public let time: String
  public let active: Bool
  public let status: String?

  public init(seq: Int64, did: String, time: String, active: Bool, status: String?) {
    self.seq = seq
    self.did = did
    self.time = time
    self.active = active
    self.status = status
  }
}

public struct RelaySyncEvent: Sendable, Equatable {
  public let seq: Int64
  public let did: String
  public let blocks: Data
  public let rev: String
  public let time: String

  public init(seq: Int64, did: String, blocks: Data, rev: String, time: String) {
    self.seq = seq
    self.did = did
    self.blocks = blocks
    self.rev = rev
    self.time = time
  }
}

public struct RelayCommitEvent: Sendable, Equatable {
  public let seq: Int64
  public let repo: String
  public let commitCID: CID
  public let rev: String
  public let since: String?
  public let blocks: Data
  public let ops: [RelayRepoOp]
  public let prevDataCID: CID?
  public let time: String

  public init(
    seq: Int64,
    repo: String,
    commitCID: CID,
    rev: String,
    since: String?,
    blocks: Data,
    ops: [RelayRepoOp],
    prevDataCID: CID?,
    time: String
  ) {
    self.seq = seq
    self.repo = repo
    self.commitCID = commitCID
    self.rev = rev
    self.since = since
    self.blocks = blocks
    self.ops = ops
    self.prevDataCID = prevDataCID
    self.time = time
  }
}

public struct RelayInfoEvent: Sendable, Equatable {
  public let name: String
  public let message: String?

  public init(name: String, message: String?) {
    self.name = name
    self.message = message
  }
}

public struct RelayErrorEvent: Sendable, Equatable {
  public let error: String
  public let message: String?

  public init(error: String, message: String?) {
    self.error = error
    self.message = message
  }
}

public enum RelayEvent: Sendable, Equatable {
  case identity(RelayIdentityEvent)
  case account(RelayAccountEvent)
  case sync(RelaySyncEvent)
  case commit(RelayCommitEvent)
  case info(RelayInfoEvent)
  case error(RelayErrorEvent)

  public var sequence: Int64? {
    switch self {
    case let .identity(event): event.seq
    case let .account(event): event.seq
    case let .sync(event): event.seq
    case let .commit(event): event.seq
    case .info, .error: nil
    }
  }

  public var repositoryDID: String? {
    switch self {
    case let .identity(event): event.did
    case let .account(event): event.did
    case let .sync(event): event.did
    case let .commit(event): event.repo
    case .info, .error: nil
    }
  }
}

public struct RelayReconnectEvidence: Sendable, Equatable, Codable {
  public let upstreamCursor: Int64
  public let firstDeliveredRelaySequence: Int64

  public init(upstreamCursor: Int64, firstDeliveredRelaySequence: Int64) {
    self.upstreamCursor = upstreamCursor
    self.firstDeliveredRelaySequence = firstDeliveredRelaySequence
  }
}

public struct RelaySequenceVerification: Sendable, Equatable {
  public let firstSequence: Int64
  public let lastSequence: Int64
  public let offlineCommitCount: Int

  public init(firstSequence: Int64, lastSequence: Int64, offlineCommitCount: Int) {
    self.firstSequence = firstSequence
    self.lastSequence = lastSequence
    self.offlineCommitCount = offlineCommitCount
  }
}

public struct RelayRepositoryHead: Sendable, Equatable {
  public let did: String
  public let revision: String
  public let commitCID: CID
  public let dataCID: CID

  public init(did: String, revision: String, commitCID: CID, dataCID: CID) {
    self.did = did
    self.revision = revision
    self.commitCID = commitCID
    self.dataCID = dataCID
  }
}

public struct RelayRepositorySnapshot: Sendable, Equatable {
  public let did: String
  public let revision: String
  public let commitCID: CID
  public let dataCID: CID
  public let records: [String: CID]
  public let mstDigest: String

  public init(
    did: String,
    revision: String,
    commitCID: CID,
    dataCID: CID,
    records: [String: CID],
    mstDigest: String
  ) {
    self.did = did
    self.revision = revision
    self.commitCID = commitCID
    self.dataCID = dataCID
    self.records = records
    self.mstDigest = mstDigest
  }

  public var head: RelayRepositoryHead {
    .init(did: did, revision: revision, commitCID: commitCID, dataCID: dataCID)
  }
}

public enum RelayRepositoryPayloadKind: String, Sendable, Equatable, Codable {
  case fullSnapshot
  case commitDiff
  case commitAnnouncement

  public var isDiff: Bool { self == .commitDiff }
}

public enum RelayGetRepoQueryMode: String, Sendable, Equatable, Codable {
  case cursorOnly = "cursor-only"
  case sinceRejected = "since-rejected"
  case sinceObserved = "since-observed"
}

public struct RelayGetRepoObservation: Sendable, Equatable, Codable {
  public let mode: RelayGetRepoQueryMode
  public let fullSnapshotAccepted: Bool
  public let exactFinalStateProven: Bool

  public init(
    mode: RelayGetRepoQueryMode,
    fullSnapshotAccepted: Bool = false,
    exactFinalStateProven: Bool = false
  ) {
    self.mode = mode
    self.fullSnapshotAccepted = fullSnapshotAccepted
    self.exactFinalStateProven = exactFinalStateProven
  }
}

public enum RelayVerificationCheckName: String, Sendable, Equatable, Codable {
  case canonicalFrames = "canonical_frames"
  case orderedLifecycle = "ordered_lifecycle"
  case cursorRecovery = "cursor_recovery"
  case repositoryCommits = "repository_commits"
  case getRepoMode = "get_repo_mode"
  case finalMSTEquality = "final_mst_equality"
}

public enum RelayVerificationCheckOutcome: String, Sendable, Equatable, Codable {
  case passed
  case failed
}

public struct RelayNamedCheck: Sendable, Equatable, Codable {
  public let name: RelayVerificationCheckName
  public let outcome: RelayVerificationCheckOutcome

  public init(name: RelayVerificationCheckName, outcome: RelayVerificationCheckOutcome) {
    self.name = name
    self.outcome = outcome
  }
}

public struct RelayVerificationAggregate: Sendable, Equatable, Codable {
  public let did: String
  public let firstSequence: Int64
  public let lastSequence: Int64
  public let frameCount: Int
  public let finalRevision: String
  public let finalCommitCID: String
  public let finalDataCID: String
  public let projectionDigest: String
  public let checks: [RelayNamedCheck]

  public init(
    did: String,
    firstSequence: Int64,
    lastSequence: Int64,
    frameCount: Int,
    finalRevision: String,
    finalCommitCID: String,
    finalDataCID: String,
    projectionDigest: String,
    checks: [RelayNamedCheck]
  ) {
    self.did = did
    self.firstSequence = firstSequence
    self.lastSequence = lastSequence
    self.frameCount = frameCount
    self.finalRevision = finalRevision
    self.finalCommitCID = finalCommitCID
    self.finalDataCID = finalDataCID
    self.projectionDigest = projectionDigest
    self.checks = checks
  }
}
