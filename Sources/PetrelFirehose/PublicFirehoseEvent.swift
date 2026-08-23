import Foundation

/// The durable event kind stored in outboxes and the global log. This is the
/// final kind, not an intermediate representation: a `.commit` row is never
/// reinterpreted as `.sync` by a later phase.
public enum PublicFirehoseEventKind: String, Codable, Sendable {
  case commit, sync, identity, account
}

public enum PublicFirehoseRepoAction: String, Codable, Sendable {
  case create, update, delete
}

/// One repository mutation op as it appears on the firehose wire. CIDs stay
/// strings here; SQLite rows must not depend on Petrel binary layout.
public struct PublicFirehoseRepoOp: Codable, Sendable, Equatable {
  public let action: PublicFirehoseRepoAction
  public let path: String
  public let cid: String?
  public let prev: String?

  public init(action: PublicFirehoseRepoAction, path: String, cid: String?, prev: String?) {
    self.action = action
    self.path = path
    self.cid = cid
    self.prev = prev
  }
}

/// Durable material for a `#commit` event. `since` is optional and encoded as
/// CBOR null when absent; `prevDataCID` is omitted from the wire when absent.
public struct PublicFirehoseCommitMaterial: Codable, Sendable, Equatable {
  public let did: String
  public let rev: String
  public let since: String?
  public let commitCID: String
  public let prevDataCID: String?
  public let ops: [PublicFirehoseRepoOp]
  public let time: String

  public init(
    did: String,
    rev: String,
    since: String?,
    commitCID: String,
    prevDataCID: String?,
    ops: [PublicFirehoseRepoOp],
    time: String
  ) {
    self.did = did
    self.rev = rev
    self.since = since
    self.commitCID = commitCID
    self.prevDataCID = prevDataCID
    self.ops = ops
    self.time = time
  }
}

/// Durable material for a `#sync` event.
public struct PublicFirehoseSyncMaterial: Codable, Sendable, Equatable {
  public let did: String
  public let rev: String
  public let commitCID: String
  public let time: String

  public init(did: String, rev: String, commitCID: String, time: String) {
    self.did = did
    self.rev = rev
    self.commitCID = commitCID
    self.time = time
  }
}

/// Durable material for an `#identity` event. `handle` is captured from the
/// confirmed lifecycle operation at enqueue time, never from the mutable
/// account record at sequencing time.
public struct PublicFirehoseIdentityMaterial: Codable, Sendable, Equatable {
  public let did: String
  public let handle: String?
  public let time: String

  public init(did: String, handle: String?, time: String) {
    self.did = did
    self.handle = handle
    self.time = time
  }
}

/// Externally visible account statuses. Internal states (`deleting`,
/// `unknown`, `active`) are never encoded as status strings.
public enum PublicFirehoseAccountStatus: String, Codable, Sendable {
  case deactivated
  case suspended
  case takendown
  case desynchronized
  case throttled
  case deleted
}

/// Durable material for an `#account` event. Active events use
/// `active: true, status: nil`.
public struct PublicFirehoseAccountMaterial: Codable, Sendable, Equatable {
  public let did: String
  public let active: Bool
  public let status: PublicFirehoseAccountStatus?
  public let time: String

  public init(did: String, active: Bool, status: PublicFirehoseAccountStatus?, time: String) {
    self.did = did
    self.active = active
    self.status = status
    self.time = time
  }
}
