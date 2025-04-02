//
//  ATProtoTypes.swift
//
//
//  Created by Josh LaCalamito on 11/30/23.
//

import Foundation
import SwiftCBOR

public protocol ATProtocolCodable: Codable, DAGCBORCodable, Sendable {}

public protocol ATProtocolValue: ATProtocolCodable, Equatable, Hashable, PendingDataLoadable {
    func isEqual(to other: any ATProtocolValue) -> Bool
}

public enum ATProtocolError: Error {
    case invalidURI(String)
    case invalidTID(String)
}

// MARK: URIs

public struct ATProtocolURI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    
    public let authority: String
    public let collection: String?
    public let recordKey: String?

    // Store the original string to avoid recomputing
    private let originalString: String

    public init(from decoder: Decoder) throws {
        // Use a simpler direct approach to avoid complex decoder internals
        let container = try decoder.singleValueContainer()
        let uriString = try container.decode(String.self)

        // Store original string
        originalString = uriString

        // Parse in a very straightforward way with minimal allocations
        guard uriString.hasPrefix("at://") else {
            throw ATProtocolError.invalidURI("Invalid AT URI format")
        }

        // Use simple string manipulation
        let parts = uriString.dropFirst(5).split(separator: "/", omittingEmptySubsequences: false)

        guard !parts.isEmpty else {
            throw ATProtocolError.invalidURI("Invalid AT URI: missing authority")
        }

        authority = String(parts[0])
        collection = parts.count > 1 ? (parts[1].isEmpty ? nil : String(parts[1])) : nil
        recordKey = parts.count > 2 ? (parts[2].isEmpty ? nil : String(parts[2])) : nil
    }

    public init(uriString: String) throws {
        originalString = uriString

        guard uriString.hasPrefix("at://"),
              uriString.utf8.count <= 8192
        else {
            throw ATProtocolError.invalidURI("Invalid AT URI format or length")
        }

        let trimmedString = String(uriString.dropFirst(5)) // Remove "at://"
        let components = trimmedString.split(separator: "/", omittingEmptySubsequences: false)

        guard !components.isEmpty, !components[0].isEmpty else {
            throw ATProtocolError.invalidURI("Invalid AT URI: missing or empty authority")
        }

        authority = String(components[0])
        collection = components.count > 1 ? (components[1].isEmpty ? nil : String(components[1])) : nil
        recordKey = components.count > 2 ? (components[2].isEmpty ? nil : String(components[2])) : nil
    }

    public var description: String {
        return uriString()
    }

    public func uriString() -> String {
        // Return the original string if we have it
        return originalString
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherURI = other as? ATProtocolURI else {
            return false
        }

        return authority == otherURI.authority && collection == otherURI.collection
            && recordKey == otherURI.recordKey
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uriString())
    }

    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: uriString())
    }

    public func toCBORValue() throws -> Any {
        return uriString()
    }
}

/*
 public struct ATProtocolURI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
     public let authority: String
     public let collection: String?
     public let recordKey: String?

     public init(from decoder: Decoder) throws {
         let container = try decoder.singleValueContainer()
         let uriString = try container.decode(String.self)

         try self.init(uriString: uriString)
     }

     public init(uriString: String) throws {
         guard uriString.hasPrefix("at://"),
               uriString.utf8.count <= 8192
         else {
             throw ATProtocolError.invalidURI("Invalid AT URI format or length")
         }

         let trimmedString = String(uriString.dropFirst(5)) // Remove "at://"
         let components = trimmedString.components(separatedBy: "/").filter { !$0.isEmpty }

         guard let authorityComponent = components.first,
               !authorityComponent.isEmpty
         else {
             throw ATProtocolError.invalidURI("Invalid AT URI: missing or empty authority")
         }

         authority = authorityComponent
         collection = components.count > 1 ? components[1] : nil
         recordKey = components.count > 2 ? components[2] : nil
     }

     public var description: String {
         return uriString()
     }

     public func uriString() -> String {
         var uri = "at://\(authority)"
         if let collection = collection {
             uri += "/\(collection)"
         }
         if let recordKey = recordKey {
             uri += "/\(recordKey)"
         }
         return uri
     }

     public func isEqual(to other: any ATProtocolValue) -> Bool {
         guard let otherURI = other as? ATProtocolURI else {
             return false
         }

         return authority == otherURI.authority && collection == otherURI.collection
             && recordKey == otherURI.recordKey
     }

     public func encode(to encoder: Encoder) throws {
         var container = encoder.singleValueContainer()
         let uriString = self.uriString()
         try container.encode(uriString)
     }

     func asQueryItem(name: String) -> URLQueryItem? {
         return URLQueryItem(name: name, value: uriString())
     }
 }

 */

