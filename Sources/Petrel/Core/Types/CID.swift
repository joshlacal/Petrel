// File: CID.swift
// Description: Implements CID handling and canonical DAG-CBOR encoding
//              according to AT Protocol specifications.

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
import SwiftCBOR

// MARK: - ================== Core Protocols ==================

/// Basic interface for DAG-CBOR encoding
public protocol DAGCBOREncodable {
    func toCBORValue() throws -> Any
    func encodedDAGCBOR() throws -> Data
}

/// Basic interface for DAG-CBOR decoding
public protocol DAGCBORDecodable {
    static func decodedFromDAGCBOR(_ data: Data) throws -> Self
}

/// Protocol for types that can be encoded to and decoded from DAG-CBOR
public typealias DAGCBORCodable = DAGCBORDecodable & DAGCBOREncodable

/// Error types for DAG-CBOR operations
public enum DAGCBORError: Error {
    case encodingFailed(String)
    case decodingFailed(String)
    case unsupportedType(String)
    case invalidCIDEncoding(String)
    case invalidMapKey
    case floatingPointNotAllowed
}

// MARK: - ================== CIDAsLink Wrapper ==================

/// Carries a CID's string-vs-link wire representation through CBOR conversion.
struct CIDAsLink {
    enum Representation {
        case link
        case string
    }

    let cid: CID
    let representation: Representation
}

// MARK: - ================== CID Implementation ==================

/// Represents the codec type for Content Identifiers
public enum CIDCodec: UInt8, ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? CIDCodec else { return false }
        return self == other
    }

    public func toCBORValue() throws -> Any {
        return rawValue
    }

    case raw = 0x55
    case dagPB = 0x70
    case dagCBOR = 0x71
    case gitRaw = 0x78
    case identity = 0x00

    var name: String {
        switch self {
        case .raw: return "raw"
        case .dagPB: return "dag-pb"
        case .dagCBOR: return "dag-cbor"
        case .gitRaw: return "git-raw"
        case .identity: return "identity"
        }
    }
}

/// Represents a multihash structure as used in IPFS and AT Protocol
public struct Multihash: ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Multihash else { return false }
        return algorithm == other.algorithm && length == other.length && digest == other.digest
    }

    public func toCBORValue() throws -> Any {
        return bytes
    }

    // Common hash algorithm codes (from multihash table)
    public static let sha1Code: UInt8 = 0x11
    public static let sha1Length: UInt8 = 0x14 // 20 bytes
    public static let sha256Code: UInt8 = 0x12
    public static let sha256Length: UInt8 = 0x20 // 32 bytes
    public static let sha512Code: UInt8 = 0x13
    public static let sha512Length: UInt8 = 0x40 // 64 bytes
    public static let blake2b256Code: UInt8 = 0xB2
    public static let blake2b256Length: UInt8 = 0x20 // 32 bytes
    /// Get a human-readable name for the hash algorithm
    public var algorithmName: String {
        switch algorithm {
        case Multihash.sha1Code:
            return "SHA-1"
        case Multihash.sha256Code:
            return "SHA-256"
        case Multihash.sha512Code:
            return "SHA-512"
        case Multihash.blake2b256Code:
            return "BLAKE2b-256"
        default:
            return "Unknown (0x\(String(format: "%02X", algorithm)))"
        }
    }

    public let algorithm: UInt8
    public let length: UInt8
    public let digest: Data

    public init(algorithm: UInt8, length: UInt8, digest: Data) {
        self.algorithm = algorithm
        self.length = length
        self.digest = digest
    }

    public var bytes: Data {
        Data([algorithm, length]) + digest
    }

    public static func sha256(_ data: Data) -> Multihash {
        Multihash(
            algorithm: sha256Code,
            length: sha256Length,
            digest: Data(SHA256.hash(data: data))
        )
    }
}

// MARK: $link

