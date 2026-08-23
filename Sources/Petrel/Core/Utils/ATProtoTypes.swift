//
//  ATProtoTypes.swift
//
//
//  Created by Josh LaCalamito on 11/30/23.
//

import Foundation
import SwiftCBOR

public protocol ATProtocolCodable: Codable, DAGCBORCodable, Sendable {}

public protocol ATProtocolValue: ATProtocolCodable, Equatable, Hashable {
    /// The Lexicon wire discriminator used when this value is framed by an
    /// `ATProtocolValueContainer`. Standalone helper values leave this empty.
    static var typeIdentifier: String { get }

    func isEqual(to other: any ATProtocolValue) -> Bool
}

public extension ATProtocolValue {
    static var typeIdentifier: String {
        ""
    }
}

public enum ATProtocolError: Error {
    case invalidURI(String)
    case invalidTID(String)
}

// MARK: URIs

public struct ATProtocolURI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let authority: String

    /// The record's collection NSID. On a space URI this names the collection of
    /// the record *within* the space — never the `space` marker itself.
    public let collection: String?

    /// The record's key. On a space URI this is the key of the record within the
    /// space, not the space's own `skey`.
    public let recordKey: String?

    /// Whether this URI addresses permissioned space data. Space URIs carry extra
    /// path segments the public grammar disallows, so they are parsed separately.
    public let isSpace: Bool

    /// The DID of the space's authority. Non-nil only on a space URI whose
    /// authority is a well-formed DID.
    public let spaceDID: String?

    /// The space's type NSID. Non-nil only on a space URI.
    public let spaceType: String?

    /// The space's own key — the third component of a space ref. Non-nil only on
    /// a space URI.
    public let skey: String?

    /// The DID of the account whose record this is. On a public URI that is the
    /// authority itself; on a space URI the authority owns the space while the
    /// record belongs to one of its members, so the two differ.
    public let authorDID: String?

    /// Store the original string to avoid recomputing
    private let originalString: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uriString = try container.decode(String.self)
        try self.init(uriString: uriString)
    }

    public init(uriString: String) throws {
        originalString = uriString

        guard uriString.hasPrefix("at://"),
              uriString.utf8.count <= 8192
        else {
            throw ATProtocolError.invalidURI("Invalid AT URI format or length")
        }

        // Safe string trimming with bounds checking
        guard uriString.count > 5 else {
            throw ATProtocolError.invalidURI("Invalid AT URI: too short")
        }
        let trimmedString = String(uriString.dropFirst(5)) // Remove "at://"
        let components = trimmedString.split(separator: "/", omittingEmptySubsequences: false)

        guard !components.isEmpty, !components[0].isEmpty else {
            throw ATProtocolError.invalidURI("Invalid AT URI: missing or empty authority")
        }

        let authorityStr = String(components[0])
        guard DID.isValidDID(authorityStr) || Handle.isValidHandle(authorityStr) else {
            throw ATProtocolError.invalidURI("Invalid authority in AT URI: \(authorityStr)")
        }

        let parsed = try ATProtocolURI.parseSegments(components)
        authority = parsed.authority
        collection = parsed.collection
        recordKey = parsed.recordKey
        isSpace = parsed.isSpace
        spaceDID = parsed.spaceDID
        spaceType = parsed.spaceType
        skey = parsed.skey
        authorDID = parsed.authorDID
    }
    private struct ParsedURI {
        let authority: String
        let collection: String?
        let recordKey: String?
        let isSpace: Bool
        let spaceDID: String?
        let spaceType: String?
        let skey: String?
        let authorDID: String?
    }

    /// Assigns path segments to their roles, following `parsePath` in
    /// `@atproto/syntax`. Two grammars share the `at://` scheme:
    ///
    ///     at://{authorDid}/{collection}/{rkey}                                        public
    ///     at://{spaceDid}/space/{spaceType}/{skey}[/{authorDid}/{collection}/{rkey}]  space
    ///
    /// Assigning positionally without checking for the `space` marker reports the
    /// marker as the collection and silently discards the space's `skey`, so the
    /// two are separated here. `segments[0]` is the authority.
    private static func parseSegments(_ segments: [Substring]) throws -> ParsedURI {
        let authority = String(segments[0])
        let path = segments.dropFirst().map(String.init)

        guard path.first == "space" else {
            // Public AT URI: at://{authority}[/{collection}[/{rkey}]]
            guard path.count <= 2 else {
                throw ATProtocolError.invalidURI("Too many path segments in public AT URI")
            }

            let collectionName: String?
            if path.count > 0 && !path[0].isEmpty {
                guard NSID.isValidNSID(path[0]) else {
                    throw ATProtocolError.invalidURI("Invalid collection NSID: \(path[0])")
                }
                collectionName = path[0]
            } else {
                collectionName = nil
            }

            let rkey: String?
            if path.count > 1 && !path[1].isEmpty {
                guard RecordKey.isValidRecordKey(path[1]) else {
                    throw ATProtocolError.invalidURI("Invalid record key: \(path[1])")
                }
                rkey = path[1]
            } else {
                rkey = nil
            }

            return ParsedURI(
                authority: authority,
                collection: collectionName,
                recordKey: rkey,
                isSpace: false,
                spaceDID: nil,
                spaceType: nil,
                skey: nil,
                authorDID: DID.isValidDID(authority) ? authority : nil
            )
        }

        // Space URI: at://{spaceDid}/space/{spaceType}/{skey}[/{authorDid}/{collection}/{rkey}]
        let space = path.filter { !$0.isEmpty }
        func segment(_ index: Int) -> String? {
            return index < space.count ? space[index] : nil
        }
        let author = segment(3)

        return ParsedURI(
            authority: authority,
            collection: segment(4),
            recordKey: segment(5),
            isSpace: true,
            spaceDID: DID.isValidDID(authority) ? authority : nil,
            spaceType: segment(1).flatMap { NSID.isValidNSID($0) ? $0 : nil },
            skey: segment(2),
            authorDID: author.flatMap { DID.isValidDID($0) ? $0 : nil }
        )
    }

    /// The space this URI belongs to, whether it names the space itself or a
    /// record within it. `nil` on a public URI, or on a space URI missing any of
    /// the three parts a space ref requires.
    public var spaceRef: SpaceRef? {
        guard isSpace, let spaceDID, let spaceType, let skey else { return nil }
        return try? SpaceRef(spaceDID: spaceDID, spaceType: spaceType, skey: skey)
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

// MARK: - Space Reference

/// A reference to a permissioned-data space, as distinct from a record within one:
///
///     at://{spaceDid}/space/{spaceType}/{skey}
///
/// This is the lexicon string format `space-ref`. It is not a narrower `at-uri`:
/// the public AT-URI grammar admits at most two path segments, so a space ref
/// does not parse as one, and its authority must be a DID rather than any AT
/// identifier — a space's identity and membership are keyed on DIDs.
public struct SpaceRef: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    /// The DID of the account that is the space's authority.
    public let spaceDID: String

    /// The NSID naming the space's type.
    public let spaceType: String

    /// The space's key, unique within its authority and type.
    public let skey: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(uriString: container.decode(String.self))
    }

    public init(spaceDID: String, spaceType: String, skey: String) throws {
        _ = try DID(didString: spaceDID)
        _ = try NSID(nsidString: spaceType)
        _ = try RecordKey(keyString: skey)

        self.spaceDID = spaceDID
        self.spaceType = spaceType
        self.skey = skey
    }

    /// Parses the three-part form only. A URI naming a record *within* a space
    /// begins with a valid space ref but is not one, and is rejected — matching
    /// `SpaceRef.parse` upstream, which requires its input to equal its own
    /// canonical serialisation.
    public init(uriString: String) throws {
        guard uriString.hasPrefix("at://"),
              uriString.utf8.count <= 8192
        else {
            throw ATProtocolError.invalidURI("Invalid space ref format or length")
        }

        let segments = uriString.dropFirst(5).split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 4, segments[1] == "space" else {
            throw ATProtocolError.invalidURI("Invalid space ref: \(uriString)")
        }

        try self.init(
            spaceDID: String(segments[0]),
            spaceType: String(segments[2]),
            skey: String(segments[3])
        )
    }

    public var description: String {
        return uriString()
    }

    public func uriString() -> String {
        return "at://\(spaceDID)/space/\(spaceType)/\(skey)"
    }

    /// The URI of a record published inside this space by one of its members.
    public func recordURI(
        authorDID: String,
        collection: String,
        recordKey: String
    ) throws -> ATProtocolURI {
        _ = try DID(didString: authorDID)
        _ = try NSID(nsidString: collection)
        _ = try RecordKey(keyString: recordKey)

        return try ATProtocolURI(
            uriString: "\(uriString())/\(authorDID)/\(collection)/\(recordKey)"
        )
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherRef = other as? SpaceRef else {
            return false
        }

        return spaceDID == otherRef.spaceDID && spaceType == otherRef.spaceType
            && skey == otherRef.skey
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uriString())
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: uriString())
    }

    public func toCBORValue() throws -> Any {
        return uriString()
    }
}
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
        let raw = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.starts(with: "did:") {
            isDID = true
            let components = raw.split(separator: ":")
            guard components.count >= 3 else { throw URIError.invalidDID }
            scheme = String(components[0])
            authority = String(components[1])
            path = components.count > 2 ? components.dropFirst(2).joined(separator: ":") : nil
            query = nil
            fragment = nil
        } else {
            // Defensive parse for non-DID URIs: reject obviously malformed strings like "//"
            // Require a non-empty scheme and avoid passing bad input to URLComponents.
            isDID = false
            if raw.isEmpty || raw.hasPrefix("//") || URI.detectScheme(in: raw) == nil {
                // Safe fallback to a benign invalid host
                scheme = "https"
                authority = "invalid.invalid"
                path = nil
                query = nil
                fragment = nil
            } else {
                let comps = URLComponents(string: raw)
                scheme = comps?.scheme ?? ""
                authority = comps?.host ?? ""
                path = comps?.path.isEmpty ?? true ? nil : comps?.path
                query = comps?.query
                fragment = comps?.fragment
            }
        }
    }

    public init(uriString: String) {
        if uriString.starts(with: "did:") {
            isDID = true
            let components = uriString.split(separator: ":")
            scheme = "did"
            authority = components.count > 1 ? String(components[1]) : ""
            path = components.count > 2 ? components.dropFirst(2).joined(separator: ":") : nil
            query = nil
            fragment = nil
        } else {
            isDID = false
            let raw = uriString.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty || raw.hasPrefix("//") || URI.detectScheme(in: raw) == nil {
                // Safe fallback
                scheme = "https"
                authority = "invalid.invalid"
                path = nil
                query = nil
                fragment = nil
            } else {
                let comps = URLComponents(string: raw)
                let defaultScheme = "https"
                scheme = comps?.scheme ?? defaultScheme
                authority = comps?.host ?? ""
                path = comps?.path.isEmpty ?? true ? nil : comps?.path
                query = comps?.query
                fragment = comps?.fragment
            }
        }
    }

    /// Detect a valid URI scheme prefix (e.g., https:, http:, ftp:, etc.)
    private static func detectScheme(in s: String) -> String? {
        // scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ':'
        // Use a lightweight regex
        let pattern = "^[A-Za-z][A-Za-z0-9+.-]*:"
        return s.range(of: pattern, options: .regularExpression).map { _ in String(s.prefix { $0 != ":" }) }
    }

    public func isValid() -> Bool {
        if isDID {
            return scheme == "did" && !authority.isEmpty
        } else {
            return !scheme.isEmpty && !authority.isEmpty
        }
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
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

    /// Initializer to create URI from URL
    public init(url: URL) {
        isDID = false
        scheme = url.scheme ?? "https"
        authority = url.host ?? ""
        path = url.path.isEmpty ? nil : url.path
        query = url.query
        fragment = url.fragment
    }

    /// Computed property to get URL from URI
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

        // Check if this is the legacy format (has cid but no $type)
        if container.contains(.cid), !container.contains(.type) {
            // Legacy blob format: { "cid": "...", "mimeType": "..." }
            type = "blob" // Default type for legacy blobs
            ref = nil // Legacy format doesn't have ref
            mimeType = try container.decode(String.self, forKey: .mimeType)
            size = 0 // Legacy format doesn't include size, use 0 as placeholder
            cid = try container.decode(String.self, forKey: .cid)
        } else {
            // Modern blob format: { "$type": "blob", "ref": {...}, "mimeType": "...", "size": ... }
            type = try container.decode(String.self, forKey: .type)
            ref = try container.decodeIfPresent(ATProtoLink.self, forKey: .ref)
            mimeType = try container.decode(String.self, forKey: .mimeType)
            size = try container.decode(Int.self, forKey: .size)
            cid = try container.decodeIfPresent(String.self, forKey: .cid)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Always encode in modern format when writing
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
        map.append(key: "$type", value: type) // Assuming 'type' holds the lexicon identifier like "blob"

        if let refLink = ref {
            let refValue = try refLink.toCBORValue()
            map.append(key: "ref", value: refValue)
        }

        map.append(key: "mimeType", value: mimeType)
        map.append(key: "size", value: size)

        if let cidValue = cid {
            map.append(key: "cid", value: cidValue)
        }

        return map
    }
}

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
        guard let normalizedBase64 = Self.normalizedRFC4648Base64(base64String),
              let data = Data(base64Encoded: normalizedBase64)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .data,
                in: container,
                debugDescription: "String is not canonical RFC 4648 base64"
            )
        }
        self.data = data
    }

    private static func normalizedRFC4648Base64(_ value: String) -> String? {
        let encoded = Array(value.utf8)
        let paddingStart = encoded.firstIndex(of: Character("=").asciiValue!) ?? encoded.endIndex
        let payload = encoded[..<paddingStart]
        let padding = encoded[paddingStart...]

        guard padding.count <= 2, padding.allSatisfy({ $0 == Character("=").asciiValue }) else {
            return nil
        }

        let sextets = payload.compactMap(base64SextetValue)
        guard sextets.count == payload.count else {
            return nil
        }

        let remainder = payload.count % 4
        let canonicalPaddingCount: Int
        switch remainder {
        case 0:
            canonicalPaddingCount = 0
        case 2:
            canonicalPaddingCount = 2
            guard let last = sextets.last, last & 0x0F == 0 else { return nil }
        case 3:
            canonicalPaddingCount = 1
            guard let last = sextets.last, last & 0x03 == 0 else { return nil }
        default:
            return nil
        }

        if !padding.isEmpty {
            guard encoded.count.isMultiple(of: 4), padding.count == canonicalPaddingCount else {
                return nil
            }
        }

        return String(decoding: payload, as: UTF8.self)
            + String(repeating: "=", count: canonicalPaddingCount)
    }

    private static func base64SextetValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case Character("A").asciiValue! ... Character("Z").asciiValue!:
            return byte - Character("A").asciiValue!
        case Character("a").asciiValue! ... Character("z").asciiValue!:
            return byte - Character("a").asciiValue! + 26
        case Character("0").asciiValue! ... Character("9").asciiValue!:
            return byte - Character("0").asciiValue! + 52
        case Character("+").asciiValue!:
            return 62
        case Character("/").asciiValue!:
            return 63
        default:
            return nil
        }
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
        return data
    }
}