public struct URI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible,
    ExpressibleByStringLiteral
{
    public let scheme: String
    public let authority: String
    public let path: String?
    public let query: String?
    public let fragment: String?
    public let isDID: Bool

    enum URIError: Error {
        case invalidScheme
        case invalidURI
        case invalidDID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uriString = try container.decode(String.self)

        if uriString.starts(with: "did:") {
            isDID = true
            let components = uriString.split(separator: ":")
            guard components.count >= 3 else {
                throw URIError.invalidDID
            }
            scheme = String(components[0])
            authority = String(components[1])
            path = components.dropFirst(2).joined(separator: ":")
            query = nil
            fragment = nil
        } else {
            isDID = false
            let urlComponents = URLComponents(string: uriString)
            scheme = urlComponents?.scheme ?? ""
            authority = urlComponents?.host ?? ""
            path = urlComponents?.path.isEmpty ?? true ? nil : urlComponents?.path
            query = urlComponents?.query
            fragment = urlComponents?.fragment
        }
    }

    init(uriString: String) {
        if uriString.starts(with: "did:") {
            isDID = true
            let components = uriString.split(separator: ":")
            scheme = "did"
            authority = String(components[1])
            path = components.count > 2 ? components.dropFirst(2).joined(separator: ":") : nil
            query = nil
            fragment = nil
        } else {
            isDID = false
            let urlComponents = URLComponents(string: uriString)
            let defaultScheme = "https"
            scheme = urlComponents?.scheme ?? defaultScheme
            authority = urlComponents?.host ?? ""
            path = urlComponents?.path.isEmpty ?? true ? nil : urlComponents?.path
            query = urlComponents?.query
            fragment = urlComponents?.fragment
        }
    }

    func isValid() -> Bool {
        if isDID {
            return scheme == "did" && !authority.isEmpty
        } else {
            return !scheme.isEmpty && !authority.isEmpty
        }
    }

    func asQueryItem(name: String) -> URLQueryItem? {
        guard isValid() else {
            return nil
        }
        return URLQueryItem(name: name, value: uriString())
    }

    public func uriString() -> String {
        if isDID {
            var didString = "did:\(authority)"
            if let path = path {
                didString += ":\(path)"
            }
            return didString
        } else {
            var components = URLComponents()
            components.scheme = scheme.isEmpty ? nil : scheme
            components.host = authority
            components.path = path ?? ""
            components.query = query
            components.fragment = fragment
            return components.string ?? "invalid-uri"
        }
    }

    // Initializer to create URI from URL
    public init(url: URL) {
        isDID = false
        scheme = url.scheme ?? "https"
        authority = url.host ?? ""
        path = url.path.isEmpty ? nil : url.path
        query = url.query
        fragment = url.fragment
    }

    // Computed property to get URL from URI
    public var url: URL? {
        guard !isDID else { return nil }
        var components = URLComponents()
        components.scheme = scheme.isEmpty ? nil : scheme
        components.host = authority
        components.path = path ?? ""
        components.query = query
        components.fragment = fragment
        return components.url
    }

    public init(stringLiteral value: String) {
        self.init(uriString: value)
    }

    public init?(_ description: String) {
        self.init(uriString: description)
    }

    public var description: String {
        return uriString()
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherURI = other as? URI else {
            return false
        }
        return scheme == otherURI.scheme && authority == otherURI.authority && path == otherURI.path
            && query == otherURI.query && fragment == otherURI.fragment && isDID == otherURI.isDID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let uriString = self.uriString()
        try container.encode(uriString)
    }

    public func toCBORValue() throws -> Any {
        return uriString()
    }
}