public struct ATProtoLink: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
    /// Store the actual CID object
    public let cid: CID

    /// JSON Coding Keys
    enum CodingKeys: String, CodingKey {
        case cidString = "$link" // Map JSON "$link" to a temporary string property
    }

    // --- Initializers ---

    /// Initialize with a CID struct
    public init(cid: CID) {
        self.cid = cid
    }

    /// Initialize by parsing a CID string (e.g., "bafy...")
    public init(cidString: String) throws {
        let cid = try CID.parse(cidString)
        try Self.validate(cid)
        self.cid = cid
    }

    // --- Codable Conformance ---

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cidString = try container.decode(String.self, forKey: .cidString)
        self = try ATProtoLink(cidString: cidString)
    }

    public func encode(to encoder: Encoder) throws {
        try Self.validate(cid)
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode back to the string representation for JSON compatibility
        try container.encode(cid.string, forKey: .cidString)
    }

    // --- ATProtocolValue / Equatable / Hashable Conformance ---

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherLink = other as? ATProtoLink else { return false }
        return cid == otherLink.cid // Compare contained CIDs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cid)
    }

    // --- DAGCBOREncodable Conformance ---

    /// **IMPORTANT:** For DAG-CBOR, a CID struct needs to encode differently based on context:
    /// - When used in a data model like StrongRef, it should encode as a simple string
    /// - When used through ATProtoLink, it needs Tag 42 encoding
    public func toCBORValue() throws -> Any {
        try Self.validate(cid)
        return CIDAsLink(cid: cid, representation: .link)
    }

    private static func validate(_ cid: CID) throws {
        guard cid.codec == .raw || cid.codec == .dagCBOR else {
            throw DAGCBORError.invalidCIDEncoding(
                "ATProtoLink requires raw or dag-cbor codec, received \(cid.codec.name)"
            )
        }

        guard cid.multihash.algorithm == Multihash.sha256Code else {
            throw DAGCBORError.invalidCIDEncoding(
                "ATProtoLink requires SHA-256 multihash algorithm"
            )
        }

        guard cid.multihash.length == Multihash.sha256Length else {
            throw DAGCBORError.invalidCIDEncoding(
                "ATProtoLink requires a declared multihash length of 32 bytes"
            )
        }

        guard cid.multihash.digest.count == Int(Multihash.sha256Length) else {
            throw DAGCBORError.invalidCIDEncoding(
                "ATProtoLink requires a 32-byte multihash digest"
            )
        }
    }
}

/// Content Identifier (CID) implementation for AT Protocol (v1, SHA-256)
public struct CID: Equatable, Hashable, Codable, CustomStringConvertible, ATProtocolValue {
    private enum CodingKeys: String, CodingKey {
        case link = "$link"
    }

    static let version: UInt8 = 0x01
    public let codec: CIDCodec
    public let multihash: Multihash

    public init(codec: CIDCodec, multihash: Multihash) {
        self.codec = codec
        self.multihash = multihash
    }

    /// Returns the full binary representation of the CID (version + codec + multihash)
    public var bytes: Data {
        Data([CID.version, codec.rawValue]) + multihash.bytes
    }

    /// Returns the base32 string representation (e.g., "bafy...")
    public var string: String {
        "b" + base32Encode(bytes).lowercased()
    }

    public var description: String {
        string
    }

    /// Creates a CID by hashing DAG-CBOR encoded data
    public static func fromDAGCBOR(_ cborData: Data) -> CID {
        CID(codec: .dagCBOR, multihash: Multihash.sha256(cborData))
    }

    /// Creates a CID by hashing raw blob data
    public static func fromBlob(_ blobData: Data) -> CID {
        CID(codec: .raw, multihash: Multihash.sha256(blobData))
    }

    /// --- Parsing ---
    public enum CIDParseError: Error {
        case invalidPrefix(String)
        case invalidBase32Encoding, insufficientLength
        case
            invalidVersion(UInt8)
        case unsupportedCodec(UInt8)
        case invalidHashAlgorithm(UInt8, UInt8)
    }

    public static func parse(_ cidString: String) throws -> CID {
        // Input validation
        guard !cidString.isEmpty else {
            throw CIDParseError.invalidPrefix("CID string cannot be empty")
        }

        guard cidString.hasPrefix("b") else {
            throw CIDParseError.invalidPrefix("Requires 'b' prefix")
        }

        // Validate reasonable length (CIDs should be around 50-60 characters typically)
        guard cidString.count >= 10 && cidString.count <= 100 else {
            throw CIDParseError.invalidPrefix("CID string length out of valid range")
        }

        let base32Part = String(cidString.dropFirst())

        guard let cidBytes = base32Decode(base32Part.uppercased()) else {
            throw CIDParseError.invalidBase32Encoding
        }

        return try CID(bytes: cidBytes)
    }

