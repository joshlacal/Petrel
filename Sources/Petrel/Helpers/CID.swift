import CryptoKit
import Foundation
import SwiftCBOR

// MARK: - Constants and Enums

/// Represents the codec type for Content Identifiers
public enum CIDCodec: UInt8 {
  case dagCBOR = 0x71
  case raw = 0x55

  var name: String {
    switch self {
    case .dagCBOR: return "dag-cbor"
    case .raw: return "raw"
    }
  }
}

// MARK: - Multihash Implementation

/// Represents a multihash structure as used in IPFS and AT Protocol
public struct Multihash {
  static let sha256Code: UInt8 = 0x12
  static let sha256Length: UInt8 = 0x20  // 32 bytes

  let algorithm: UInt8
  let length: UInt8
  let digest: Data

  /// Returns the full binary representation of the multihash
  var bytes: Data {
    var data = Data()
    data.append(algorithm)
    data.append(length)
    data.append(digest)
    return data
  }

  /// Creates a SHA-256 multihash from the provided data
  static func sha256(_ data: Data) -> Multihash {
    let digest = SHA256.hash(data: data)
    let digestData = Data(digest)
    return Multihash(
      algorithm: sha256Code,
      length: sha256Length,
      digest: digestData
    )
  }
}

// MARK: - CID Implementation

/// Content Identifier (CID) implementation for AT Protocol
/// works specifically for AT Protocol's blessed CID format using SHA-256
public struct CID: Equatable, Hashable, Codable, CustomStringConvertible {
  static let version: UInt8 = 0x01
  let codec: CIDCodec
  let multihash: Multihash

    public init(codec: CIDCodec, multihash: Multihash) {
        self.codec = codec
        self.multihash = multihash
    }
    
  /// Returns the full binary representation of the CID
  public var bytes: Data {
    var data = Data([CID.version])
    data.append(codec.rawValue)
    data.append(multihash.bytes)
    return data
  }

  /// Returns the string representation of the CID (base32-encoded with 'b' prefix)
  public var string: String {
    // "b" is the multibase prefix for base32
    return "b" + base32Encode(bytes).lowercased()
  }

  /// Returns the string representation when the CID is used in a string context
  public var description: String {
    return string
  }

  /// Creates a CID from DAG-CBOR encoded data
  public static func fromDAGCBOR(_ cborData: Data) -> CID {
    let multihash = Multihash.sha256(cborData)
    return CID(codec: .dagCBOR, multihash: multihash)
  }

  /// Creates a CID from blob data
  public static func fromBlob(_ blobData: Data) -> CID {
    let multihash = Multihash.sha256(blobData)
    return CID(codec: .raw, multihash: multihash)
  }

  /// Attempts to parse a CID from a string representation
  public static func parse(_ cidString: String) -> CID? {
    guard cidString.hasPrefix("b") else { return nil }  // Must be base32

    let base32Part = String(cidString.dropFirst())
    guard let cidBytes = base32Decode(base32Part.uppercased()) else { return nil }

    // Must be at least 36 bytes for AT Protocol CIDs: 1+1+1+1+32
    guard cidBytes.count >= 36 else { return nil }

    // Parse components
    guard cidBytes[0] == version else { return nil }

    let codecByte = cidBytes[1]
    guard let codec = CIDCodec(rawValue: codecByte) else { return nil }

    guard cidBytes[2] == Multihash.sha256Code,
      cidBytes[3] == Multihash.sha256Length
    else { return nil }

    let digestBytes = cidBytes.suffix(from: 4)
    let multihash = Multihash(
      algorithm: Multihash.sha256Code,
      length: Multihash.sha256Length,
      digest: Data(digestBytes)
    )

    return CID(codec: codec, multihash: multihash)
  }

  // MARK: - Codable Implementation

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let cidString = try container.decode(String.self)

    guard let cid = CID.parse(cidString) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid CID string format"
      )
    }

    self = cid
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(string)
  }

  // MARK: - Equatable & Hashable Implementation

  public static func == (lhs: CID, rhs: CID) -> Bool {
    return lhs.bytes == rhs.bytes
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(bytes)
  }
}

// MARK: - DAG-CBOR Serialization

/// Basic interface for DAG-CBOR encoding
public protocol DAGCBOREncodable {
  /// Convert the object to a SwiftCBOR compatible value
  func toCBORValue() throws -> Any

  /// Encode to DAG-CBOR format
  func encodedDAGCBOR() throws -> Data
}

/// Basic interface for DAG-CBOR decoding
public protocol DAGCBORDecodable {
  /// Decode from DAG-CBOR format
  static func decodedFromDAGCBOR(_ data: Data) throws -> Self
}

/// Protocol for types that can be encoded to and decoded from DAG-CBOR
public typealias DAGCBORCodable = DAGCBOREncodable & DAGCBORDecodable

/// Error types for DAG-CBOR operations
public enum DAGCBORError: Error {
  case encodingFailed(String)
  case decodingFailed(String)
  case unsupportedType(String)
  case invalidCIDEncoding
  case invalidMapKey
  case floatingPointNotAllowed
}