// MARK: Blob

public struct Blob: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
    public let type: String
    public let ref: ATProtoLink?
    public let mimeType: String
    public let size: Int
    public let cid: String?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case ref
        case mimeType
        case size
        case cid
    }

    public init(
        type: String, ref: ATProtoLink? = nil, mimeType: String, size: Int, cid: String? = nil
    ) {
        self.type = type
        self.ref = ref
        self.mimeType = mimeType
        self.size = size
        self.cid = cid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        ref = try container.decodeIfPresent(ATProtoLink.self, forKey: .ref)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        size = try container.decode(Int.self, forKey: .size)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(ref, forKey: .ref)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(cid, forKey: .cid)
    }

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherBlob = other as? Blob else { return false }
        return self == otherBlob
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(ref)
        hasher.combine(mimeType)
        hasher.combine(size)
        hasher.combine(cid)
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: type) // Assuming 'type' holds the lexicon identifier like "blob"

        if let refLink = ref {
            let refValue = try refLink.toCBORValue()
            map = map.adding(key: "ref", value: refValue)
        }

        map = map.adding(key: "mimeType", value: mimeType)
        map = map.adding(key: "size", value: size)

        if let cidValue = cid {
            map = map.adding(key: "cid", value: cidValue)
        }

        return map
    }
}

// public struct ATProtoLink: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
//  public let cid: String
//
//  enum CodingKeys: String, CodingKey {
//    case cid = "$link"
//  }
//
//  public init(cid: String) {
//    self.cid = cid
//  }
//
//  public init(from decoder: Decoder) throws {
//    let container = try decoder.container(keyedBy: CodingKeys.self)
//    cid = try container.decode(String.self, forKey: .cid)
//  }
//
//  public func encode(to encoder: Encoder) throws {
//    var container = encoder.container(keyedBy: CodingKeys.self)
//    try container.encode(cid, forKey: .cid)
//  }
//
//  public func hash(into hasher: inout Hasher) {
//    hasher.combine(cid)
//  }
//
//  public func isEqual(to other: any ATProtocolCodable) -> Bool {
//    guard let otherLink = other as? ATProtoLink else { return false }
//    return self == otherLink
//  }
//
//  public func toCBORValue() throws -> Any {
//    var map = OrderedCBORMap()
//    map = map.adding(key: "$link", value: self.cid)
//    return map
//  }
// }

// MARK: $bytes

public struct Bytes: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
    public let data: Data

    enum CodingKeys: String, CodingKey {
        case data = "$bytes"
    }

    public init(data: Data) {
        self.data = data
    }

    public init?(string: String) {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base64String = try container.decode(String.self, forKey: .data)
        guard let data = Data(base64Encoded: base64String) else {
            throw DecodingError.dataCorruptedError(
                forKey: .data,
                in: container,
                debugDescription: "Base64 string could not be decoded"
            )
        }
        self.data = data
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let base64String = data.base64EncodedString()
        try container.encode(base64String, forKey: .data)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherBytes = other as? Bytes else { return false }
        return self == otherBytes
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        // Bytes should be encoded directly as CBOR bytes, not base64 string in a map
        return data
    }
}

// MARK: - DID Identifier