    /// Initialize CID from its raw binary representation (version + codec + multihash)
    public init(bytes cidBytes: Data) throws {
        // Basic length validation
        guard cidBytes.count >= 4 else {
            throw CIDParseError.insufficientLength
        }

        // Safe array access with bounds checking
        guard cidBytes.indices.contains(0) else {
            throw CIDParseError.insufficientLength
        }

        guard cidBytes[0] == CID.version else {
            throw CIDParseError.invalidVersion(cidBytes[0])
        }

        guard cidBytes.indices.contains(1) else {
            throw CIDParseError.insufficientLength
        }

        guard let codec = CIDCodec(rawValue: cidBytes[1]) else {
            let codecByte = cidBytes[1]
            throw CIDParseError.unsupportedCodec(codecByte)
        }

        // Safe access to hash algorithm and length bytes
        guard cidBytes.indices.contains(2), cidBytes.indices.contains(3) else {
            throw CIDParseError.insufficientLength
        }

        let hashAlgorithm = cidBytes[2]
        let hashLength = cidBytes[3]
        let digestStart = 4

        // Validate hash length is reasonable (prevent overflow attacks)
        guard hashLength > 0, hashLength <= 64 else {
            throw CIDParseError.insufficientLength
        }

        let expectedTotalLength = digestStart + Int(hashLength)
        guard cidBytes.count == expectedTotalLength else {
            throw CIDParseError.insufficientLength
        }

        // Safe digest extraction with bounds validation
        guard digestStart >= 0, digestStart <= cidBytes.count else {
            throw CIDParseError.insufficientLength
        }

        // Create digest safely - avoid suffix() which may cause runtime issues
        let digestBytes = Data(cidBytes[digestStart...])

        // Final validation that we got the expected digest length
        guard digestBytes.count == Int(hashLength) else {
            throw CIDParseError.insufficientLength
        }

        self.codec = codec
        multihash = Multihash(algorithm: hashAlgorithm, length: hashLength, digest: digestBytes)

        // AT Protocol typically uses SHA-256, but CAR files may contain other hash algorithms
        // Allow parsing to continue for all hash algorithms
    }

    /// --- Codable Conformance ---
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let cidString = try? container.decode(String.self)
        {
            self = try CID.parse(cidString)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cidString = try container.decode(String.self, forKey: .link)
        self = try CID.parse(cidString)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    /// --- ATProtocolValue Conformance ---
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? CID else { return false }
        return self == other
    }

    /// --- DAGCBOREncodable Conformance ---
    /// Lexicon `format: cid` values remain CBOR strings. `ATProtoLink` selects
    /// the distinct Tag 42 representation used by Lexicon `cid-link` values.
    public func toCBORValue() throws -> Any {
        return CIDAsLink(cid: self, representation: .string)
    }
}

public class DAGCBOR {
    private static let cidTagValue: UInt64 = 42

    /// Encode a DAGCBOREncodable value to canonical DAG-CBOR bytes.
    public static func encode(_ value: DAGCBOREncodable) throws -> Data {
        let intermediateValue = try value.toCBORValue()
        return try encodeValue(intermediateValue)
    }

    /// Encode a standard Swift value (Int, String, Array, Dictionary, CID, etc.)
    /// to canonical DAG-CBOR bytes.
    public static func encodeValue(_ value: Any) throws -> Data {
        // 1. Convert the Swift value into its CBOR enum representation (e.g., .utf8String, .map, .tagged)
        //    This step handles converting ATProtoLink -> CID struct -> CBOR.tagged(42, ...)
        //    and StrongRef -> OrderedMap -> CBOR.map(string_keys, string_cid_value)
        let cborItem = try convertToCBORItem(value)

        // 2. Canonically encode the typed CBOR tree without decoding it back to
        //    Swift values. This preserves the distinction between string-format
        //    CIDs and Tag 42 cid-links at every nesting level.
        return try encodeCanonicalCBORItem(cborItem)
    }

    private static func encodeCanonicalCBORItem(_ item: CBOR) throws -> Data {
        switch item {
        case let .map(map):
            return try encodeCanonicalMap(map)
        case let .array(array):
            var result = encodeMajorTypeHeader(majorType: 4, argument: UInt64(array.count))
            for nestedItem in array {
                try result.append(encodeCanonicalCBORItem(nestedItem))
            }
            return result
        case let .tagged(tag, nestedItem):
            var result = encodeMajorTypeHeader(majorType: 6, argument: tag.rawValue)
            try result.append(encodeCanonicalCBORItem(nestedItem))
            return result
        default:
            return Data(item.encode(options: CBOROptions()))
        }
    }