// MARK: - DID Identifier

public struct DID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let method: String
    public let authority: String
    public let segments: [String]
    private let originalString: String

    /// Per https://atproto.com/specs/did the method must be lowercase letters, the
    /// method-specific identifier allows [a-zA-Z0-9._:%-] (including empty colon-separated
    /// segments), and the final character cannot be ":" or "%".
    private static let didPattern = "^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$"

    /// Cached compiled regex - compiled once, reused forever
    private static let didRegex: NSRegularExpression? = try? NSRegularExpression(pattern: didPattern, options: [])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let didString = try container.decode(String.self)
        try self.init(didString: didString)
    }

    public init(didString: String) throws {
        originalString = didString

        guard didString.utf8.count <= 8192,
              DID.isValidDID(didString)
        else {
            throw ATProtocolError.invalidURI("Invalid DID format or length")
        }

        // The regex guarantees a "did:" prefix, a non-empty method, and at least one
        // character of method-specific identifier (so components.count >= 2).
        let components = didString.dropFirst(4).split(separator: ":", omittingEmptySubsequences: false)

        method = String(components[0])
        // The method-specific identifier may contain empty colon-separated segments
        // (e.g. "did:method::."), so the authority segment may legitimately be empty.
        authority = components.count > 1 ? String(components[1]) : ""
        segments = components.count > 2 ? components.dropFirst(2).map { String($0) } : []
    }

    /// Gate a space URI's authority and author on being well-formed DIDs, as the space grammar requires.
    public static func isValidDID(_ did: String) -> Bool {
        guard let regex = didRegex else {
            // Fallback validation without regex
            return did.hasPrefix("did:") && did.count > 4
        }

        let range = NSRange(location: 0, length: did.utf16.count)
        return regex.firstMatch(in: did, options: [], range: range) != nil
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

    /// Registration-time restricted TLDs (per upstream @atproto/syntax handle.ts: DISALLOWED_TLDS).
    /// Note: .test is explicitly allowed for testing/development.
    public static let disallowedTLDs: Set<String> = [
        "alt", "arpa", "example", "internal", "invalid", "local", "localhost", "onion",
    ]

    /// Registration-time policy check for TLD validity (mirrors upstream isValidTld).
    public static func isValidTLD(_ tld: String) -> Bool {
        let normalized = tld.hasPrefix(".") ? String(tld.dropFirst()) : tld
        return !disallowedTLDs.contains(normalized.lowercased())
    }

    /// Registration-time policy check for TLD validity (alias matching upstream naming).
    public static func isValidTld(_ tld: String) -> Bool {
        isValidTLD(tld)
    }

    /// Returns true if this handle's TLD is in the registration-time disallowed list.
    public var hasDisallowedTLD: Bool {
        guard let tld = value.split(separator: ".").last else { return false }
        return Self.disallowedTLDs.contains(String(tld))
    }

    /// Returns true if this handle's TLD is in the registration-time disallowed list.
    public var hasDisallowedTld: Bool {
        hasDisallowedTLD
    }

    /// Per https://atproto.com/specs/handle the final segment (TLD) cannot start with a digit
    private static let handlePattern =
        "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"

    /// Cached compiled regex - compiled once, reused forever
    private static let handleRegex: NSRegularExpression? = try? NSRegularExpression(pattern: handlePattern, options: [])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let handleString = try container.decode(String.self)
        try self.init(handleString: handleString)
    }

    public init(handleString: String) throws {
        guard Handle.isValidHandle(handleString) else {
            throw ATProtocolError.invalidURI("Invalid handle format: \(handleString)")
        }

        value = handleString.lowercased()
    }

    public static func isValidHandle(_ handle: String) -> Bool {
        // Basic validation before regex
        guard !handle.isEmpty, handle.utf8.count <= 253 else {
            return false
        }

        let lower = handle.lowercased()
        let labels = lower.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else {
            return false
        }

        guard labels.allSatisfy({ label in
            !label.isEmpty
                && label.utf8.count <= 63
                && label.first != "-"
                && label.last != "-"
                && label.utf8.allSatisfy({ ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 45 })
        }) else {
            return false
        }

        guard let tld = labels.last.map(String.init) else {
            return false
        }

        guard let firstByte = tld.utf8.first, (firstByte >= 97 && firstByte <= 122) else {
            return false
        }


        guard let regex = handleRegex else {
            return true
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

        return value == otherHandle.value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
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

    /// Add support for DAG-CBOR encoding
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

    /// Cached compiled regex - compiled once, reused forever
    private static let nsidRegex: NSRegularExpression? = try? NSRegularExpression(pattern: nsidPattern, options: [])

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
        guard !components.isEmpty else {
            throw ATProtocolError.invalidURI("Invalid NSID: no components found")
        }
        name = String(components.last ?? "")
        authority = components.count > 1 ? components.dropLast().joined(separator: ".") : ""
    }

    /// Gate a space URI's type segment, as the space grammar requires.
    public static func isValidNSID(_ nsid: String) -> Bool {
        // Basic validation before regex
        guard !nsid.isEmpty, nsid.count <= 584 else {
            return false
        }

        guard let regex = nsidRegex else {
            // Fallback validation without regex
            let components = nsid.split(separator: ".")
            return components.count >= 3 && components.allSatisfy { component in
                !component.isEmpty && component.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
            }
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

    /// Pattern for "any" record key format (https://atproto.com/specs/record-key allows "~")
    private static let recordKeyPattern = "^[a-zA-Z0-9\\-_.:~%]+$"

    /// Cached compiled regex - compiled once, reused forever
    private static let recordKeyRegex: NSRegularExpression? = try? NSRegularExpression(pattern: recordKeyPattern, options: [])

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
    public static func isValidRecordKey(_ key: String) -> Bool {
        // Basic validation before regex
        guard !key.isEmpty, key.utf8.count <= 512, key != ".", key != ".." else {
            return false
        }

        guard let regex = recordKeyRegex else {
            // Fallback validation without regex
            return key.allSatisfy { char in
                char.isLetter || char.isNumber || "-_.:~%".contains(char)
            }
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    public func toCBORValue() throws -> Any {
        return value
    }
}

public struct TID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible, Comparable {
    /// Timestamp in microseconds since epoch
    private let timestamp: UInt64
    /// Clock ID plus counter
    private let clockId: UInt64
    /// Original string representation
    private let originalString: String

    /// Base32 sortable character set
    private static let base32Chars = "234567abcdefghijklmnopqrstuvwxyz"

    /// Fixed length of TID strings
    private static let TID_LENGTH = 13

    /// Valid first characters. Timestamp-based TIDs always lead with a digit; the
    /// interop test fixtures treat letter-leading strings as invalid TIDs.
    private static let validFirstChars = "234567"

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

        // Validate first character (must be 2-7)
        guard let firstChar = tidString.first,
              Self.validFirstChars.contains(firstChar)
        else {
            throw ATProtocolError.invalidURI(
                "Invalid TID string format: first character must be in 234567"
            )
        }

        // Decode TID value
        let tidValue = Self.decode(tidString)

        // Extract timestamp and clock ID
        // 53 bits for timestamp, 10 bits for clock ID
        timestamp = (tidValue >> 10) & 0x1F_FFFF_FFFF_FFFF
        clockId = tidValue & 0x3FF
        originalString = tidString
    }

    /// Decode a base32 string to a number
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(clockId)
    }

    /// Comparable implementation for sorting
    public static func < (lhs: TID, rhs: TID) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        return lhs.clockId < rhs.clockId
    }

    /// Static validation method
    public static func isValid(_ str: String) -> Bool {
        // Must be exactly 13 characters
        guard str.count == TID_LENGTH else { return false }

        // All characters must be in the base32 charset
        for char in str {
            if !base32Chars.contains(char) {
                return false
            }
        }

        // First character must be 2-7
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

// MARK: - Swift Standard Types DAGCBOREncodable Extensions

extension String: DAGCBOREncodable {
    public func toCBORValue() throws -> Any {
        return self
    }
}

extension Array: DAGCBOREncodable where Element: DAGCBOREncodable {
    public func toCBORValue() throws -> Any {
        return try map { try $0.toCBORValue() }
    }
}

extension Int: DAGCBOREncodable {
    public func toCBORValue() throws -> Any {
        return self
    }
}

extension Bool: DAGCBOREncodable {
    public func toCBORValue() throws -> Any {
        return self
    }
}

extension Data: DAGCBOREncodable {
    public func toCBORValue() throws -> Any {
        return self
    }
}