public struct DID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let method: String
    public let authority: String
    public let segments: [String]
    private let originalString: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let didString = try container.decode(String.self)
        try self.init(didString: didString)
    }

    public init(didString: String) throws {
        originalString = didString

        guard didString.hasPrefix("did:"),
              didString.utf8.count <= 8192
        else {
            throw ATProtocolError.invalidURI("Invalid DID format or length")
        }

        let components = didString.dropFirst(4).split(separator: ":", omittingEmptySubsequences: false)

        guard !components.isEmpty, !components[0].isEmpty else {
            throw ATProtocolError.invalidURI("Invalid DID: missing or empty method")
        }

        method = String(components[0])

        guard components.count > 1, !components[1].isEmpty else {
            throw ATProtocolError.invalidURI("Invalid DID: missing or empty authority")
        }

        authority = String(components[1])
        segments = components.count > 2 ? components.dropFirst(2).map { String($0) } : []
    }

    public var description: String {
        return originalString
    }

    public func didString() -> String {
        var didString = "did:\(method):\(authority)"
        if !segments.isEmpty {
            didString += ":" + segments.joined(separator: ":")
        }
        return didString
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherDID = other as? DID else {
            return false
        }

        return method == otherDID.method && authority == otherDID.authority
            && segments == otherDID.segments
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(didString())
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: didString())
    }

    public var hasPendingData: Bool { return false }

    public mutating func loadPendingData() async {}

    public func hash(into hasher: inout Hasher) {
        hasher.combine(method)
        hasher.combine(authority)
        hasher.combine(segments)
    }

    public func toCBORValue() throws -> Any {
        return didString()
    }
}

// MARK: - Handle Identifier

public struct Handle: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let value: String

    private static let handlePattern =
        "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))+$"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let handleString = try container.decode(String.self)
        try self.init(handleString: handleString)
    }

    public init(handleString: String) throws {
        guard Handle.isValidHandle(handleString) else {
            throw ATProtocolError.invalidURI("Invalid handle format: \(handleString)")
        }

        value = handleString
    }

    private static func isValidHandle(_ handle: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: handlePattern) else {
            return false
        }

        let range = NSRange(location: 0, length: handle.utf16.count)
        return regex.firstMatch(in: handle, options: [], range: range) != nil
    }

    public var description: String {
        return value
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherHandle = other as? Handle else {
            return false
        }

        return value.lowercased() == otherHandle.value.lowercased()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: value)
    }

    public var hasPendingData: Bool { return false }

    public mutating func loadPendingData() async {}

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value.lowercased())
    }

    public func toCBORValue() throws -> Any {
        return value
    }
}

// MARK: - AT Identifier (either Handle or DID)

public enum ATIdentifier: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: stringValue())
    }

    case did(DID)
    case handle(Handle)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        if string.starts(with: "did:") {
            self = try .did(DID(didString: string))
        } else {
            self = try .handle(Handle(handleString: string))
        }
    }

    public init(string: String) throws {
        if string.starts(with: "did:") {
            self = try .did(DID(didString: string))
        } else {
            self = try .handle(Handle(handleString: string))
        }
    }

    public var description: String {
        switch self {
        case let .did(did):
            return did.description
        case let .handle(handle):
            return handle.description
        }
    }

    public func stringValue() -> String {
        switch self {
        case let .did(did):
            return did.didString()
        case let .handle(handle):
            return handle.value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Just encode the string value directly
        try container.encode(stringValue())
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherIdentifier = other as? ATIdentifier else {
            return false
        }

        switch (self, otherIdentifier) {
        case let (.did(did1), .did(did2)):
            return did1 == did2
        case let (.handle(handle1), .handle(handle2)):
            return handle1 == handle2
        default:
            return false
        }
    }

    // Add support for DAG-CBOR encoding
    public func toCBORValue() throws -> Any {
        return stringValue()
    }
}

// MARK: - NSID (Namespaced Identifier)