    private static func encodeMajorTypeHeader(majorType: UInt8, argument: UInt64) -> Data {
        let prefix = majorType << 5
        var result = Data()

        switch argument {
        case 0 ..< 24:
            result.append(prefix | UInt8(argument))
        case 24 ... UInt64(UInt8.max):
            result.append(prefix | 24)
            result.append(UInt8(argument))
        case (UInt64(UInt8.max) + 1) ... UInt64(UInt16.max):
            result.append(prefix | 25)
            var value = UInt16(argument).bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt16>.size))
        case (UInt64(UInt16.max) + 1) ... UInt64(UInt32.max):
            result.append(prefix | 26)
            var value = UInt32(argument).bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt32>.size))
        default:
            result.append(prefix | 27)
            var value = argument.bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt64>.size))
        }

        return result
    }

    /// --- Canonical Map Encoding ---
    private static func encodeCanonicalMap(_ map: [CBOR: CBOR]) throws -> Data {
        // 1. Extract keys and sort (Length then Lexicographical)
        var keyPairs: [(key: CBOR, utf8Bytes: Data, value: CBOR)] = []
        for (key, value) in map {
            guard case let .utf8String(keyString) = key else {
                throw DAGCBORError.invalidMapKey
            }
            let utf8Bytes = keyString.data(using: .utf8)!
            keyPairs.append((key: key, utf8Bytes: utf8Bytes, value: value))
        }

        keyPairs.sort { a, b in
            if a.utf8Bytes.count != b.utf8Bytes.count {
                return a.utf8Bytes.count < b.utf8Bytes.count
            }
            return a.utf8Bytes.lexicographicallyPrecedes(b.utf8Bytes)
        }

        // 3. Create a minimal map header.
        var result = encodeMajorTypeHeader(majorType: 5, argument: UInt64(map.count))

        // 4. Add sorted key-value pairs while preserving their typed CBOR values.
        let keyEncodingOptions = CBOROptions() // Defaults for simple string keys
        for pair in keyPairs {
            // Encode the key (always a UTF8 string here)
            let keyBytes = pair.key.encode(options: keyEncodingOptions)
            result.append(contentsOf: keyBytes)

            let valueBytes = try encodeCanonicalCBORItem(pair.value)
            result.append(contentsOf: valueBytes)
        }
        return result
    }

    /// --- Swift Value -> CBOR Enum Conversion ---
    private static func convertToCBORItem(_ value: Any) throws -> CBOR {
        switch value {
        // Handle ATProtoLink by using its toCBORValue method
        case let link as ATProtoLink:
            return try convertToCBORItem(link.toCBORValue())
        case let cidValue as CIDAsLink:
            switch cidValue.representation {
            case .link:
                return try encodeCIDLinkForCBOR(cidValue.cid)
            case .string:
                return .utf8String(cidValue.cid.string)
            }
        case let cid as CID:
            return .utf8String(cid.string)
        // Other cases remain the same...
        case let orderedMap as OrderedCBORMap:
            var cborDict = [CBOR: CBOR]()
            for (key, value) in orderedMap.entries {
                let cborKey = CBOR.utf8String(key)
                let cborValue = try convertToCBORItem(value) // Recursive call
                cborDict[cborKey] = cborValue
            }
            return .map(cborDict)
        // Handle basic Swift types
        case let string as String: return .utf8String(string)
        case let bool as Bool: return .boolean(bool)
        case let data as Data: return .byteString(data.map { $0 })
        case let int as Int: return CBOR.fromInt(int) // Handles positive/negative
        case let uint as UInt: return .unsignedInt(UInt64(uint))
        case let int8 as Int8: return CBOR.fromInt(Int(int8))
        case let uint8 as UInt8: return .unsignedInt(UInt64(uint8))
        case let int16 as Int16: return CBOR.fromInt(Int(int16))
        case let uint16 as UInt16: return .unsignedInt(UInt64(uint16))
        case let int32 as Int32: return CBOR.fromInt(Int(int32))
        case let uint32 as UInt32: return .unsignedInt(UInt64(uint32))
        case let int64 as Int64: return CBOR.fromInt64(int64)
        case let uint64 as UInt64: return .unsignedInt(uint64)
        // Handle Arrays
        case let array as [Any]:
            var cborArray = [CBOR]()
            for item in array {
                try cborArray.append(convertToCBORItem(item)) // Recursive call
            }
            return .array(cborArray)
        // Handle standard Dictionaries (less common if using OrderedCBORMap)
        case let dict as [String: Any]:
            var cborDict = [CBOR: CBOR]()
            for (key, value) in dict {
                let cborKey = CBOR.utf8String(key)
                let cborValue = try convertToCBORItem(value) // Recursive call
                cborDict[cborKey] = cborValue
            }
            return .map(cborDict) // Note: This CBOR.map is inherently unordered
        // Handle nil / null
        case Optional<Any>.none:
            return .null
        case is NSNull: // Just in case NSNull is used somewhere
            return .null
        // Handle floating point (disallowed)
        case is Float, is Double, is CGFloat:
            throw DAGCBORError.floatingPointNotAllowed
        // Default: Check for other DAGCBOREncodable types
        default:
            if let encodableValue = value as? DAGCBOREncodable {
                let intermediateValue = try encodableValue.toCBORValue()
                // Recursively call with the result (e.g., if ATProtoDate.toCBORValue returns a String)
                return try convertToCBORItem(intermediateValue)
            } else {
                // Truly unsupported type
                throw DAGCBORError.unsupportedType(String(describing: type(of: value)))
            }
        }
    }

    /// Creates the CBOR.tagged enum case for a CID (used by convertToCBORItem).
    private static func encodeCIDLinkForCBOR(_ cid: CID) throws -> CBOR {
        let cidPayload = Data([0x00]) + cid.bytes // Add 0x00 prefix
        // Return the standard CBOR tagged structure using SwiftCBOR's types
        return .tagged(.init(rawValue: cidTagValue), .byteString(cidPayload.map { $0 }))
    }

    /// --- Decoding ---
    public static func decode<T: DAGCBORDecodable>(_ data: Data) throws -> T {
        return try T.decodedFromDAGCBOR(data)
    }

    /// Decode a CBOR item (recursive helper for DAGCBORDecodable extension)
    public static func decodeCBORItem(_ item: CBOR) throws -> Any {
        switch item {
        case let .utf8String(string): return string
        case let .unsignedInt(uint): return uint // Consider conversion to Int if needed
        case let .negativeInt(argument):
            guard argument <= UInt64(Int64.max) else {
                throw DAGCBORError.decodingFailed(
                    "CBOR negative integer argument exceeds the Int64 decoding boundary"
                )
            }
            return -Int64(argument) - 1
        case let .boolean(bool): return bool
        case let .array(array): return try array.map { try decodeCBORItem($0) }
        case let .map(dict):
            var decodedDict = [String: Any]()
            for (key, value) in dict {
                guard case let .utf8String(keyString) = key else { throw DAGCBORError.invalidMapKey }
                decodedDict[keyString] = try decodeCBORItem(value)
            }
            return decodedDict
        case let .byteString(bytes): return Data(bytes)
        case .null: return NSNull()
        case let .tagged(tag, value):
            if tag.rawValue == cidTagValue {
                guard case let .byteString(bytes) = value, bytes.count > 0, bytes[0] == 0x00 else {
                    throw DAGCBORError.invalidCIDEncoding("Tag 42 payload must be bytes starting with 0x00")
                }
                let cidBytes = Data(bytes.dropFirst())
                // Return the raw CID bytes - let the specific type handle parsing if needed
                // OR parse it into a CID struct here if ATProtocolValueContainer expects it
                // Option 1: Return raw bytes
                // return cidBytes
                // Option 2: Return CID struct
                return try CID(bytes: cidBytes)
            } else {
                throw DAGCBORError.unsupportedType("Unsupported CBOR tag: \(tag.rawValue)")
            }
        // Handle unsupported types explicitly
        case .simple, .date, .half, .float, .double, .break, .undefined:
            throw DAGCBORError.unsupportedType(
                "Unsupported CBOR type encountered during decoding: \(item)"
            )
        }
    }
}

