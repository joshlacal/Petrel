import Foundation
import Petrel
import PetrelRepo

/// Storage interface for persisting and loading verified accepted repository heads by DID.
///
/// Implementations must enforce monotonic compare-and-set semantics:
/// When persisting a head for a given DID, any existing persisted head revision must be parsed
/// as `PublicRepositoryTID`. If an existing head exists, the incoming head revision must be
/// strictly greater than the stored revision (`existingTID < incomingTID`), or equal with
/// identical head properties for idempotent re-announcement. Stale or conflicting writes must
/// throw `RelayVerifierError.revisionRollback`.
public protocol RelayAcceptedHeadStorage: Sendable {
  func loadAcceptedHead(for did: String) async throws -> RelayRepositoryHead?
  func saveAcceptedHead(_ head: RelayRepositoryHead) async throws
}

public actor InMemoryRelayAcceptedHeadStorage: RelayAcceptedHeadStorage {
  private var heads: [String: RelayRepositoryHead]

  public init(initialHeads: [String: RelayRepositoryHead] = [:]) {
    self.heads = initialHeads
  }

  public func loadAcceptedHead(for did: String) async throws -> RelayRepositoryHead? {
    heads[did]
  }

  public func saveAcceptedHead(_ head: RelayRepositoryHead) async throws {
    if let existing = heads[head.did] {
      let existingTID = try PublicRepositoryTID(existing.revision)
      let incomingTID = try PublicRepositoryTID(head.revision)
      if incomingTID < existingTID {
        throw RelayVerifierError.revisionRollback
      }
      if incomingTID == existingTID {
        guard existing == head else {
          throw RelayVerifierError.revisionRollback
        }
      }
    }
    heads[head.did] = head
  }
}
