import Foundation
import Petrel
import PetrelFirehose

/// One record mutation from the Jetstream v2 stream or archive.
public struct JetstreamCommitEvent: Sendable {
  /// Jetstream's monotonic per-event sequence number; the stream cursor.
  public let seq: Int64
  public let did: String
  /// Display timestamp, unix microseconds.
  public let timeUS: Int64
  /// Repo rev of the commit that produced this op.
  public let rev: String
  public let operation: RelayRepoAction
  public let collection: String
  public let rkey: String
  /// CID of the record; absent for deletes and for archive rows.
  public let cid: String?
  /// Raw JSON bytes of the record; nil on deletes or when record decoding
  /// from an archive payload failed.
  public let recordJSON: Data?

  public init(
    seq: Int64, did: String, timeUS: Int64, rev: String, operation: RelayRepoAction,
    collection: String, rkey: String, cid: String? = nil, recordJSON: Data? = nil
  ) {
    self.seq = seq
    self.did = did
    self.timeUS = timeUS
    self.rev = rev
    self.operation = operation
    self.collection = collection
    self.rkey = rkey
    self.cid = cid
    self.recordJSON = recordJSON
  }

  /// Decode `recordJSON` into Petrel's dynamic record container.
  public func decodedRecord() -> ATProtocolValueContainer? {
    guard let recordJSON else { return nil }
    return try? JSONCoders.decode(ATProtocolValueContainer.self, from: recordJSON)
  }
}

public struct JetstreamIdentityEvent: Sendable {
  public let seq: Int64
  public let did: String
  public let timeUS: Int64
  /// Wrapped upstream event; nil when its decode failed (envelope fields remain valid).
  public let identity: ComAtprotoSyncSubscribeRepos.Identity?

  public init(seq: Int64, did: String, timeUS: Int64, identity: ComAtprotoSyncSubscribeRepos.Identity?) {
    self.seq = seq
    self.did = did
    self.timeUS = timeUS
    self.identity = identity
  }
}

public struct JetstreamAccountEvent: Sendable {
  public let seq: Int64
  public let did: String
  public let timeUS: Int64
  public let account: ComAtprotoSyncSubscribeRepos.Account?

  public init(seq: Int64, did: String, timeUS: Int64, account: ComAtprotoSyncSubscribeRepos.Account?) {
    self.seq = seq
    self.did = did
    self.timeUS = timeUS
    self.account = account
  }
}

public struct JetstreamSyncEvent: Sendable {
  public let seq: Int64
  public let did: String
  public let timeUS: Int64
  public let sync: ComAtprotoSyncSubscribeRepos.Sync?

  public init(seq: Int64, did: String, timeUS: Int64, sync: ComAtprotoSyncSubscribeRepos.Sync?) {
    self.seq = seq
    self.did = did
    self.timeUS = timeUS
    self.sync = sync
  }
}

/// Advisory, non-fatal notice; carries no seq and does not advance the cursor.
public struct JetstreamInfoEvent: Sendable {
  public let name: String
  public let message: String?

  public init(name: String, message: String? = nil) {
    self.name = name
    self.message = message
  }
}

public enum JetstreamEvent: Sendable {
  case commit(JetstreamCommitEvent)
  case identity(JetstreamIdentityEvent)
  case account(JetstreamAccountEvent)
  case sync(JetstreamSyncEvent)
  case info(JetstreamInfoEvent)

  public var seq: Int64? {
    switch self {
    case let .commit(e): return e.seq
    case let .identity(e): return e.seq
    case let .account(e): return e.seq
    case let .sync(e): return e.seq
    case .info: return nil
    }
  }

  public var did: String? {
    switch self {
    case let .commit(e): return e.did
    case let .identity(e): return e.did
    case let .account(e): return e.did
    case let .sync(e): return e.did
    case .info: return nil
    }
  }
}

/// Event kinds; raw values are the wire filter values and message `$type`
/// fragment names.
public enum JetstreamKind: String, Sendable, Equatable, CaseIterable {
  case commit
  case identity
  case account
  case sync
}

/// The independent, ANDed filter predicates of subscribeEvents/planSnapshot.
/// Each dimension is match-all when empty.
public struct JetstreamFilter: Sendable, Equatable {
  public var kinds: [JetstreamKind]
  public var dids: [String]
  /// Collection NSIDs or `<prefix>.*` wildcards; constrains commit events ONLY.
  public var collections: [String]

  public init(
    kinds: [JetstreamKind] = [], dids: [String] = [], collections: [String] = []
  ) {
    self.kinds = kinds
    self.dids = dids
    self.collections = collections
  }

  /// Exact predicate re-applied to decoded rows (the server planner is
  /// one-sided and may over-select). `collections` never drops non-commit
  /// events; excluding markers is exclusively `kinds`' job. `.info` frames
  /// always pass.
  public func matches(_ event: JetstreamEvent) -> Bool {
    let kind: JetstreamKind
    switch event {
    case .info:
      return true
    case .commit: kind = .commit
    case .identity: kind = .identity
    case .account: kind = .account
    case .sync: kind = .sync
    }
    if !kinds.isEmpty, !kinds.contains(kind) { return false }
    if !dids.isEmpty, let did = event.did, !dids.contains(did) { return false }
    if case let .commit(commit) = event, !collections.isEmpty {
      if !collections.contains(where: { Self.collectionMatches(pattern: $0, collection: commit.collection) }) {
        return false
      }
    }
    return true
  }

  static func collectionMatches(pattern: String, collection: String) -> Bool {
    if pattern.hasSuffix(".*") {
      return collection.hasPrefix(pattern.dropLast(1))  // keep the trailing "."
    }
    return pattern == collection
  }
}