// MARK: - ================== Default Protocol Implementations ==================

/// Default implementation of DAGCBOREncodable
public extension DAGCBOREncodable {
    func encodedDAGCBOR() throws -> Data {
        let value = try toCBORValue()
        return try DAGCBOR.encodeValue(value)
    }
}

/// Default implementation for DAGCBORDecodable using standard Decodable
/// Assumes the CBOR decodes to a structure representable as JSON first.
/// Might need customization if direct CBOR -> Struct mapping is required.
public extension DAGCBORDecodable where Self: Decodable {
    static func decodedFromDAGCBOR(_ data: Data) throws -> Self {
        // Ensure data is not empty
        guard !data.isEmpty else {
            throw DAGCBORError.decodingFailed("Cannot decode empty data")
        }
        // Decode the top-level CBOR item
        guard let cborItem = try? CBOR.decode([UInt8](data)) else {
            throw DAGCBORError.decodingFailed("Failed to decode CBOR data. Data: \(data.hexDump())")
        }
        let intermediateValue = try DAGCBOR.decodeCBORItem(cborItem)
        let jsonData = try DAGCBORJSONBridge.jsonData(from: intermediateValue)
        return try JSONDecoder().decode(Self.self, from: jsonData)
    }
}

// MARK: - ================== Base32 ==================