/// Implementation of DAG-CBOR encoding and decoding
public class DAGCBOR {
  /// The CBOR tag used for CIDs in DAG-CBOR
    private static let cidTag = CBOR.Tag.self(rawValue: 42)

  /// Encode a value to DAG-CBOR format according to the AT Protocol specifications
  public static func encode(_ value: DAGCBOREncodable) throws -> Data {
    let cborValue = try value.toCBORValue()
    return try encodeValue(cborValue)
  }

  /// Encode a raw value to DAG-CBOR format
    public static func encodeValue(_ value: Any) throws -> Data {
        let cborItem = try convertToCBORItem(value)
        let bytes = CBOR.encode([cborItem])
        return Data(bytes)  // Convert [UInt8] to Data
    }
    
  /// Decode a DAG-CBOR encoded value
  public static func decode<T: DAGCBORDecodable>(_ data: Data) throws -> T {
    return try T.decodedFromDAGCBOR(data)
  }

  /// Convert a Swift value to a CBOR.CBOREncodable item ensuring DAG-CBOR compatibility
  private static func convertToCBORItem(_ value: Any) throws -> CBOR {
    switch value {
    case let string as String:
      return .utf8String(string)

    case let int as Int:
      return .unsignedInt(UInt64(int))

    case let uint as UInt:
      return .unsignedInt(UInt64(uint))

    case let int8 as Int8:
      return .negativeInt(UInt64(abs(Int64(int8) + 1)))

    case let uint8 as UInt8:
      return .unsignedInt(UInt64(uint8))

    case let int16 as Int16:
      if int16 < 0 {
        return .negativeInt(UInt64(abs(Int64(int16) + 1)))
      } else {
        return .unsignedInt(UInt64(int16))
      }

    case let uint16 as UInt16:
      return .unsignedInt(UInt64(uint16))

    case let int32 as Int32:
      if int32 < 0 {
        return .negativeInt(UInt64(abs(Int64(int32) + 1)))
      } else {
        return .unsignedInt(UInt64(int32))
      }

    case let uint32 as UInt32:
      return .unsignedInt(UInt64(uint32))

    case let int64 as Int64:
      if int64 < 0 {
        return .negativeInt(UInt64(abs(int64 + 1)))
      } else {
        return .unsignedInt(UInt64(int64))
      }

    case let uint64 as UInt64:
      return .unsignedInt(uint64)

    case let bool as Bool:
      return .boolean(bool)

    case let array as [Any]:
      var cborArray = [CBOR]()
      for item in array {
        cborArray.append(try convertToCBORItem(item))
      }
      return .array(cborArray)

    case let dict as [String: Any]:
      // Sort keys lexicographically for deterministic encoding
      let sortedKeys = dict.keys.sorted()
      var cborDict = [CBOR: CBOR]()

      for key in sortedKeys {
        let cborKey = CBOR.utf8String(key)
        let value = dict[key]!
        let cborValue = try convertToCBORItem(value)
        cborDict[cborKey] = cborValue
      }

      return .map(cborDict)

    case let data as Data:
      return .byteString([UInt8](data))

    case let cid as CID:
      // CID links are encoded with tag 42 and a leading 0x00 byte
      return try encodeCIDLink(cid)

    case is Float, is Double, is CGFloat:
      // AT Protocol forbids floating point numbers in DAG-CBOR
      throw DAGCBORError.floatingPointNotAllowed

    case let null as Any? where null == nil:
      return .null

    default:
      throw DAGCBORError.unsupportedType(String(describing: type(of: value)))
    }
  }

  /// Encode a CID as a properly tagged link according to DAG-CBOR rules
    private static func encodeCIDLink(_ cid: CID) throws -> CBOR {
        // Prefix the CID bytes with 0x00 as required by the DAG-CBOR spec
        let cidWithPrefix = Data([0x00]) + cid.bytes
        
        // Create a tagged value with the CID bytes
        return CBOR.tagged(CBOR.Tag.self(rawValue: 42),
                           .byteString([UInt8](cidWithPrefix)))
    }
    
