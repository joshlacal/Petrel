import Foundation

/// An independent DAG-CBOR encoder for building wire fixtures in tests, so decoder tests do not
/// depend on the encoder of the library under test. Maps are written in canonical key order
/// (shorter keys first, then bytewise) unless `rawOrder` is used.
public indirect enum TestDAGCBOR: Sendable {
  case unsigned(UInt64)
  case negative(Int64)
  case bytes(Data)
  case text(String)
  case array([TestDAGCBOR])
  case map([(String, TestDAGCBOR)])
  /// Map written in the given order, for non-canonical fixtures.
  case rawOrder([(String, TestDAGCBOR)])
  /// A DAG-CBOR cid-link: tag 42 over `0x00` + the binary CID.
  case link(Data)
  case tag(UInt64, TestDAGCBOR)
  case bool(Bool)
  case null
  case float64(Double)
  /// Bytes spliced in verbatim.
  case raw(Data)

  public static func int(_ value: Int64) -> TestDAGCBOR {
    value >= 0 ? .unsigned(UInt64(value)) : .negative(value)
  }

  public var encoded: Data {
    var out = Data()
    encode(into: &out)
    return out
  }

  private func encode(into out: inout Data) {
    switch self {
    case let .unsigned(value):
      Self.head(major: 0, argument: value, into: &out)
    case let .negative(value):
      Self.head(major: 1, argument: UInt64(-1 - value), into: &out)
    case let .bytes(data):
      Self.head(major: 2, argument: UInt64(data.count), into: &out)
      out.append(data)
    case let .text(text):
      let utf8 = Data(text.utf8)
      Self.head(major: 3, argument: UInt64(utf8.count), into: &out)
      out.append(utf8)
    case let .array(items):
      Self.head(major: 4, argument: UInt64(items.count), into: &out)
      for item in items {
        item.encode(into: &out)
      }
    case let .map(entries):
      let sorted = entries.sorted { lhs, rhs in
        let l = Array(lhs.0.utf8), r = Array(rhs.0.utf8)
        return l.count != r.count ? l.count < r.count : l.lexicographicallyPrecedes(r)
      }
      TestDAGCBOR.rawOrder(sorted).encode(into: &out)
    case let .rawOrder(entries):
      Self.head(major: 5, argument: UInt64(entries.count), into: &out)
      for (key, value) in entries {
        TestDAGCBOR.text(key).encode(into: &out)
        value.encode(into: &out)
      }
    case let .link(cidBytes):
      var prefixed = Data([0x00] as [UInt8])
      prefixed.append(cidBytes)
      TestDAGCBOR.tag(42, .bytes(prefixed)).encode(into: &out)
    case let .tag(tag, value):
      Self.head(major: 6, argument: tag, into: &out)
      value.encode(into: &out)
    case let .bool(value):
      out.append(value ? 0xF5 : 0xF4)
    case .null:
      out.append(0xF6)
    case let .float64(value):
      out.append(0xFB)
      withUnsafeBytes(of: value.bitPattern.bigEndian) { out.append(contentsOf: $0) }
    case let .raw(data):
      out.append(data)
    }
  }

  private static func head(major: UInt8, argument: UInt64, into out: inout Data) {
    let prefix = major << 5
    switch argument {
    case 0 ..< 24:
      out.append(prefix | UInt8(argument))
    case 24 ... 0xFF:
      out.append(prefix | 24)
      out.append(UInt8(argument))
    case 0x100 ... 0xFFFF:
      out.append(prefix | 25)
      withUnsafeBytes(of: UInt16(argument).bigEndian) { out.append(contentsOf: $0) }
    case 0x1_0000 ... 0xFFFF_FFFF:
      out.append(prefix | 26)
      withUnsafeBytes(of: UInt32(argument).bigEndian) { out.append(contentsOf: $0) }
    default:
      out.append(prefix | 27)
      withUnsafeBytes(of: argument.bigEndian) { out.append(contentsOf: $0) }
    }
  }

  /// An event-stream frame: header object followed by payload object.
  public static func frame(header: TestDAGCBOR, payload: TestDAGCBOR) -> Data {
    header.encoded + payload.encoded
  }

  /// A message frame with header `{op: 1, t: type}`.
  public static func messageFrame(type: String, payload: [(String, TestDAGCBOR)]) -> Data {
    frame(header: .map([("op", .unsigned(1)), ("t", .text(type))]), payload: .map(payload))
  }

  /// An error frame with header `{op: -1}`.
  public static func errorFrame(error: String, message: String? = nil) -> Data {
    var payload: [(String, TestDAGCBOR)] = [("error", .text(error))]
    if let message {
      payload.append(("message", .text(message)))
    }
    return frame(header: .map([("op", .negative(-1))]), payload: .map(payload))
  }
}
