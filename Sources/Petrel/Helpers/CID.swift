// File: ATProtoCBOREncoding.swift
// Description: Implements CID handling and canonical DAG-CBOR encoding
//              according to AT Protocol specifications.

import CryptoKit
import Foundation
import SwiftCBOR

// MARK: - ================== Core Protocols ==================

// Basic interface for DAG-CBOR encoding
public protocol DAGCBOREncodable {
    func toCBORValue() throws -> Any
    func encodedDAGCBOR() throws -> Data
}

// Basic interface for DAG-CBOR decoding
public protocol DAGCBORDecodable {
    static func decodedFromDAGCBOR(_ data: Data) throws -> Self
}

// Protocol for types that can be encoded to and decoded from DAG-CBOR
public typealias DAGCBORCodable = DAGCBORDecodable & DAGCBOREncodable

// Error types for DAG-CBOR operations
public enum DAGCBORError: Error {
    case encodingFailed(String)
    case decodingFailed(String)
    case unsupportedType(String)
    case invalidCIDEncoding(String)
    case invalidMapKey
    case floatingPointNotAllowed
}

// MARK: - ================== CIDAsLink Wrapper ==================

/// Wrapper struct to indicate when a CID should use Tag 42 encoding
struct CIDAsLink {
    let cid: CID
}

// MARK: - ================== CID Implementation ==================

/// Represents the codec type for Content Identifiers
public enum CIDCodec: UInt8, ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? CIDCodec else { return false }
        return self == other
    }

    public func toCBORValue() throws -> Any { return rawValue }

    case dagCBOR = 0x71
    case raw = 0x55
    var name: String { self == .dagCBOR ? "dag-cbor" : "raw" }
}

/// Represents a multihash structure as used in IPFS and AT Protocol
public struct Multihash: ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Multihash else { return false }
        return algorithm == other.algorithm && length == other.length && digest == other.digest
    }

    public func toCBORValue() throws -> Any { return bytes }

    static let sha256Code: UInt8 = 0x12
    static let sha256Length: UInt8 = 0x20 // 32 bytes

    let algorithm: UInt8
    let length: UInt8
    let digest: Data

    var bytes: Data { Data([algorithm, length]) + digest }

    static func sha256(_ data: Data) -> Multihash {
        Multihash(
            algorithm: sha256Code,
            length: sha256Length,
            digest: Data(SHA256.hash(data: data))
        )
    }
}

// MARK: $link

public struct ATProtoLink: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
    // Store the actual CID object
    public let cid: CID

    // JSON Coding Keys
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
        cid = try CID.parse(cidString)
    }

    // --- Codable Conformance ---

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cidString = try container.decode(String.self, forKey: .cidString)
        // Parse the string into the internal CID struct during decoding
        cid = try CID.parse(cidString)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode back to the string representation for JSON compatibility
        try container.encode(cid.string, forKey: .cidString)
    }

    // --- ATProtocolValue / Equatable / Hashable Conformance ---

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherLink = other as? ATProtoLink else { return false }
        return cid == otherLink.cid // Compare contained CIDs
    }

    public static func == (lhs: ATProtoLink, rhs: ATProtoLink) -> Bool {
        return lhs.cid == rhs.cid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cid)
    }

    // --- DAGCBOREncodable Conformance ---

    /// **IMPORTANT:** For DAG-CBOR, a CID struct needs to encode differently based on context:
    /// - When used in a data model like StrongRef, it should encode as a simple string
    /// - When used through ATProtoLink, it needs Tag 42 encoding
    public func toCBORValue() throws -> Any {
        return CIDAsLink(cid: cid) // Use the wrapper to signal Tag 42 encoding
    }
}

/// Content Identifier (CID) implementation for AT Protocol (v1, SHA-256)
public struct CID: Equatable, Hashable, Codable, CustomStringConvertible, ATProtocolValue {
    static let version: UInt8 = 0x01
    let codec: CIDCodec
    let multihash: Multihash

    public init(codec: CIDCodec, multihash: Multihash) {
        self.codec = codec
        self.multihash = multihash
    }

    /// Returns the full binary representation of the CID (version + codec + multihash)
    public var bytes: Data { Data([CID.version, codec.rawValue]) + multihash.bytes }

    /// Returns the base32 string representation (e.g., "bafy...")
    public var string: String { "b" + base32Encode(bytes).lowercased() }
    public var description: String { string }

    /// Creates a CID by hashing DAG-CBOR encoded data
    public static func fromDAGCBOR(_ cborData: Data) -> CID {
        CID(codec: .dagCBOR, multihash: Multihash.sha256(cborData))
    }

    /// Creates a CID by hashing raw blob data
    public static func fromBlob(_ blobData: Data) -> CID {
        CID(codec: .raw, multihash: Multihash.sha256(blobData))
    }