public struct NSID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let authority: String
    public let name: String

    private static let nsidPattern =
        "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))+\\.[a-zA-Z][a-zA-Z0-9]{0,62}$"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let nsidString = try container.decode(String.self)
        try self.init(nsidString: nsidString)
    }

    public init(nsidString: String) throws {
        guard NSID.isValidNSID(nsidString) else {
            throw ATProtocolError.invalidURI("Invalid NSID format: \(nsidString)")
        }

        let components = nsidString.split(separator: ".")
        name = String(components.last ?? "")
        authority = components.dropLast().joined(separator: ".")
    }

    private static func isValidNSID(_ nsid: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: nsidPattern) else {
            return false
        }

        let range = NSRange(location: 0, length: nsid.utf16.count)
        return regex.firstMatch(in: nsid, options: [], range: range) != nil
    }

    public var description: String {
        return "\(authority).\(name)"
    }

    public func nsidString() -> String {
        return "\(authority).\(name)"
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherNSID = other as? NSID else {
            return false
        }

        return authority.lowercased() == otherNSID.authority.lowercased()
            && name.lowercased() == otherNSID.name.lowercased()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(nsidString())
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: nsidString())
    }

    public var hasPendingData: Bool { return false }

    public mutating func loadPendingData() async {}

    public func hash(into hasher: inout Hasher) {
        hasher.combine(authority.lowercased())
        hasher.combine(name.lowercased())
    }

    public func toCBORValue() throws -> Any {
        return nsidString()
    }
}

// MARK: - Record Key

public struct RecordKey: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let value: String

    // Pattern for "any" record key format
    private static let recordKeyPattern = "^[a-zA-Z0-9\\-_.:%]+$"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let keyString = try container.decode(String.self)
        try self.init(keyString: keyString)
    }

    public init(keyString: String) throws {
        guard RecordKey.isValidRecordKey(keyString) else {
            throw ATProtocolError.invalidURI("Invalid record key format: \(keyString)")
        }

        value = keyString
    }

    private static func isValidRecordKey(_ key: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: recordKeyPattern) else {
            return false
        }

        let range = NSRange(location: 0, length: key.utf16.count)
        return regex.firstMatch(in: key, options: [], range: range) != nil
    }

    public var description: String {
        return value
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherKey = other as? RecordKey else {
            return false
        }

        return value == otherKey.value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: value)
    }

    public var hasPendingData: Bool { return false }

    public mutating func loadPendingData() async {}

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    public func toCBORValue() throws -> Any {
        return value
    }
}

public struct TID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible, Comparable {
    // Timestamp in microseconds since epoch
    private let timestamp: UInt64
    // Clock ID plus counter
    private let clockId: UInt64
    // Original string representation
    private let originalString: String

    // Base32 sortable character set
    private static let base32Chars = "234567abcdefghijklmnopqrstuvwxyz"

    // Fixed length of TID strings
    private static let TID_LENGTH = 13

    // Valid first characters (first half of base32 chars)
    private static let validFirstChars = "234567abcdefghij"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let tidString = try container.decode(String.self)