/// Character set for Base32 encoding (RFC 4648, lowercase) - ATProto uses lowercase
private let base32Alphabet = "abcdefghijklmnopqrstuvwxyz234567"
private let base32Lookup: [UInt8: UInt8] = {
    var lookup = [UInt8: UInt8]()
    for (i, char) in base32Alphabet.utf8.enumerated() {
        lookup[char] = UInt8(i)
    }
    return lookup
}()

/// Encodes data to a Base32 string (lowercase, no padding)
public func base32Encode(_ data: Data) -> String {
    var result = ""
    var bits = 0
    var value: UInt32 = 0 // Use UInt32 to avoid overflow during shifts

    for byte in data {
        value = (value << 8) | UInt32(byte)
        bits += 8

        while bits >= 5 {
            bits -= 5
            let index = Int((value >> bits) & 0x1F)
            result.append(
                base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)]
            )
        }
    }

    if bits > 0 {
        let index = Int((value << (5 - bits)) & 0x1F)
        result.append(base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)])
    }

    return result // No padding in ATProto CIDs typically
}

/// Decodes a Base32 string (lowercase or uppercase, no padding) to data
public func base32Decode(_ string: String) -> Data? {
    // Input validation
    guard !string.isEmpty else {
        return nil
    }

    // Validate reasonable length to prevent memory exhaustion attacks
    guard string.count <= 200 else {
        return nil
    }

    // Work with lowercase internally
    let lowercasedString = string.lowercased()
    var result = Data()
    var bits = 0
    var value: UInt32 = 0

    for charCode in lowercasedString.utf8 {
        guard let charValue = base32Lookup[charCode] else {
            return nil // Invalid character
        }

        // Safe bit operations - UInt32 can handle the shifts for valid base32 data
        value = (value << 5) | UInt32(charValue)
        bits += 5

        if bits >= 8 {
            bits -= 8
            let byteValue = UInt8((value >> bits) & 0xFF)
            result.append(byteValue)
        }
    }

    // The check `bits >= 8` handles completion. Any remaining bits < 8 are padding
    // and discarded in unpadded base32 as used by CIDs.

    return result
}

// MARK: - ================== Helpers & Extensions ==================

extension CBOR {
    /// Helper to create CBOR Int/NegativeInt from Swift Int
    static func fromInt(_ value: Int) -> CBOR {
        if value < 0 {
            // Formula from RFC 8949 Section 3.3.1: -1 - value
            return .negativeInt(UInt64(~Int64(value))) // Use bitwise NOT for correct negative mapping
        } else {
            return .unsignedInt(UInt64(value))
        }
    }

    /// Helper to create CBOR Int/NegativeInt from Swift Int64
    static func fromInt64(_ value: Int64) -> CBOR {
        if value < 0 {
            return .negativeInt(UInt64(~value))
        } else {
            return .unsignedInt(UInt64(value))
        }
    }
}

public extension Data {
    /// Dumps data as a formatted hex string for debugging
    func hexDump() -> String {
        let hexChars = Array("0123456789abcdef")
        var result = ""
        result += "Hex dump (\(count) bytes):\n"
        for offset in stride(from: 0, to: count, by: 16) {
            result += String(format: "%08x: ", offset)
            var hexSegment = ""
            var asciiSegment = ""
            for byteIndex in 0 ..< 16 {
                if offset + byteIndex < count {
                    let byte = self[offset + byteIndex]
                    hexSegment += String(hexChars[Int(byte >> 4)]) + String(hexChars[Int(byte & 0x0F)]) + " "
                    if byteIndex == 7 { hexSegment += " " } // Add extra space in middle
                    asciiSegment += (0x20 ... 0x7E).contains(byte) ? String(UnicodeScalar(byte)) : "."
                } else {
                    hexSegment += "   "
                    if byteIndex == 7 { hexSegment += " " }
                    asciiSegment += " "
                }
            }
            result += "\(hexSegment) |\(asciiSegment)|\n"
        }
        return result
    }
}
