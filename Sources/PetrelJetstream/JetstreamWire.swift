import Foundation
import Petrel
import PetrelFirehose

/// One decoded xrpc.v1.json websocket frame.
enum JetstreamWireFrame {
  case message(JetstreamEvent)
  case error(name: String, message: String?)
  /// A structurally valid frame we don't understand (unknown payload `$type`);
  /// skipped for forward compatibility with additive lexicon changes.
  case skipped
}

enum JetstreamWireError: Error, Sendable, Equatable {
  case malformedFrame(String)
}

/// Decoder for proposal-0015 JSON frames:
/// `{"$type":"message","payload":{...}}` / `{"$type":"error","error":...,"message":...}`.
enum JetstreamWire {
  private static let payloadTypePrefix = "network.bsky.jetstream.subscribeEvents#"

  static func decodeFrame(_ data: Data) throws -> JetstreamWireFrame {
    let root: [String: Any]
    do {
      guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw JetstreamWireError.malformedFrame("frame is not a JSON object")
      }
      root = obj
    } catch let error as JetstreamWireError {
      throw error
    } catch {
      throw JetstreamWireError.malformedFrame("invalid JSON: \(error)")
    }

    switch root["$type"] as? String {
    case "message":
      guard let payload = root["payload"] as? [String: Any] else {
        throw JetstreamWireError.malformedFrame("message frame without payload object")
      }
      return decodePayload(payload)
    case "error":
      guard let name = root["error"] as? String else {
        throw JetstreamWireError.malformedFrame("error frame without error name")
      }
      return .error(name: name, message: root["message"] as? String)
    default:
      // Unknown envelope $type: additive framing change; skip.
      return .skipped
    }
  }

  private static func decodePayload(_ payload: [String: Any]) -> JetstreamWireFrame {
    guard let type = payload["$type"] as? String, type.hasPrefix(payloadTypePrefix) else {
      return .skipped
    }
    switch type.dropFirst(payloadTypePrefix.count) {
    case "commit":
      guard let event = decodeCommit(payload) else { return .skipped }
      return .message(.commit(event))
    case "identity":
      guard let (seq, did, timeUS) = envelope(payload) else { return .skipped }
      return .message(.identity(JetstreamIdentityEvent(
        seq: seq, did: did, timeUS: timeUS,
        identity: decodeDetail(ComAtprotoSyncSubscribeRepos.Identity.self, payload["identity"])
      )))
    case "account":
      guard let (seq, did, timeUS) = envelope(payload) else { return .skipped }
      return .message(.account(JetstreamAccountEvent(
        seq: seq, did: did, timeUS: timeUS,
        account: decodeDetail(ComAtprotoSyncSubscribeRepos.Account.self, payload["account"])
      )))
    case "sync":
      guard let (seq, did, timeUS) = envelope(payload) else { return .skipped }
      return .message(.sync(JetstreamSyncEvent(
        seq: seq, did: did, timeUS: timeUS,
        sync: decodeDetail(ComAtprotoSyncSubscribeRepos.Sync.self, payload["sync"])
      )))
    case "info":
      guard let name = payload["name"] as? String else { return .skipped }
      return .message(.info(JetstreamInfoEvent(name: name, message: payload["message"] as? String)))
    default:
      return .skipped
    }
  }

  private static func decodeCommit(_ payload: [String: Any]) -> JetstreamCommitEvent? {
    guard let (seq, did, timeUS) = envelope(payload),
          let rev = payload["rev"] as? String,
          let operationRaw = payload["operation"] as? String,
          let operation = RelayRepoAction(rawValue: operationRaw),
          let collection = payload["collection"] as? String,
          let rkey = payload["rkey"] as? String
    else { return nil }

    var recordJSON: Data?
    if let record = payload["record"], JSONSerialization.isValidJSONObject(record) {
      recordJSON = try? JSONSerialization.data(withJSONObject: record)
    }
    return JetstreamCommitEvent(
      seq: seq, did: did, timeUS: timeUS, rev: rev, operation: operation,
      collection: collection, rkey: rkey, cid: payload["cid"] as? String,
      recordJSON: recordJSON
    )
  }

  private static func envelope(_ payload: [String: Any]) -> (seq: Int64, did: String, timeUS: Int64)? {
    guard let seq = (payload["seq"] as? NSNumber)?.int64Value,
          let did = payload["did"] as? String,
          let time = payload["time"] as? String,
          let timeUS = microseconds(fromRFC3339: time)
    else { return nil }
    return (seq, did, timeUS)
  }

  private static func decodeDetail<T: Decodable>(_ type: T.Type, _ value: Any?) -> T? {
    guard let value, JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value)
    else { return nil }
    return try? JSONCoders.decode(type, from: data)
  }

  /// NSISO8601DateFormatter is documented thread-safe.
  private nonisolated(unsafe) static let wholeSecondFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// Parse an RFC3339 timestamp preserving microsecond precision.
  /// `ISO8601DateFormatter` truncates to milliseconds, so the fractional
  /// digits are extracted manually.
  static func microseconds(fromRFC3339 string: String) -> Int64? {
    guard let dotIndex = string.firstIndex(of: ".") else {
      guard let date = wholeSecondFormatter.date(from: string) else { return nil }
      return Int64((date.timeIntervalSince1970).rounded()) * 1_000_000
    }
    var fractionEnd = string.index(after: dotIndex)
    while fractionEnd < string.endIndex, string[fractionEnd].isNumber {
      fractionEnd = string.index(after: fractionEnd)
    }
    let withoutFraction = String(string[..<dotIndex]) + String(string[fractionEnd...])
    guard let date = wholeSecondFormatter.date(from: withoutFraction) else { return nil }
    let digits = string[string.index(after: dotIndex)..<fractionEnd]
    guard !digits.isEmpty else { return nil }
    let padded = (digits + "000000").prefix(6)
    guard let micros = Int64(padded) else { return nil }
    return Int64((date.timeIntervalSince1970).rounded()) * 1_000_000 + micros
  }
}