        try self.init(tidString: tidString)
    }

    public init(tidString: String) throws {
        // Validate TID format
        guard tidString.count == Self.TID_LENGTH else {
            throw ATProtocolError.invalidURI("Invalid TID string format: must be exactly 13 characters")
        }

        // Validate characters (must be in base32 sortable charset)
        for char in tidString {
            if !Self.base32Chars.contains(char) {
                throw ATProtocolError.invalidURI("Invalid TID string format: contains invalid characters")
            }
        }

        // Validate first character (must be 2-j)
        guard let firstChar = tidString.first,
              Self.validFirstChars.contains(firstChar)
        else {
            throw ATProtocolError.invalidURI(
                "Invalid TID string format: first character must be in 234567abcdefghij")
        }

        // Decode TID value
        let tidValue = Self.decode(tidString)

        // Extract timestamp and clock ID
        // 53 bits for timestamp, 10 bits for clock ID
        timestamp = (tidValue >> 10) & 0x1F_FFFF_FFFF_FFFF
        clockId = tidValue & 0x3FF
        originalString = tidString
    }

    // Decode a base32 string to a number
    private static func decode(_ str: String) -> UInt64 {
        var result: UInt64 = 0

        for char in str {
            if let index = base32Chars.firstIndex(of: char) {
                let value = base32Chars.distance(from: base32Chars.startIndex, to: index)
                result = result * 32 + UInt64(value)
            }
        }

        return result
    }

    public var description: String {
        return originalString
    }

    public func toString() -> String {
        return originalString
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherTID = other as? TID else {
            return false
        }

        return timestamp == otherTID.timestamp && clockId == otherTID.clockId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(originalString)
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: originalString)
    }

    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1_000_000.0)
    }

    public var hasPendingData: Bool { return false }

    public mutating func loadPendingData() async {}

    public func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(clockId)
    }

    // Comparable implementation for sorting
    public static func < (lhs: TID, rhs: TID) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        return lhs.clockId < rhs.clockId
    }

    // Static validation method
    public static func isValid(_ str: String) -> Bool {
        // Must be exactly 13 characters
        guard str.count == TID_LENGTH else { return false }

        // All characters must be in the base32 charset
        for char in str {
            if !base32Chars.contains(char) {
                return false
            }
        }

        // First character must be 2-j
        guard let firstChar = str.first,
              validFirstChars.contains(firstChar)
        else {
            return false
        }

        return true
    }

    public func toCBORValue() throws -> Any {
        return originalString
    }
}

extension AppBskyFeedDefs.FeedViewPost: Identifiable {
    public var id: String {
        if case let .appBskyFeedDefsReasonRepost(reasonRepost) = reason {
            let reposterDID = reasonRepost.by.did
            return "\(post.uri)-repostedBy-\(reposterDID)"
        } else if let replyRef = reply {
            let rootId = extractIdentifierFrom(replyRef.root)
            let parentId = extractIdentifierFrom(replyRef.parent)
            return "\(post.uri)-reply-root-\(rootId)-parent-\(parentId)"
        } else {
            return post.uri.uriString()
        }
    }

    private func extractIdentifierFrom(_ union: AppBskyFeedDefs.ReplyRefRootUnion) -> String {
        switch union {
        case let .appBskyFeedDefsPostView(postView):
            return postView.uri.uriString()
        case let .appBskyFeedDefsNotFoundPost(notFoundPost):
            return notFoundPost.uri.uriString()
        case let .appBskyFeedDefsBlockedPost(blockedPost):
            return blockedPost.uri.uriString()
        case let .unexpected(ATProtocolValueContainer):
            return ATProtocolValueContainer.hashValue.description
        }
    }

    private func extractIdentifierFrom(_ union: AppBskyFeedDefs.ReplyRefParentUnion) -> String {
        switch union {
        case let .appBskyFeedDefsPostView(postView):
            return postView.uri.uriString()
        case let .appBskyFeedDefsNotFoundPost(notFoundPost):
            return notFoundPost.uri.uriString()
        case let .appBskyFeedDefsBlockedPost(blockedPost):
            return blockedPost.uri.uriString()
        case let .unexpected(ATProtocolValueContainer):
            return ATProtocolValueContainer.hashValue.description
        }
    }
}

