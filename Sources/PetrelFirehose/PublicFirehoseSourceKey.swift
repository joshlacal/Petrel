import Foundation

/// Purpose-specific source keys make replay exact: the same repository head
/// can legitimately produce more than one event over time, and the same key
/// with different kind, generation, payload, CAR, DID, batch, or encoded
/// frame is corruption, not idempotency.
///
/// Formats:
///
/// ```text
/// <did>|commit|<cid>
/// <did>|sync|oversize|<cid>
/// <did>|sync|manual|<lowercase UUID>
/// <did>|sync|activation|<operation ID>
/// <did>|sync|reactivation|<operation ID>
/// <did>|account|<operation ID>
/// <did>|identity|<PLC operation CID>
/// <did>|lifecycle|<operation ID>
/// ```
public enum PublicFirehoseSourceKey {
  public static func commit(did: String, commitCID: String) -> String {
    "\(did)|commit|\(commitCID)"
  }

  public static func syncOversize(did: String, commitCID: String) -> String {
    "\(did)|sync|oversize|\(commitCID)"
  }

  public static func syncManual(did: String, requestUUID: String) -> String {
    "\(did)|sync|manual|\(requestUUID.lowercased())"
  }

  public static func syncActivation(did: String, operationID: String) -> String {
    "\(did)|sync|activation|\(operationID)"
  }

  public static func syncReactivation(did: String, operationID: String) -> String {
    "\(did)|sync|reactivation|\(operationID)"
  }

  public static func account(did: String, operationID: String) -> String {
    "\(did)|account|\(operationID)"
  }

  public static func identity(did: String, plcOperationCID: String) -> String {
    "\(did)|identity|\(plcOperationCID)"
  }

  /// Batch IDs are not raw operation IDs: namespacing by DID prevents two
  /// accounts from colliding on the same external operation identifier.
  public static func lifecycleBatch(did: String, operationID: String) -> String {
    "\(did)|lifecycle|\(operationID)"
  }
}

public enum PublicFirehoseTimeError: Error, Equatable, Sendable {
  case outOfRange
}

public enum PublicFirehoseTime {
  /// UTC ISO-8601 with millisecond fractional seconds, for example
  /// `2026-08-04T12:00:00.000Z`.
  public static func encode(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utcTimeZone
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second, .nanosecond],
      from: date
    )
    let millis = (components.nanosecond ?? 0) / 1_000_000
    return String(
      format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0,
      components.hour ?? 0,
      components.minute ?? 0,
      components.second ?? 0,
      millis
    )
  }

  /// Whole microseconds since the Unix epoch. Rejects non-finite, negative,
  /// or overflowing values with `.outOfRange` rather than trapping on
  /// conversion.
  public static func microseconds(_ date: Date) throws -> Int64 {
    guard date.timeIntervalSince1970.isFinite else { throw PublicFirehoseTimeError.outOfRange }
    let seconds = date.timeIntervalSince1970
    guard seconds >= 0 else { throw PublicFirehoseTimeError.outOfRange }
    let micros = seconds * 1_000_000
    guard micros <= Double(Int64.max) else { throw PublicFirehoseTimeError.outOfRange }
    return Int64(micros.rounded(.towardZero))
  }

  private static let utcTimeZone = TimeZone(identifier: "UTC")!
}
