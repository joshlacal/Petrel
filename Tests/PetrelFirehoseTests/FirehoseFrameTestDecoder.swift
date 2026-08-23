import Foundation
import Petrel

/// Test-only value enum preserving the distinction between null, omitted
/// fields, and tag-42 CID links. No `[String: Any]` casts.
public indirect enum FirehoseTestCBORValue: Equatable, Sendable {
  case unsigned(UInt64)
  case signed(Int64)
  case text(String)
  case bytes(Data)
  case boolean(Bool)
  case null
  case array([FirehoseTestCBORValue])
  case map([FirehoseTestCBORMapEntry])
  case cidLink(CID)
}

public struct FirehoseTestCBORMapEntry: Equatable, Sendable {
  public let key: String
  public let value: FirehoseTestCBORValue

  public init(key: String, value: FirehoseTestCBORValue) {
    self.key = key
    self.value = value
  }
}

public enum FirehoseFrameTestDecoderError: Error, Equatable {
  case truncated
  case invalidEncoding
  case nonCanonicalInteger
  case nonCanonicalMapKeyOrder
  case invalidCIDLink
  case trailingBytes
}

/// Strict canonical CBOR reader modeled on Swan's private `CommitCBORParser`.
/// It validates shortest integer encodings and canonical map-key order while
/// parsing, and offers a two-object frame decoder for firehose frames.
public struct FirehoseTestCBORReader {
  private let bytes: [UInt8]
  private var offset = 0

  public init(_ data: Data) {
    bytes = Array(data)
  }

  public var isAtEnd: Bool { offset == bytes.count }

  public var consumedByteCount: Int { offset }

  /// Parse the first canonical CBOR value and return its consumed byte count.
  public static func consumedByteCount(ofFirstValueIn data: Data) throws -> Int {
    var reader = FirehoseTestCBORReader(data)
    _ = try reader.readNext()
    return reader.consumedByteCount
  }

  /// Parse one canonical CBOR value.
  public mutating func readNext() throws -> FirehoseTestCBORValue {
    guard let initial = readByte() else { throw FirehoseFrameTestDecoderError.truncated }
    let major = initial >> 5
    let argument = try readArgument(expectedMajor: major, initial: initial)
    switch major {
    case 0:
      return .unsigned(argument)
    case 1:
      if argument == 1 << 63 {
        return .signed(Int64.min)
      }
      guard argument <= UInt64(Int64.max) else {
        throw FirehoseFrameTestDecoderError.invalidEncoding
      }
      return .signed(-1 - Int64(argument))
    case 2:
      return .bytes(Data(try readPayload(length: argument)))
    case 3:
      let payload = try readPayload(length: argument)
      guard let text = String(data: Data(payload), encoding: .utf8) else {
        throw FirehoseFrameTestDecoderError.invalidEncoding
      }
      return .text(text)
    case 4:
      guard argument <= UInt64(Int.max) else {
        throw FirehoseFrameTestDecoderError.invalidEncoding
      }
      var values: [FirehoseTestCBORValue] = []
      values.reserveCapacity(Int(argument))
      for _ in 0 ..< argument {
        values.append(try readNext())
      }
      return .array(values)
    case 5:
      guard argument <= UInt64(Int.max) else {
        throw FirehoseFrameTestDecoderError.invalidEncoding
      }
      var entries: [FirehoseTestCBORMapEntry] = []
      entries.reserveCapacity(Int(argument))
      var previousKey: (length: Int, bytes: [UInt8])?
      for _ in 0 ..< argument {
        guard case let .text(key) = try readNext() else {
          throw FirehoseFrameTestDecoderError.invalidEncoding
        }
        let keyBytes = Array(key.utf8)
        if let previousKey {
          if keyBytes.count < previousKey.length
            || (keyBytes.count == previousKey.length && keyBytes.lexicographicallyPrecedes(previousKey.bytes))
          {
            throw FirehoseFrameTestDecoderError.nonCanonicalMapKeyOrder
          }
        }
        previousKey = (keyBytes.count, keyBytes)
        entries.append(FirehoseTestCBORMapEntry(key: key, value: try readNext()))
      }
      return .map(entries)
    case 6:
      guard argument == 42 else {
        throw FirehoseFrameTestDecoderError.invalidEncoding
      }
      return .cidLink(try readRequiredLink())
    case 7:
      switch argument {
      case 20:
        return .boolean(false)
      case 21:
        return .boolean(true)
      case 22:
        return .null
      default:
        throw FirehoseFrameTestDecoderError.invalidEncoding
      }
    default:
      throw FirehoseFrameTestDecoderError.invalidEncoding
    }
  }

  /// Parse exactly two canonical CBOR values and reject trailing bytes.
  public mutating func readFrame() throws -> (header: FirehoseTestCBORValue, body: FirehoseTestCBORValue) {
    let header = try readNext()
    let body = try readNext()
    guard isAtEnd else { throw FirehoseFrameTestDecoderError.trailingBytes }
    return (header, body)
  }

  private mutating func readRequiredLink() throws -> CID {
    guard let initial = readByte(), initial >> 5 == 2 else {
      throw FirehoseFrameTestDecoderError.invalidCIDLink
    }
    let length = try readArgument(expectedMajor: 2, initial: initial)
    let payload = try readPayload(length: length)
    guard payload.count == 37, payload.first == 0 else {
      throw FirehoseFrameTestDecoderError.invalidCIDLink
    }
    do {
      return try CID(bytes: Data(payload.dropFirst()))
    } catch {
      throw FirehoseFrameTestDecoderError.invalidCIDLink
    }
  }

  private mutating func readPayload(length: UInt64) throws -> [UInt8] {
    guard length <= UInt64(bytes.count - offset) else {
      throw FirehoseFrameTestDecoderError.truncated
    }
    let slice = bytes[offset ..< offset + Int(length)]
    offset += Int(length)
    return Array(slice)
  }

  private mutating func readArgument(expectedMajor: UInt8, initial: UInt8) throws -> UInt64 {
    guard initial >> 5 == expectedMajor else {
      throw FirehoseFrameTestDecoderError.invalidEncoding
    }
    switch initial & 0x1f {
    case 0 ... 23:
      return UInt64(initial & 0x1f)
    case 24:
      let value = try readFixed(1)
      guard value >= 24 else { throw FirehoseFrameTestDecoderError.nonCanonicalInteger }
      return value
    case 25:
      let value = try readFixed(2)
      guard value > UInt8.max else { throw FirehoseFrameTestDecoderError.nonCanonicalInteger }
      return value
    case 26:
      let value = try readFixed(4)
      guard value > UInt16.max else { throw FirehoseFrameTestDecoderError.nonCanonicalInteger }
      return value
    case 27:
      let value = try readFixed(8)
      guard value > UInt32.max else { throw FirehoseFrameTestDecoderError.nonCanonicalInteger }
      return value
    default:
      throw FirehoseFrameTestDecoderError.invalidEncoding
    }
  }

  private mutating func readFixed(_ count: Int) throws -> UInt64 {
    guard count <= bytes.count - offset else {
      throw FirehoseFrameTestDecoderError.truncated
    }
    var value: UInt64 = 0
    for byte in bytes[offset ..< offset + count] {
      value = (value << 8) | UInt64(byte)
    }
    offset += count
    return value
  }

  private mutating func readByte() -> UInt8? {
    guard offset < bytes.count else { return nil }
    defer { offset += 1 }
    return bytes[offset]
  }
}