    // --- Parsing ---
    public enum CIDParseError: Error {
        case invalidPrefix(String)
        case invalidBase32Encoding, insufficientLength
        case
            invalidVersion(UInt8)
        case unsupportedCodec(UInt8)
        case invalidHashAlgorithm(UInt8, UInt8)
    }

    public static func parse(_ cidString: String) throws -> CID {
        guard cidString.hasPrefix("b") else { throw CIDParseError.invalidPrefix("Requires 'b' prefix") }
        let base32Part = String(cidString.dropFirst())
        guard let cidBytes = base32Decode(base32Part.uppercased()) else {
            throw CIDParseError.invalidBase32Encoding
        }
        return try CID(bytes: cidBytes)
    }

    /// Initialize CID from its raw binary representation (version + codec + multihash)
    init(bytes cidBytes: Data) throws {
        guard cidBytes.count >= 4 else { throw CIDParseError.insufficientLength }
        guard cidBytes[0] == CID.version else { throw CIDParseError.invalidVersion(cidBytes[0]) }
        guard let codec = CIDCodec(rawValue: cidBytes[1]) else {
            throw CIDParseError.unsupportedCodec(cidBytes[1])
        }

        let hashAlgorithm = cidBytes[2]
        let hashLength = cidBytes[3]
        let digestStart = 4
        guard cidBytes.count == digestStart + Int(hashLength) else {
            throw CIDParseError.insufficientLength
        }
        let digest = cidBytes.suffix(from: digestStart)

        self.codec = codec
        multihash = Multihash(algorithm: hashAlgorithm, length: hashLength, digest: Data(digest))

        // Optional: Verify hash algorithm matches expected (e.g., SHA-256 for ATP)
        guard hashAlgorithm == Multihash.sha256Code && hashLength == Multihash.sha256Length else {
            // Allow parsing, but maybe log a warning if it's not the 'blessed' format
            print(
                "Warning: Parsed CID uses non-standard hash algorithm/length for ATProto: \(hashAlgorithm)/\(hashLength)"
            )
            // Alternatively, throw: throw CIDParseError.invalidHashAlgorithm(hashAlgorithm, hashLength)
            return
        }
    }