  /// Decode a CBOR item that might contain CID links
    public static func decodeCBORItem(_ item: CBOR) throws -> Any {
    switch item {
    case .utf8String(let string):
      return string

    case .unsignedInt(let uint):
      return uint

    case .negativeInt(let uint):
      return -Int64(uint) - 1

    case .boolean(let bool):
      return bool

    case .array(let array):
      var decodedArray = [Any]()
      for item in array {
        decodedArray.append(try decodeCBORItem(item))
      }
      return decodedArray

    case .map(let dict):
      var decodedDict = [String: Any]()
      for (key, value) in dict {
        // In DAG-CBOR, map keys must be strings
        guard case let .utf8String(keyString) = key else {
          throw DAGCBORError.invalidMapKey
        }

        decodedDict[keyString] = try decodeCBORItem(value)
      }
      return decodedDict

    case .byteString(let bytes):
      return Data(bytes)

    case .null:
      return nil as Any?

    case .tagged(let tag, let value):
        // Handle tag 42 (CID link)
        if tag.rawValue == 42 {
        guard case let .byteString(bytes) = value,
          bytes.count > 1,
          bytes[0] == 0x00
        else {
          throw DAGCBORError.invalidCIDEncoding
        }

        // Remove the 0x00 prefix and create a CID
        let cidBytes = Data(bytes.dropFirst())

        // Must be at least 36 bytes for AT Protocol CIDs: 1+1+1+1+32
        guard cidBytes.count >= 36 else {
          throw DAGCBORError.invalidCIDEncoding
        }

        // Parse components
        guard cidBytes[0] == CID.version else {
          throw DAGCBORError.invalidCIDEncoding
        }

        let codecByte = cidBytes[1]
        guard let codec = CIDCodec(rawValue: codecByte) else {
          throw DAGCBORError.invalidCIDEncoding
        }

        guard cidBytes[2] == Multihash.sha256Code,
          cidBytes[3] == Multihash.sha256Length
        else {
          throw DAGCBORError.invalidCIDEncoding
        }

        let digestBytes = cidBytes.suffix(from: 4)
        let multihash = Multihash(
          algorithm: Multihash.sha256Code,
          length: Multihash.sha256Length,
          digest: Data(digestBytes)
        )

        return CID(codec: codec, multihash: multihash)
      } else {
        // AT Protocol only supports tag 42 for CIDs
        throw DAGCBORError.unsupportedType("CBOR tag \(tag)")
      }
    case .simple, .date, .float, .double, .break:
        // These CBOR types are not supported in DAG-CBOR
        throw DAGCBORError.unsupportedType(String(describing: item))
    case .undefined:
        throw DAGCBORError.unsupportedType("CBOR undefined")
    case .half(_):
        throw DAGCBORError.floatingPointNotAllowed
    }
  }
}

// Default implementation of DAGCBOREncodable
public extension DAGCBOREncodable {
  public func encodedDAGCBOR() throws -> Data {
    let value = try self.toCBORValue()
    return try DAGCBOR.encodeValue(value)
  }
}

// MARK: - Base32 Encoding/Decoding

/// Character set for Base32 encoding (RFC 4648)
private let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

/// Encodes data to a Base32 string
/// - Parameter data: The data to encode
/// - Returns: Base32 encoded string
public func base32Encode(_ data: Data) -> String {
  var result = ""
  var bits = 0
  var value = 0

  for byte in data {
    value = (value << 8) | Int(byte)
    bits += 8

    while bits >= 5 {
      bits -= 5
      let index = (value >> bits) & 0x1F
      result.append(
        base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)])
    }
  }

  // Handle remaining bits if any
  if bits > 0 {
    let index = (value << (5 - bits)) & 0x1F
    result.append(base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)])
  }

  // Remove the padding step - don't add "=" characters
  return result
}

/// Decodes a Base32 string to data
/// - Parameter string: The Base32 string to decode
/// - Returns: Decoded data or nil if the string is invalid
public func base32Decode(_ string: String) -> Data? {
  var string = string.uppercased()

  // Remove padding
  string = string.replacingOccurrences(of: "=", with: "")

  var result = Data()
  var bits = 0
  var value = 0

  for char in string {
    guard let index = base32Alphabet.firstIndex(of: char) else {
      return nil
    }

    let charValue = base32Alphabet.distance(from: base32Alphabet.startIndex, to: index)
    value = (value << 5) | charValue
    bits += 5

    if bits >= 8 {
      bits -= 8
      result.append(UInt8((value >> bits) & 0xFF))
    }
  }

  return result
}

// MARK: - Usage Examples

/// Create a CID for a record
public func createRecordCID<T: DAGCBOREncodable>(_ record: T) throws -> String {
  let cborData = try DAGCBOR.encode(record)
  let cid = CID.fromDAGCBOR(cborData)
  return cid.string
}

/// Create a CID for a blob
public func createBlobCID(_ blobData: Data) -> String {
  let cid = CID.fromBlob(blobData)
  return cid.string
}

// Extension for types that are both Codable and DAGCBOREncodable
public extension DAGCBOREncodable where Self: Encodable {
    public func toCBORValue() throws -> Any {
        // Convert to a dictionary using JSONEncoder's internals
        let data = try JSONEncoder().encode(self)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Handle potential conversion errors
        guard let dict = dict else {
            throw DAGCBORError.encodingFailed("Failed to convert object to dictionary")
        }
        
        return dict
    }
}

// Extension for decoding
public extension DAGCBORDecodable where Self: Decodable {
    public static func decodedFromDAGCBOR(_ data: Data) throws -> Self {
        // Parse CBOR data directly - it returns a single CBOR value, not an array
        guard let cborItem = try CBOR.decode([UInt8](data)) else {
            throw DAGCBORError.decodingFailed("Failed to convert decoded value to target type")
        }
        
        // Convert to native dictionary or other Swift type
        let value = try DAGCBOR.decodeCBORItem(cborItem)
        
        // Convert back to JSON and then to the target type
        if let dict = value as? [String: Any] {
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Self.self, from: jsonData)
        }
        
        throw DAGCBORError.decodingFailed("Failed to convert decoded value to target type")
    }
}
