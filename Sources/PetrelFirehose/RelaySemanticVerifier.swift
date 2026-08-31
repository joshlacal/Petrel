import Foundation
import Petrel
import PetrelRepo

public enum RelaySequenceVerifier {
  public static func verify(
    events: [RelayEvent],
    reconnects: [RelayReconnectEvidence],
    offlineCommitRange: ClosedRange<Int64>? = nil,
    expectedOfflineCommitCount: Int = 5
  ) throws -> RelaySequenceVerification {
    let sequenced = events.compactMap { event -> (Int64, RelayEvent)? in
      event.sequence.map { ($0, event) }
    }
    guard let first = sequenced.first, let last = sequenced.last else {
      throw RelayVerifierError.invalidEventBody
    }
    var previous: Int64?
    var seen = Set<Int64>()
    for (sequence, _) in sequenced {
      guard seen.insert(sequence).inserted else {
        throw RelayVerifierError.duplicateSequence
      }
      if let previous, sequence != previous + 1 {
        throw RelayVerifierError.sequenceGap
      }
      previous = sequence
    }
    for reconnect in reconnects {
      guard reconnect.upstreamCursor >= 0,
            reconnect.upstreamCursor <= FirehoseFrameLimits.maximumSequence,
            seen.contains(reconnect.firstDeliveredRelaySequence) else {
        throw RelayVerifierError.reconnectCursorOutOfBounds
      }
    }
    let offlineCount: Int
    if let range = offlineCommitRange {
      let ranged = sequenced.filter { range.contains($0.0) }
      offlineCount = ranged.filter {
        if case .commit = $0.1 { return true }
        return false
      }.count
      guard ranged.count == range.count,
            offlineCount == expectedOfflineCommitCount else {
        throw RelayVerifierError.offlineCommitCountMismatch
      }
      guard reconnects.contains(where: {
        $0.firstDeliveredRelaySequence == range.lowerBound
      }) else {
        throw RelayVerifierError.reconnectCursorOutOfBounds
      }
    } else {
      offlineCount = 0
    }
    return .init(
      firstSequence: first.0,
      lastSequence: last.0,
      offlineCommitCount: offlineCount
    )
  }
}

public enum RelayLifecycleVerifier {
  public static func verify(
    events: [RelayEvent],
    expectedDID: String? = nil
  ) throws {
    enum Stage: Equatable { case initial, identity, account, synchronized }
    var stage = Stage.initial
    var did = expectedDID
    for event in events {
      guard let eventDID = event.repositoryDID else { continue }
      if let did {
        guard did == eventDID else { throw RelayVerifierError.repositoryDIDMismatch }
      } else {
        did = eventDID
      }
      switch (stage, event) {
      case (.initial, .identity): stage = .identity
      case (.identity, let .account(account)) where account.active && account.status == nil:
        stage = .account
      case (.account, .sync): stage = .synchronized
      case (.synchronized, .identity), (.synchronized, .account),
           (.synchronized, .sync), (.synchronized, .commit):
        break
      default:
        throw RelayVerifierError.lifecycleOrderMismatch
      }
    }
    guard stage == .synchronized else {
      throw RelayVerifierError.lifecycleOrderMismatch
    }
  }
}

public enum RelayCommitSemanticVerifier {
  public static func verify(
    event: RelayCommitEvent,
    previous: RelayRepositorySnapshot,
    current: RelayRepositorySnapshot
  ) throws {
    guard event.repo == previous.did, event.repo == current.did else {
      throw RelayVerifierError.repositoryDIDMismatch
    }
    guard event.rev == current.revision else {
      throw RelayVerifierError.commitRevisionMismatch
    }
    guard event.commitCID == current.commitCID else {
      throw RelayVerifierError.commitCIDMismatch
    }
    guard event.since == previous.revision else {
      throw RelayVerifierError.sinceRevisionMismatch
    }
    guard event.prevDataCID == previous.dataCID else {
      throw RelayVerifierError.previousDataCIDMismatch
    }
    guard let previousTID = try? PublicRepositoryTID(previous.revision),
          let currentTID = try? PublicRepositoryTID(current.revision),
          previousTID < currentTID else {
      throw RelayVerifierError.revisionRollback
    }
    let expected = try expectedDelta(previous: previous.records, current: current.records)
    guard event.ops == expected else {
      throw RelayVerifierError.repositoryDeltaMismatch
    }
  }

  private static func expectedDelta(
    previous: [String: CID],
    current: [String: CID]
  ) throws -> [RelayRepoOp] {
    try Set(previous.keys).union(current.keys).sorted().compactMap { path in
      _ = try validatePath(path)
      switch (previous[path], current[path]) {
      case (nil, let current?):
        return .init(action: .create, path: path, cid: current, prev: nil)
      case (let previous?, nil):
        return .init(action: .delete, path: path, cid: nil, prev: previous)
      case (let previous?, let current?) where previous != current:
        return .init(action: .update, path: path, cid: current, prev: previous)
      default:
        return nil
      }
    }
  }

  private static func validatePath(_ value: String) throws -> PublicRepositoryPath {
    guard let slash = value.firstIndex(of: "/") else {
      throw RelayVerifierError.repositoryDeltaMismatch
    }
    do {
      return try PublicRepositoryPath(
        collection: String(value[..<slash]),
        recordKey: String(value[value.index(after: slash)...])
      )
    } catch {
      throw RelayVerifierError.repositoryDeltaMismatch
    }
  }
}

public enum RelayGetRepoPolicy {
  public static func verify(
    _ observation: RelayGetRepoObservation
  ) throws -> RelayGetRepoQueryMode {
    switch observation.mode {
    case .cursorOnly, .sinceRejected:
      return observation.mode
    case .sinceObserved:
      guard observation.fullSnapshotAccepted,
            observation.exactFinalStateProven else {
        throw RelayVerifierError.sinceObservedNotProven
      }
      return .sinceObserved
    }
  }
}

public enum RelayFinalStateVerifier {
  public static func verify(
    relay: RelayRepositorySnapshot,
    swan: RelayRepositorySnapshot
  ) throws {
    guard relay.did == swan.did else { throw RelayVerifierError.repositoryDIDMismatch }
    guard relay.revision == swan.revision else {
      throw RelayVerifierError.finalRevisionMismatch
    }
    guard relay.commitCID == swan.commitCID else {
      throw RelayVerifierError.finalCommitCIDMismatch
    }
    guard relay.dataCID == swan.dataCID else {
      throw RelayVerifierError.finalDataCIDMismatch
    }
    guard relay.records == swan.records else {
      throw RelayVerifierError.finalProjectionMismatch
    }
    guard relay.mstDigest == swan.mstDigest else {
      throw RelayVerifierError.finalMSTMismatch
    }
  }
}

private extension ClosedRange where Bound == Int64 {
  var count: Int {
    let (distance, overflow) = upperBound.subtractingReportingOverflow(lowerBound)
    guard !overflow, distance < Int64(Int.max) else { return Int.max }
    return Int(distance) + 1
  }
}