    // --- Codable Conformance ---
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cidString = try container.decode(String.self)
        self = try CID.parse(cidString)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    // --- ATProtocolValue Conformance ---
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? CID else { return false }
        return self == other
    }

    // --- DAGCBOREncodable Conformance ---
    /// **IMPORTANT:** For DAG-CBOR, a CID struct itself signals it should be encoded
    /// using Tag 42 *when it's the value being processed* (e.g., returned by ATProtoLink.toCBORValue).
    /// It should NOT be encoded this way when it's just a string value within another structure (like StrongRef).
    public func toCBORValue() throws -> Any {
        return self // Return the struct itself
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

        // 2. Encode the CBOR enum representation into bytes.
        //    Use the canonical map encoder for maps, otherwise use SwiftCBOR's encoder.
        if case let .map(dict) = cborItem {
            // Ensure dictionary is [CBOR: CBOR] as expected by encodeCanonicalMap
            guard let cborMap = dict as? [CBOR: CBOR] else {
                throw DAGCBORError.encodingFailed("Internal error: Map conversion failed.")
            }
            print("DEBUG: encodeValue directing to encodeCanonicalMap")
            return try encodeCanonicalMap(cborMap)
        } else {
            // For non-maps (strings, ints, arrays, TAGGED CIDs), use SwiftCBOR's encode.
            // Assuming SwiftCBOR encodes these canonically (especially tags).
            let options = CBOROptions() // Use defaults - SwiftCBOR should handle minimal encoding
            print("DEBUG: encodeValue using SwiftCBOR.encode for non-map type: \(cborItem)")
            let bytes = CBOR.encode(cborItem, options: options) // Use SwiftCBOR's encoding for primitives and tags
            return Data(bytes)
        }
    }

    // --- Canonical Map Encoding ---
    private static func encodeCanonicalMap(_ map: [CBOR: CBOR]) throws -> Data {
        // 1. Extract keys and sort (Length then Lexicographical)
        var keyPairs: [(key: CBOR, utf8Bytes: Data, value: CBOR)] = []
        for (key, value) in map {
            print("DEBUG encodeCanonicalMap: Processing key type: \(type(of: key)), raw: \(key)")
            guard case let .utf8String(keyString) = key else {
                print("ERROR: Invalid map key type: \(type(of: key)), raw: \(key)")
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

        // Log sorted order
        print("DEBUG: encodeCanonicalMap - Final sorted key order:")
        for pair in keyPairs {
            print("  - '\(String(data: pair.utf8Bytes, encoding: .utf8) ?? "?")'")
        }

        // 3. Create map header (using minimal encoding based on count)
        var result = Data()
        let count = map.count
        let mapHeaderBase: UInt8 = 0xA0 // Map type indicator

        // Use Int values corresponding to max boundaries for comparison
        let uInt8MaxAsInt = Int(UInt8.max) // 255
        let uInt16MaxAsInt = Int(UInt16.max) // 65535
        let uInt32MaxAsInt = Int(UInt32.max) // 4294967295

        switch count {
        case 0 ..< 24:
            result.append(mapHeaderBase + UInt8(count)) // Map(0-23)
        case 24 ... uInt8MaxAsInt: // Use Int range check
            result.append(0xB8) // Map(1) - Major type 5, add info 24
            result.append(UInt8(count))
        case (uInt8MaxAsInt + 1) ... uInt16MaxAsInt: // Use Int range check
            result.append(0xB9) // Map(2) - Major type 5, add info 25
            var countBE = UInt16(count).bigEndian
            result.append(Data(bytes: &countBE, count: MemoryLayout<UInt16>.size))
        case (uInt16MaxAsInt + 1) ... uInt32MaxAsInt: // Use Int range check
            result.append(0xBA) // Map(4) - Major type 5, add info 26
            var countBE = UInt32(count).bigEndian
            result.append(Data(bytes: &countBE, count: MemoryLayout<UInt32>.size))
        default: // Count exceeds UInt32.max, up to UInt64.max
            // Check if count fits in UInt64 before proceeding
            guard count >= 0 else { // Should not happen for map.count but good practice
                throw DAGCBORError.encodingFailed("Invalid map count")
            }
            result.append(0xBB) // Map(8) - Major type 5, add info 27
            var countBE = UInt64(count).bigEndian
            result.append(Data(bytes: &countBE, count: MemoryLayout<UInt64>.size))
        }
        print("DEBUG: encodeCanonicalMap wrote map header for \(count) items.")

        // 4. Add sorted key-value pairs, using recursive encodeValue for values
        let keyEncodingOptions = CBOROptions() // Defaults for simple string keys
        for pair in keyPairs {
            // Encode the key (always a UTF8 string here)
            let keyBytes = pair.key.encode(options: keyEncodingOptions)
            result.append(contentsOf: keyBytes)

            // **CRITICAL:** Recursively call `encodeValue` for the value.
            // This ensures nested maps use this canonical encoder, and non-maps
            // (including tagged CIDs) are handled by the main `encodeValue` logic,
            // which ultimately uses `SwiftCBOR.CBOR.encode`.
            print(
                "DEBUG: encodeCanonicalMap encoding value for key '\(String(data: pair.utf8Bytes, encoding: .utf8) ?? "???")' using encodeValue"
            )
            let valueAny = try decodeCBORItem(pair.value) // Convert CBOR enum back to intermediate Swift type (needed for encodeValue)
            let valueBytes = try encodeValue(valueAny) // Let encodeValue handle recursion / final encoding of the value
            result.append(contentsOf: valueBytes)
        }
        print("DEBUG: encodeCanonicalMap finished encoding map.")
        return result
    }

    // --- Swift Value -> CBOR Enum Conversion ---
    private static func convertToCBORItem(_ value: Any) throws -> CBOR {
        print("DEBUG convertToCBORItem: Converting type: \(type(of: value))")
        switch value {
        // Handle ATProtoLink by using its toCBORValue method
        case let link as ATProtoLink:
            print("DEBUG convertToCBORItem: Detected ATProtoLink")
            return try convertToCBORItem(link.toCBORValue())
        // NEW CASE: Handle the CIDAsLink wrapper - this is the Tag 42 path
        case let cidLink as CIDAsLink:
            print("DEBUG convertToCBORItem: Processing CID as Link (Tag 42)")
            return try encodeCIDLinkForCBOR(cidLink.cid)
        // CID struct now encodes as a string by default
        case let cid as CID:
            print("DEBUG convertToCBORItem: Converting CID to string representation")
            return CBOR.utf8String(cid.string)
        // Other cases remain the same...
        case let orderedMap as OrderedCBORMap:
            print(
                "DEBUG convertToCBORItem: Processing OrderedCBORMap with \(orderedMap.entries.count) entries."
            )
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
            print("DEBUG convertToCBORItem: Processing array with \(array.count) items.")
            var cborArray = [CBOR]()
            for (index, item) in array.enumerated() {
                print("DEBUG convertToCBORItem:   Array item \(index) type: \(type(of: item))")
                try cborArray.append(convertToCBORItem(item)) // Recursive call
            }
            return .array(cborArray)
        // Handle standard Dictionaries (less common if using OrderedCBORMap)
        case let dict as [String: Any]:
            print("DEBUG convertToCBORItem: Processing dictionary with \(dict.count) entries.")
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
            print("ERROR: Floating point number encountered.")
            throw DAGCBORError.floatingPointNotAllowed
        // Default: Check for other DAGCBOREncodable types
        default:
            if let encodableValue = value as? DAGCBOREncodable {
                print(
                    "DEBUG convertToCBORItem: Value conforms to DAGCBOREncodable, calling its toCBORValue(). Type: \(type(of: value))"
                )
                let intermediateValue = try encodableValue.toCBORValue()
                print(
                    "DEBUG convertToCBORItem: Intermediate value type from toCBORValue: \(type(of: intermediateValue))"
                )
                // Recursively call with the result (e.g., if ATProtoDate.toCBORValue returns a String)
                return try convertToCBORItem(intermediateValue)
            } else {
                // Truly unsupported type
                print("ERROR: Unsupported type encountered in convertToCBORItem: \(type(of: value))")
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

    // --- Decoding ---
    public static func decode<T: DAGCBORDecodable>(_ data: Data) throws -> T {
        return try T.decodedFromDAGCBOR(data)
    }

    /// Decode a CBOR item (recursive helper for DAGCBORDecodable extension)
    public static func decodeCBORItem(_ item: CBOR) throws -> Any {
        print("DEBUG decodeCBORItem: Decoding item: \(item)")
        switch item {
        case let .utf8String(string): return string
        case let .unsignedInt(uint): return uint // Consider conversion to Int if needed
        case let .negativeInt(uint): return -Int64(uint) - 1
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
        case .null: return nil as Any?
        case let .tagged(tag, value):
            if tag.rawValue == cidTagValue {
                print("DEBUG decodeCBORItem: Decoding Tag 42")
                guard case let .byteString(bytes) = value, bytes.count > 0, bytes[0] == 0x00 else {
                    throw DAGCBORError.invalidCIDEncoding("Tag 42 payload must be bytes starting with 0x00")
                }
                let cidBytes = Data(bytes.dropFirst())
                // Return the raw CID bytes - let the specific type handle parsing if needed
                // OR parse it into a CID struct here if ATProtoValueContainer expects it
                print("DEBUG decodeCBORItem: Decoded CID bytes (len \(cidBytes.count)) from Tag 42")
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
                "Unsupported CBOR type encountered during decoding: \(item)")
        }
    }
}

// MARK: - ================== Default Protocol Implementations ==================

// Default implementation of DAGCBOREncodable
public extension DAGCBOREncodable {
    func encodedDAGCBOR() throws -> Data {
        let value = try toCBORValue()
        return try DAGCBOR.encodeValue(value)
    }
}

// Default implementation for DAGCBORDecodable using standard Decodable
// Assumes the CBOR decodes to a structure representable as JSON first.
// Might need customization if direct CBOR -> Struct mapping is required.
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

        // Attempt to convert intermediate Swift type back to JSON Data
        let jsonData: Data
        if JSONSerialization.isValidJSONObject(intermediateValue) {
            // Handles cases where intermediateValue is [String: Any] or [Any]
            jsonData = try JSONSerialization.data(withJSONObject: intermediateValue, options: [])
        } else {
            print(
                "Warning: Decoded CBOR item is not standard JSON object/array, attempting direct encoding.")
            // Check if the primitive value itself conforms to Encodable
            if let encodablePrimitive = intermediateValue as? Encodable {
                // This covers String, Int, UInt, Bool, Double, potentially Data if needed, etc.
                // It also correctly handles Optional<Encodable>.none (nil)
                jsonData = try JSONEncoder().encode(encodablePrimitive)
            }
            // else if intermediateValue == nil { // Handled by Optional<Encodable> above
            //    jsonData = Data("null".utf8) // Explicitly handle null if necessary
            // }
            else {
                // If it's not a valid JSON object/array and not directly Encodable, we can't use JSONDecoder
                throw DAGCBORError.decodingFailed(
                    "Decoded CBOR root value cannot be represented as JSON for Decodable conformance. Value Type: \(type(of: intermediateValue))"
                )
            }
        }

        // Use JSONDecoder to decode the target Decodable type from the JSON data
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
                base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)])
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
    // Work with lowercase internally
    let lowercasedString = string.lowercased()
    var result = Data()
    var bits = 0
    var value: UInt32 = 0

    for charCode in lowercasedString.utf8 {
        guard let charValue = base32Lookup[charCode] else {
            return nil // Invalid character
        }

        value = (value << 5) | UInt32(charValue)
        bits += 5

        if bits >= 8 {
            bits -= 8
            result.append(UInt8((value >> bits) & 0xFF))
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