/*
 extension ATProtocolValueContainer: Equatable {
     public static func == (lhs: ATProtocolValueContainer, rhs: ATProtocolValueContainer) -> Bool {
         switch (lhs, rhs) {
         case (.knownType(let lhsValue), .knownType(let rhsValue)):
             return lhsValue.isEqual(to: rhsValue)
         case (.string(let lhsValue), .string(let rhsValue)):
             return lhsValue == rhsValue
         case (.number(let lhsValue), .number(let rhsValue)):
             return lhsValue == rhsValue
         case (.bigNumber(let lhsValue), .bigNumber(let rhsValue)):
             return lhsValue == rhsValue
         case (.object(let lhsValue), .object(let rhsValue)):
             return lhsValue == rhsValue
         case (.array(let lhsValue), .array(let rhsValue)):
             return lhsValue == rhsValue
         case (.bool(let lhsValue), .bool(let rhsValue)):
             return lhsValue == rhsValue
         case (.null, .null):
             return true
         case (.link(let lhsValue), .link(let rhsValue)):
             return lhsValue == rhsValue
         case (.bytes(let lhsValue), .bytes(let rhsValue)):
             return lhsValue == rhsValue
         case (.unknownType(let lhsType, let lhsValue), .unknownType(let rhsType, let rhsValue)):
             return lhsType == rhsType && lhsValue == rhsValue
         case (.decodeError(let lhsError), .decodeError(let rhsError)):
             return lhsError == rhsError
         default:
             return false
         }
     }
 }

 public extension ATProtocolValueContainer {
     func isEqual(to other: any ATProtocolValue) -> Bool {
         guard let otherValue = other as? ATProtocolValueContainer else { return false }

         switch (self, otherValue) {
         case (.knownType(let lhsValue), .knownType(let rhsValue)):
             return lhsValue.isEqual(to: rhsValue)
         case (.string(let lhsValue), .string(let rhsValue)):
             return lhsValue == rhsValue
         case (.number(let lhsValue), .number(let rhsValue)):
             return lhsValue == rhsValue
         case (.bigNumber(let lhsValue), .bigNumber(let rhsValue)):
             return lhsValue == rhsValue
         case (.object(let lhsValue), .object(let rhsValue)):
             return lhsValue == rhsValue
         case (.array(let lhsValue), .array(let rhsValue)):
             return lhsValue == rhsValue
         case (.bool(let lhsValue), .bool(let rhsValue)):
             return lhsValue == rhsValue
         case (.null, .null):
             return true
         case (.link(let lhsValue), .link(let rhsValue)):
             return lhsValue == rhsValue
         case (.bytes(let lhsValue), .bytes(let rhsValue)):
             return lhsValue == rhsValue
         case (.unknownType(let lhsType, let lhsValue), .unknownType(let rhsType, let rhsValue)):
             return lhsType == rhsType && lhsValue == rhsValue
         case (.decodeError(let lhsError), .decodeError(let rhsError)):
             return lhsError == rhsError
         default:
             return false
         }
     }
 }

 extension ATProtocolValueContainer: Hashable {
     public func hash(into hasher: inout Hasher) {
         switch self {
         case .knownType(let customValue):
             customValue.hash(into: &hasher)
         case .string(let stringValue):
             hasher.combine("string")
             hasher.combine(stringValue)
         case .number(let intValue):
             hasher.combine("number")
             hasher.combine(intValue)
         case .bigNumber(let bigNumberString):
             hasher.combine("bigNumber")
             hasher.combine(bigNumberString)
         case .object(let objectValue):
             hasher.combine("object")
             hasher.combine(objectValue)
         case .array(let arrayValue):
             hasher.combine("array")
             hasher.combine(arrayValue)
         case .bool(let boolValue):
             hasher.combine("bool")
             hasher.combine(boolValue)
         case .null:
             hasher.combine("null")
         case .link(let linkValue):
             hasher.combine("link")
             hasher.combine(linkValue)
         case .bytes(let bytesValue):
             hasher.combine("bytes")
             hasher.combine(bytesValue)
         case .unknownType(let type, let value):
             hasher.combine("unknownType")
             hasher.combine(type)
             hasher.combine(value)
         case .decodeError(let errorMessage):
             hasher.combine("decodeError")
             hasher.combine(errorMessage)
         }
     }
 }
  */
