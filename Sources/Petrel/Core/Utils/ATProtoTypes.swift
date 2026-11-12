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
extension CIDCodec: ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? CIDCodec else { return false }
        return self == other
    }
}

extension Multihash: ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Multihash else { return false }
        return algorithm == other.algorithm && length == other.length && digest == other.digest
    }
}

extension ATProtoLink: ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherLink = other as? ATProtoLink else { return false }
        return cid == otherLink.cid
    }

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherLink = other as? ATProtoLink else { return false }
        return cid == otherLink.cid
    }
}

extension CID: ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? CID else { return false }
        return self == other
    }
}


/// A string failed validation as an AT Protocol identifier or string format.
///
/// Each case names the format that was being parsed and carries a
/// human-readable reason. The associated message is for logs and diagnostics;
/// match on the case, not on its text.
public enum ATProtocolError: Error, Equatable, Sendable {
    /// Not a valid AT-URI (``ATProtocolURI``), space reference (``SpaceRef``) or
    /// generic URI (``URI``).
    case invalidURI(String)
    /// Not a valid timestamp identifier (``TID``).
    case invalidTID(String)
    /// Not a valid DID (``DID``).
    case invalidDID(String)
    /// Not a valid handle (``Handle``).
    case invalidHandle(String)
    /// Not a valid namespaced identifier (``NSID``).
    case invalidNSID(String)
    /// Not a valid record key (``RecordKey``).
    case invalidRecordKey(String)
    /// Not a valid datetime (``ATProtocolDate``).
    case invalidDatetime(String)
    /// Not a valid BCP 47 language tag (``LanguageTag``, ``LanguageCodeContainer``).
    case invalidLanguage(String)
    /// Not a valid CID string (``CIDSyntax``).
    case invalidCID(String)

    /// The reason carried by the error.
    public var message: String {
        switch self {
        case let .invalidURI(message), let .invalidTID(message), let .invalidDID(message),
             let .invalidHandle(message), let .invalidNSID(message), let .invalidRecordKey(message),
             let .invalidDatetime(message), let .invalidLanguage(message), let .invalidCID(message):
            return message
        }
    }
}

extension ATProtocolError: LocalizedError {
    public var errorDescription: String? {
        message
    }
}

// MARK: URIs

/// An AT-URI (`at://…`), the Lexicon `at-uri` string format.
///
/// Parsing is strict. The public grammar is the "Restricted AT URI Syntax" of
/// https://atproto.com/specs/at-uri-scheme:
///
///     at://AUTHORITY[/COLLECTION[/RKEY]]
///
/// where the authority is a ``DID`` or ``Handle``, the collection an ``NSID`` and
/// the record key a ``RecordKey``. Trailing slashes, empty path segments, query
/// strings, fragments, whitespace and anything over 8 KB are rejected.
///
/// A second, equally strict grammar addresses permissioned-data spaces and the
/// records inside them (see ``SpaceRef``):
///
///     at://SPACE-DID/space/SPACE-TYPE/SKEY[/AUTHOR-DID/COLLECTION/RKEY]
///
/// It is not part of the published AT-URI specification. ``init(uriString:)``
/// accepts both; pass ``Grammar/restricted`` to ``init(uriString:grammar:)`` or
/// ``isValidATURI(_:grammar:)`` to accept the specification grammar only.
///
/// Accepting both by default follows the Spaces reference implementation:
/// `@atproto/syntax` `parseAtUriString` hands a URI whose first path segment is
/// `space` to a separate, equally strict space parser, and Lexicon `at-uri`
/// validation uses that same check, so a `format: at-uri` field may hold a space
/// URI. The Spaces endpoints rely on it: `com.atproto.space.createRecord` and its
/// siblings return the URI of a record inside a space in an `at-uri` field.
/// Decoding (``init(from:)``) therefore uses the default grammar too. To hold a
/// decoded value to the specification grammar, check ``isSpace``, or re-validate
/// with `ATProtocolURI.isValidATURI(uri.uriString(), grammar: .restricted)`.
///
/// The string is kept exactly as written; ``normalized()`` returns the
/// normalized form the specification describes.
///
/// ```swift
/// let uri = try ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jzfcijpj2z2a")
/// uri.authority   // "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
/// uri.collection  // "app.bsky.feed.post"
/// uri.recordKey   // "3jzfcijpj2z2a"
/// ```
public struct ATProtocolURI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    /// Which AT-URI grammars a parse accepts.
    public enum Grammar: Sendable {
        /// Only the "Restricted AT URI Syntax" of the AT-URI specification:
        /// `at://AUTHORITY[/COLLECTION[/RKEY]]`.
        case restricted
        /// The specification grammar, plus the permissioned-data space grammar
        /// `at://SPACE-DID/space/SPACE-TYPE/SKEY[/AUTHOR-DID/COLLECTION/RKEY]`.
        case restrictedOrSpace
    }

    /// The authority exactly as written: a DID or a handle. On a space URI this
    /// is the DID that owns the space.
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

    /// The DID of the space's authority. Non-nil exactly when ``isSpace`` is true.
    public let spaceDID: String?

    /// The space's type NSID. Non-nil exactly when ``isSpace`` is true.
    public let spaceType: String?

    /// The space's own key — the third component of a space ref. Non-nil exactly
    /// when ``isSpace`` is true.
    public let skey: String?

    /// The DID of the account whose record this is. On a public URI that is the
    /// authority itself when it is a DID (`nil` for a handle authority); on a
    /// space URI the authority owns the space while the record belongs to one of
    /// its members, so this is the author segment, or `nil` when the URI names
    /// the space rather than a record in it.
    public let authorDID: String?

    /// Store the original string to avoid recomputing
    private let originalString: String

    /// The authority, parsed.
    private let parsedAuthority: ATIdentifier

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uriString = try container.decode(String.self)
        try self.init(uriString: uriString)
    }

    /// Parses an AT-URI, accepting the specification grammar and the space
    /// grammar. Throws ``ATProtocolError/invalidURI(_:)`` with the reason.
    public init(uriString: String) throws {
        try self.init(uriString: uriString, grammar: .restrictedOrSpace)
    }

    /// Parses an AT-URI under the given grammar. Throws
    /// ``ATProtocolError/invalidURI(_:)`` with the reason.
    public init(uriString: String, grammar: Grammar) throws {
        switch ATProtocolURI.parse(uriString, grammar: grammar) {
        case let .success(parsed):
            originalString = uriString
            authority = parsed.authority
            parsedAuthority = parsed.parsedAuthority
            collection = parsed.collection
            recordKey = parsed.recordKey
            isSpace = parsed.isSpace
            spaceDID = parsed.spaceDID
            spaceType = parsed.spaceType
            skey = parsed.skey
            authorDID = parsed.authorDID
        case let .failure(failure):
            throw ATProtocolError.invalidURI("Invalid AT-URI \(syntaxExcerpt(uriString)): \(failure.reason)")
        }
    }

    /// Builds a public AT-URI from typed parts. Throws
    /// ``ATProtocolError/invalidURI(_:)`` if a record key is given without a
    /// collection, or the result would exceed 8 KB.
    public init(authority: ATIdentifier, collection: NSID? = nil, recordKey: RecordKey? = nil) throws {
        var string = "at://\(authority.wireValue)"
        if let collection {
            string += "/\(collection.nsidString())"
            if let recordKey {
                string += "/\(recordKey.value)"
            }
        } else if recordKey != nil {
            throw ATProtocolError.invalidURI("Invalid AT-URI: a record key requires a collection")
        }
        try self.init(uriString: string, grammar: .restricted)
    }

    /// Whether `string` is a valid AT-URI under `grammar` (by default the
    /// specification grammar plus the space grammar, as ``init(uriString:)``).
    public static func isValidATURI(_ string: String, grammar: Grammar = .restrictedOrSpace) -> Bool {
        if case .success = parse(string, grammar: grammar) { return true }
        return false
    }

    private struct ParsedURI {
        let authority: String
        let parsedAuthority: ATIdentifier
        let collection: String?
        let recordKey: String?
        let isSpace: Bool
        let spaceDID: String?
        let spaceType: String?
        let skey: String?
        let authorDID: String?
    }

    /// Splits and validates an AT-URI. Two grammars share the `at://` scheme:
    ///
    ///     at://{authority}[/{collection}[/{rkey}]]                                    public
    ///     at://{spaceDid}/space/{spaceType}/{skey}[/{authorDid}/{collection}/{rkey}]  space
    ///
    /// `space` is not a valid NSID, so the first path segment tells them apart
    /// without ambiguity.
    private static func parse(_ uriString: String, grammar: Grammar) -> Result<ParsedURI, SyntaxFailure> {
        let utf8 = uriString.utf8
        guard utf8.count <= 8192 else { return .failure("longer than 8192 bytes") }
        guard utf8.starts(with: "at://".utf8) else { return .failure("must start with \"at://\"") }

        // Split on the "/" byte. Splitting by Character would let a slash hide
        // inside a grapheme cluster.
        let segments = utf8.dropFirst(5)
            .split(separator: SyntaxByte.slash, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        let authority = segments[0]
        guard !authority.isEmpty else { return .failure("authority is missing") }
        let parsedAuthority: ATIdentifier
        if let did = try? DID(didString: authority) {
            parsedAuthority = .did(did)
        } else if let handle = try? Handle(handleString: authority) {
            parsedAuthority = .handle(handle)
        } else {
            return .failure("authority is neither a DID nor a handle")
        }

        let path = Array(segments.dropFirst())
        guard !path.contains(where: \.isEmpty) else {
            return .failure("trailing slash or empty path segment")
        }

        if grammar == .restrictedOrSpace, path.first == "space" {
            guard case .did = parsedAuthority else {
                return .failure("the authority of a space URI must be a DID")
            }
            guard path.count == 3 || path.count == 6 else {
                return .failure(
                    "a space URI is /space/{type}/{skey}, optionally followed by /{authorDid}/{collection}/{rkey}"
                )
            }
            if let reason = ATProtoSyntax.nsidFailure(path[1]) {
                return .failure("space type is not an NSID (\(reason))")
            }
            if let reason = ATProtoSyntax.recordKeyFailure(path[2]) {
                return .failure("space key is not a record key (\(reason))")
            }
            if path.count == 6 {
                if let reason = ATProtoSyntax.didFailure(path[3]) {
                    return .failure("record author is not a DID (\(reason))")
                }
                if let reason = ATProtoSyntax.nsidFailure(path[4]) {
                    return .failure("collection is not an NSID (\(reason))")
                }
                if let reason = ATProtoSyntax.recordKeyFailure(path[5]) {
                    return .failure("record key is not valid (\(reason))")
                }
            }
            return .success(ParsedURI(
                authority: authority,
                parsedAuthority: parsedAuthority,
                collection: path.count == 6 ? path[4] : nil,
                recordKey: path.count == 6 ? path[5] : nil,
                isSpace: true,
                spaceDID: authority,
                spaceType: path[1],
                skey: path[2],
                authorDID: path.count == 6 ? path[3] : nil
            ))
        }

        guard path.count <= 2 else { return .failure("too many path segments") }
        if path.count >= 1, let reason = ATProtoSyntax.nsidFailure(path[0]) {
            return .failure("collection is not an NSID (\(reason))")
        }
        if path.count == 2, let reason = ATProtoSyntax.recordKeyFailure(path[1]) {
            return .failure("record key is not valid (\(reason))")
        }

        let authorDID: String?
        if case .did = parsedAuthority {
            authorDID = authority
        } else {
            authorDID = nil
        }
        return .success(ParsedURI(
            authority: authority,
            parsedAuthority: parsedAuthority,
            collection: path.count >= 1 ? path[0] : nil,
            recordKey: path.count == 2 ? path[1] : nil,
            isSpace: false,
            spaceDID: nil,
            spaceType: nil,
            skey: nil,
            authorDID: authorDID
        ))
    }

    /// The authority as a typed identifier.
    public var authorityIdentifier: ATIdentifier {
        parsedAuthority
    }

    /// The collection as a typed ``NSID``, when the URI has one.
    public var collectionNSID: NSID? {
        collection.flatMap { try? NSID(nsidString: $0) }
    }

    /// The record key as a typed ``RecordKey``, when the URI has one.
    public var rkey: RecordKey? {
        recordKey.flatMap { try? RecordKey(keyString: $0) }
    }

    /// The space this URI belongs to, whether it names the space itself or a
    /// record within it. `nil` on a public URI.
    public var spaceRef: SpaceRef? {
        guard isSpace, let spaceDID, let spaceType, let skey else { return nil }
        return try? SpaceRef(spaceDID: spaceDID, spaceType: spaceType, skey: skey)
    }

    /// The normalized form described by the AT-URI specification: a handle
    /// authority in lower case and the domain-authority part of every NSID in
    /// lower case. DIDs, NSID names and record keys are case-sensitive and are
    /// left as written. Use this form for string equality and when writing a URI
    /// into a record.
    public func normalized() -> ATProtocolURI {
        func normalizedNSID(_ nsid: String) -> String {
            (try? NSID(nsidString: nsid).normalized.nsidString()) ?? nsid
        }

        var string = "at://\(parsedAuthority.stringValue())"
        if isSpace, let spaceType, let skey {
            string += "/space/\(normalizedNSID(spaceType))/\(skey)"
            if let authorDID, let collection, let recordKey {
                string += "/\(authorDID)/\(normalizedNSID(collection))/\(recordKey)"
            }
        } else if let collection {
            string += "/\(normalizedNSID(collection))"
            if let recordKey {
                string += "/\(recordKey)"
            }
        }
        // Lower-casing cannot invalidate a URI that has already parsed.
        return (try? ATProtocolURI(uriString: string)) ?? self
    }

    /// Whether the URI is already in the form ``normalized()`` returns.
    public var isNormalized: Bool {
        normalized().originalString == originalString
    }

    public var description: String {
        return uriString()
    }

    /// The URI exactly as it was written.
    public func uriString() -> String {
        // Return the original string if we have it
        return originalString
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherURI = other as? ATProtocolURI else {
            return false
        }

        return originalString == otherURI.originalString
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
        try self.init(uriString: "at://\(spaceDID)/space/\(spaceType)/\(skey)")
    }

    /// Parses the three-part form only. A URI naming a record *within* a space
    /// begins with a valid space ref but is not one, and is rejected — matching
    /// `SpaceRef.parse` upstream, which requires its input to equal its own
    /// canonical serialisation.
    public init(uriString: String) throws {
        let utf8 = uriString.utf8
        guard utf8.starts(with: "at://".utf8), utf8.count <= 8192 else {
            throw ATProtocolError.invalidURI("Invalid space ref format or length")
        }

        let segments = utf8.dropFirst(5)
            .split(separator: SyntaxByte.slash, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }
        guard segments.count == 4, segments[1] == "space" else {
            throw ATProtocolError.invalidURI("Invalid space ref: \(syntaxExcerpt(uriString))")
        }

        let did = try DID(didString: segments[0])
        let nsid = try NSID(nsidString: segments[2])
        let rkey = try RecordKey(keyString: segments[3])

        self.spaceDID = did.didString()
        self.spaceType = nsid.nsidString()
        self.skey = rkey.value
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

/// A generic URI, the Lexicon `uri` string format.
///
/// The format is "flexible to any URI schema, following the generic RFC-3986"
/// with a maximum length of 8 KB (https://atproto.com/specs/lexicon#uri). A
/// string is accepted when it has
///
/// - an RFC 3986 scheme (a letter, then letters, digits, `+`, `-` or `.`)
///   followed by `:`,
/// - something after the scheme (and after `//` if present), and
/// - no whitespace or control characters anywhere,
///
/// and is at most 8192 bytes. That covers `https:`, `at:`, `did:`, `dns:`,
/// `ipfs:` and any other scheme, and matches the official `uri_syntax_*` interop
/// vectors. Non-ASCII characters outside the scheme are tolerated, as they are
/// by the reference implementation, because such links exist in published
/// records.
///
/// The string is stored and re-encoded exactly as written: nothing is trimmed,
/// re-escaped or replaced.
///
/// ```swift
/// let link = try URI(validating: "https://example.com/path?q=1#top")
/// link.scheme       // "https"
/// link.authority    // "example.com"
/// link.uriString()  // "https://example.com/path?q=1#top"
/// URI.isValidURI("example.com")  // false: no scheme
/// ```
///
/// ``init(uriString:)``, ``init(url:)`` and string literals do not validate, so
/// that existing call sites keep compiling; a value built that way from a string
/// that is not a URI reports `isValid() == false` and throws when encoded.
public struct URI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible,
    ExpressibleByStringLiteral
{
    /// The scheme as written (`https`, `at`, `did`), or empty when the string has none.
    public let scheme: String
    /// The host for hierarchical URIs, the DID method for `did:` URIs, the
    /// AT-URI authority for `at:` URIs; empty when there is none.
    public let authority: String
    /// The path, when there is one. For a `did:` URI, everything after the method.
    public let path: String?
    /// The query, without the leading `?`.
    public let query: String?
    /// The fragment, without the leading `#`.
    public let fragment: String?
    /// Whether the scheme is `did`.
    public let isDID: Bool
    /// The string this value was created from, exactly as written.
    public let originalString: String?

    /// Whether `originalString` passed ``isValidURI(_:)`` when the value was created.
    private let hasValidSyntax: Bool

    /// Maximum length of a Lexicon `uri`, in bytes.
    public static let maximumLength = 8192

    /// Whether `string` has valid Lexicon `uri` syntax (see the type documentation).
    public static func isValidURI(_ string: String) -> Bool {
        ATProtoSyntax.uriFailure(string) == nil
    }

    /// Creates a URI, throwing ``ATProtocolError/invalidURI(_:)`` with the reason
    /// if `uriString` does not have valid Lexicon `uri` syntax.
    public init(validating uriString: String) throws {
        if let reason = ATProtoSyntax.uriFailure(uriString) {
            throw ATProtocolError.invalidURI("Invalid URI \(syntaxExcerpt(uriString)): \(reason)")
        }
        self.init(unchecked: uriString, hasValidSyntax: true)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let reason = ATProtoSyntax.uriFailure(raw) {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid URI \(syntaxExcerpt(raw)): \(reason)",
                    underlyingError: ATProtocolError.invalidURI("Invalid URI \(syntaxExcerpt(raw)): \(reason)")
                )
            )
        }
        self.init(unchecked: raw, hasValidSyntax: true)
    }

    /// Wraps `uriString` without validating it. The string is kept exactly as
    /// given. If it is not a valid URI, ``isValid()`` is `false`, ``url`` is `nil`
    /// and encoding the value throws. Prefer ``init(validating:)``.
    public init(uriString: String) {
        self.init(unchecked: uriString, hasValidSyntax: ATProtoSyntax.uriFailure(uriString) == nil)
    }

    private init(unchecked raw: String, hasValidSyntax: Bool) {
        originalString = raw
        self.hasValidSyntax = hasValidSyntax

        if raw.hasPrefix("did:") {
            isDID = true
            let components = raw.split(separator: ":", omittingEmptySubsequences: false)
            scheme = "did"
            authority = components.count > 1 ? String(components[1]) : ""
            path = components.count > 2 ? components.dropFirst(2).joined(separator: ":") : nil
            query = nil
            fragment = nil
        } else if raw.hasPrefix("at://") {
            isDID = false
            scheme = "at"
            let afterPrefix = raw.dropFirst(5)
            if let slashIndex = afterPrefix.firstIndex(of: "/") {
                authority = String(afterPrefix[..<slashIndex])
                let rem = String(afterPrefix[slashIndex...])
                path = rem.isEmpty ? nil : rem
            } else {
                authority = String(afterPrefix)
                path = nil
            }
            query = nil
            fragment = nil
        } else if let parts = URI.splitComponents(raw) {
            isDID = false
            scheme = parts.scheme
            authority = parts.host
            path = parts.path
            query = parts.query
            fragment = parts.fragment
        } else {
            // No scheme: not a URI. Nothing is invented in its place.
            isDID = false
            scheme = ""
            authority = ""
            path = nil
            query = nil
            fragment = nil
        }
    }

    private struct Components {
        let scheme: String
        let host: String
        let path: String?
        let query: String?
        let fragment: String?
    }

    /// Splits a URI with a scheme into its RFC 3986 components (appendix B),
    /// reducing the authority to its host. Returns `nil` when there is no scheme.
    private static func splitComponents(_ raw: String) -> Components? {
        guard let colon = raw.firstIndex(of: ":"), colon != raw.startIndex else { return nil }
        let scheme = raw[..<colon]
        guard let first = scheme.unicodeScalars.first, first.isASCII, first.properties.isAlphabetic,
              scheme.unicodeScalars.allSatisfy({ scalar in
                  scalar.isASCII
                      && (scalar.properties.isAlphabetic || ("0" ... "9").contains(scalar)
                          || scalar == "+" || scalar == "-" || scalar == ".")
              })
        else {
            return nil
        }

        var rest = raw[raw.index(after: colon)...]
        var fragment: String?
        if let hash = rest.firstIndex(of: "#") {
            fragment = String(rest[rest.index(after: hash)...])
            rest = rest[..<hash]
        }
        var query: String?
        if let mark = rest.firstIndex(of: "?") {
            query = String(rest[rest.index(after: mark)...])
            rest = rest[..<mark]
        }

        var host = ""
        if rest.hasPrefix("//") {
            let afterSlashes = rest.dropFirst(2)
            let authorityEnd = afterSlashes.firstIndex(of: "/") ?? afterSlashes.endIndex
            var authority = afterSlashes[..<authorityEnd]
            rest = afterSlashes[authorityEnd...]
            if let at = authority.lastIndex(of: "@") {
                authority = authority[authority.index(after: at)...]
            }
            if authority.hasPrefix("["), let close = authority.firstIndex(of: "]") {
                host = String(authority[...close])
            } else if let portColon = authority.lastIndex(of: ":") {
                host = String(authority[..<portColon])
            } else {
                host = String(authority)
            }
        }

        return Components(
            scheme: String(scheme),
            host: host,
            path: rest.isEmpty ? nil : String(rest),
            query: query,
            fragment: fragment
        )
    }

    /// Whether this value has valid Lexicon `uri` syntax. Always `true` for a
    /// decoded value and one created with ``init(validating:)``.
    public func isValid() -> Bool {
        hasValidSyntax
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        guard isValid() else {
            return nil
        }
        return URLQueryItem(name: name, value: uriString())
    }

    /// The URI exactly as it was written.
    public func uriString() -> String {
        originalString ?? ""
    }

    /// Initializer to create URI from URL
    public init(url: URL) {
        self.init(uriString: url.absoluteString)
    }

    /// The URI as a `URL`, or `nil` for a `did:` URI and for a value that is not
    /// a valid URI.
    public var url: URL? {
        guard !isDID, isValid() else { return nil }
        return URL(string: uriString())
    }

    public init(stringLiteral value: String) {
        self.init(uriString: value)
    }

    /// Creates a URI, or returns `nil` if `description` does not have valid
    /// Lexicon `uri` syntax.
    public init?(_ description: String) {
        guard ATProtoSyntax.uriFailure(description) == nil else { return nil }
        self.init(unchecked: description, hasValidSyntax: true)
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

    /// The string to write, refusing to emit something that is not a URI.
    private func checkedString() throws -> String {
        let string = uriString()
        guard hasValidSyntax else {
            let reason = ATProtoSyntax.uriFailure(string) ?? "not a URI"
            throw ATProtocolError.invalidURI("Refusing to encode an invalid URI \(syntaxExcerpt(string)): \(reason)")
        }
        return string
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(checkedString())
    }

    public func toCBORValue() throws -> Any {
        return try checkedString()
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

    /// Creates a blob reference in the current format: `{"$type": "blob", ref, mimeType, size}`.
    public init(ref: ATProtoLink, mimeType: String, size: Int) {
        self.init(type: "blob", ref: ref, mimeType: mimeType, size: size, cid: nil)
    }

    /// Whether this value was read from the deprecated `{"cid": ..., "mimeType": ...}` form.
    ///
    /// The data-model specification asks implementations to keep such a blob in the regular
    /// representation with a negative `size`, and to check that when re-serializing: a
    /// legacy blob is written back exactly as it was read, never as a `$type: blob` object
    /// with a made-up size.
    public var isLegacy: Bool {
        size < 0
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Check if this is the legacy format (has cid but no $type)
        if container.contains(.cid), !container.contains(.type) {
            // Legacy blob format: { "cid": "...", "mimeType": "..." }
            type = "blob"
            ref = nil // Legacy format doesn't have ref
            mimeType = try container.decode(String.self, forKey: .mimeType)
            size = -1 // The legacy marker; the legacy format carries no size.
            cid = try container.decode(String.self, forKey: .cid)
        } else {
            // Modern blob format: { "$type": "blob", "ref": {...}, "mimeType": "...", "size": ... }
            type = try container.decode(String.self, forKey: .type)
            guard type == "blob" else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container, debugDescription: "A blob must have $type \"blob\""
                )
            }
            ref = try container.decode(ATProtoLink.self, forKey: .ref)
            mimeType = try container.decode(String.self, forKey: .mimeType)
            guard !mimeType.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .mimeType, in: container, debugDescription: "A blob's mimeType must not be empty"
                )
            }
            size = try container.decode(Int.self, forKey: .size)
            guard size >= 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .size, in: container, debugDescription: "A blob's size must not be negative"
                )
            }
            cid = try container.decodeIfPresent(String.self, forKey: .cid)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if isLegacy, let cid {
            // Written back exactly as read.
            try container.encode(cid, forKey: .cid)
            try container.encode(mimeType, forKey: .mimeType)
            return
        }
        guard size >= 0 else {
            throw EncodingError.invalidValue(
                size,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "A blob's size must not be negative")
            )
        }
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
        if isLegacy, let cid {
            // Written back exactly as read.
            map.append(key: "cid", value: cid)
            map.append(key: "mimeType", value: mimeType)
            return map
        }
        guard size >= 0 else {
            throw DAGCBORError.encodingFailed("A blob's size must not be negative")
        }
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
                debugDescription: "String is not RFC 4648 base64"
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

        // Bits of the last character that do not complete a byte are ignored, as RFC 4648
        // §3.5 permits and every other atproto implementation does: the official interop
        // vector `lexicon/record-data-valid.json` carries `"$bytes": "123"`.
        let remainder = payload.count % 4
        let canonicalPaddingCount: Int
        switch remainder {
        case 0:
            canonicalPaddingCount = 0
        case 2:
            canonicalPaddingCount = 2
        case 3:
            canonicalPaddingCount = 1
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
        case 65 ... 90:
            return byte - 65
        case 97 ... 122:
            return byte - 97 + 26
        case 48 ... 57:
            return byte - 48 + 52
        case 43:
            return 62
        case 47:
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

/// A decentralized identifier, the Lexicon `did` string format.
///
/// Validation follows "DID Identifier Syntax" in https://atproto.com/specs/did:
/// lowercase `did:`, a method of one or more lowercase letters, then an
/// identifier drawn from `A-Z a-z 0-9 . _ : % -` that does not end in `:` or
/// `%`; at most 2048 characters. The check is byte-exact — no whitespace, line
/// terminator or non-ASCII character is accepted anywhere — and DIDs are
/// case-sensitive, so nothing is normalized.
///
/// Any DID method passes this syntax check, as the Lexicon specification
/// requires. Use ``atprotoMethod`` or ``isAtprotoDID`` to ask whether a DID uses
/// one of the two methods AT Protocol supports (`did:plc`, `did:web`) and meets
/// the protocol's extra rules for it.
///
/// ```swift
/// let did = try DID(didString: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
/// did.method         // "plc"
/// did.atprotoMethod  // .plc
/// DID.isValidDID("did:plc:abc\n")  // false
/// ```
public struct DID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    /// The DID method (`plc`, `web`, `key`, …).
    public let method: String
    /// The first colon-separated segment of the method-specific identifier.
    public let authority: String
    /// Any further colon-separated segments of the method-specific identifier.
    public let segments: [String]
    private let originalString: String

    /// The DID methods AT Protocol supports for account identity.
    public enum AtprotoMethod: String, Sendable, CaseIterable {
        /// `did:plc`, the self-authenticating method developed for atproto.
        case plc
        /// `did:web`, restricted in atproto to a bare hostname.
        case web
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let didString = try container.decode(String.self)
        try self.init(didString: didString)
    }

    /// Parses a DID, throwing ``ATProtocolError/invalidDID(_:)`` with the reason
    /// if the syntax is not valid.
    public init(didString: String) throws {
        if let reason = ATProtoSyntax.didFailure(didString) {
            throw ATProtocolError.invalidDID("Invalid DID \(syntaxExcerpt(didString)): \(reason)")
        }
        originalString = didString

        // Validation guarantees a "did:" prefix, a non-empty method and a non-empty
        // method-specific identifier, so there are always at least two components.
        let components = didString.utf8.dropFirst(4)
            .split(separator: SyntaxByte.colon, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        method = components[0]
        // The method-specific identifier may contain empty colon-separated segments
        // (e.g. "did:method::."), so the authority segment may legitimately be empty.
        authority = components.count > 1 ? components[1] : ""
        segments = components.count > 2 ? Array(components.dropFirst(2)) : []
    }

    /// Builds a DID from its method and method-specific identifier, throwing
    /// ``ATProtocolError/invalidDID(_:)`` if the result is not valid.
    public init(method: String, identifier: String) throws {
        try self.init(didString: "did:\(method):\(identifier)")
    }

    /// Whether `did` has valid DID syntax. Also gates a space URI's authority and
    /// author, which the space grammar requires to be well-formed DIDs.
    public static func isValidDID(_ did: String) -> Bool {
        ATProtoSyntax.didFailure(did) == nil
    }

    /// Everything after `did:<method>:` — for `did:plc:abc` this is `abc`.
    public var methodSpecificIdentifier: String {
        String(originalString.utf8.dropFirst(5 + method.utf8.count)) ?? ""
    }

    /// The atproto-supported method this DID uses, or `nil` if the method is not
    /// supported or the DID does not meet atproto's rules for that method:
    ///
    /// - `did:plc`: the identifier is exactly 24 base32 characters (`a-z`, `2-7`).
    /// - `did:web`: a bare hostname with no path segments and no port; the
    ///   hostname must be a valid handle-style domain outside the reserved
    ///   top-level domains (``Handle/disallowedTLDs``). `localhost`, with an
    ///   optional `%3A<port>` (1–65535), is accepted for development.
    ///
    /// See "Blessed DID Methods" in https://atproto.com/specs/did.
    public var atprotoMethod: AtprotoMethod? {
        DID.atprotoMethod(of: originalString, allowLocalhost: true)
    }

    /// Whether this DID can identify an atproto account; see ``atprotoMethod``.
    public var isAtprotoDID: Bool {
        atprotoMethod != nil
    }

    /// Whether `did` is a syntactically valid DID that uses a method atproto
    /// supports and meets atproto's rules for it; see ``atprotoMethod``.
    ///
    /// - Parameters:
    ///   - did: The string to check.
    ///   - allowLocalhost: Whether `did:web:localhost` (optionally with a port)
    ///     is accepted. The specification allows it only in testing and
    ///     development; pass `false` in production paths.
    public static func isValidAtprotoDID(_ did: String, allowLocalhost: Bool = true) -> Bool {
        atprotoMethod(of: did, allowLocalhost: allowLocalhost) != nil
    }

    private static func atprotoMethod(of did: String, allowLocalhost: Bool) -> AtprotoMethod? {
        guard ATProtoSyntax.didFailure(did) == nil else { return nil }

        if did.hasPrefix("did:plc:") {
            let identifier = did.utf8.dropFirst(8)
            let isBase32 = identifier.allSatisfy { SyntaxByte.isLower($0) || (0x32 ... 0x37).contains($0) }
            return identifier.count == 24 && isBase32 ? .plc : nil
        }

        guard did.hasPrefix("did:web:") else { return nil }
        let identifier = String(did.utf8.dropFirst(8)) ?? ""
        // A colon after the prefix separates path segments, which atproto does not allow.
        guard !identifier.contains(":") else { return nil }

        var host = identifier
        var hasPort = false
        if let escape = identifier.range(of: "%3A", options: .caseInsensitive) {
            let portText = identifier[escape.upperBound...]
            guard !portText.isEmpty, portText.utf8.allSatisfy(SyntaxByte.isDigit),
                  let port = Int(portText), (1 ... 65535).contains(port)
            else {
                return nil
            }
            host = String(identifier[..<escape.lowerBound])
            hasPort = true
        }

        if host.lowercased() == "localhost" {
            return allowLocalhost ? .web : nil
        }
        // A port is only allowed on localhost; the hostname itself follows the
        // handle rules, including the reserved top-level domains.
        guard !hasPort, ATProtoSyntax.handleFailure(host) == nil, Handle.isValidTLD(host.lowercased()) else {
            return nil
        }
        return .web
    }

    public var description: String {
        return originalString
    }

    /// The DID exactly as it was written.
    public func didString() -> String {
        return originalString
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherDID = other as? DID else {
            return false
        }

        return originalString == otherDID.originalString
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(didString())
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: didString())
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(originalString)
    }

    public func toCBORValue() throws -> Any {
        return didString()
    }
}

// MARK: - Handle Identifier

/// A handle (a DNS hostname naming an account), the Lexicon `handle` string format.
///
/// Validation follows "Handle Identifier Syntax" in
/// https://atproto.com/specs/handle: ASCII letters, digits, hyphens and periods
/// only; at least two labels of 1–63 characters, none starting or ending with a
/// hyphen; a final label that starts with a letter; at most 253 characters. The
/// check is byte-exact, so whitespace, line terminators and Unicode look-alikes
/// are rejected.
///
/// Handles are case-insensitive and normalize to lower case: ``value`` is the
/// normalized form and is what equality, hashing and query parameters use.
/// ``wireValue`` keeps the handle as it was written, and is what is re-encoded,
/// so decoding and re-encoding a record never changes its bytes.
///
/// Syntax validity is separate from policy. The reserved top-level domains
/// (``disallowedTLDs``) are valid syntax but must not be registered or resolved;
/// check ``hasDisallowedTLD``.
///
/// ```swift
/// let handle = try Handle(handleString: "Alice.Example.COM")
/// handle.value      // "alice.example.com"
/// handle.wireValue  // "Alice.Example.COM"
/// try Handle(handleString: "laptop.local").hasDisallowedTLD  // true
/// ```
public struct Handle: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    /// The handle normalized to lower case.
    public let value: String

    /// The handle exactly as it was written, before normalization.
    public let wireValue: String

    /// Upstream sentinel for unverified / invalid handle in identity resolution (matches @atproto/syntax INVALID_HANDLE).
    public static let invalid = "handle.invalid"
    /// Same string as ``invalid``.
    @available(*, deprecated, renamed: "invalid")
    public static let invalidHandle = "handle.invalid"

    /// ``invalid`` as a typed handle: the placeholder shown when an account's
    /// handle does not resolve back to its DID.
    public static let invalidSentinel = Handle(validated: invalid)

    /// Whether this is the `handle.invalid` placeholder rather than a real handle.
    public var isInvalidSentinel: Bool {
        value == Handle.invalid
    }

    /// Registration-time restricted TLD suffixes (per upstream @atproto/syntax handle.ts: DISALLOWED_TLDS).
    /// Note: .test is explicitly allowed for testing/development.
    public static let disallowedTLDs: Set<String> = [
        ".alt", ".arpa", ".example", ".internal", ".invalid", ".local", ".localhost", ".onion",
    ]

    /// Registration-time policy check for TLD validity (mirrors upstream @atproto/syntax isValidTld exactly).
    ///
    /// Upstream implementation:
    /// ```ts
    /// export const isValidTld = (handle: string): boolean => {
    ///   for (const tld of DISALLOWED_TLDS) {
    ///     if (handle.endsWith(tld)) {
    ///       return false
    ///     }
    ///   }
    ///   return true
    /// }
    /// ```
    /// Note: Upstream is case-sensitive and checks `endsWith(suffix)` against lowercase
    /// DISALLOWED_TLDS without lowercasing the input (e.g. `isValidTld("SRI-NIC.ARPA")` returns `true`).
    /// This is an upstream quirk preserved for exact interop fidelity.
    public static func isValidTLD(_ handle: String) -> Bool {
        !disallowedTLDs.contains { suffix in
            handle.hasSuffix(suffix)
        }
    }

    /// Registration-time policy check for TLD validity (alias matching upstream naming).
    public static func isValidTld(_ handle: String) -> Bool {
        isValidTLD(handle)
    }

    /// Returns true if this handle's TLD is in the registration-time disallowed list.
    public var hasDisallowedTLD: Bool {
        !Self.isValidTLD(value)
    }

    /// Returns true if this handle's TLD is in the registration-time disallowed list.
    public var hasDisallowedTld: Bool {
        hasDisallowedTLD
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let handleString = try container.decode(String.self)
        try self.init(handleString: handleString)
    }

    /// Parses a handle, throwing ``ATProtocolError/invalidHandle(_:)`` with the
    /// reason if the syntax is not valid.
    public init(handleString: String) throws {
        if let reason = ATProtoSyntax.handleFailure(handleString) {
            throw ATProtocolError.invalidHandle("Invalid handle \(syntaxExcerpt(handleString)): \(reason)")
        }
        self.init(validated: handleString)
    }

    /// Wraps a string already known to be a valid handle.
    private init(validated handleString: String) {
        wireValue = handleString
        // Validated input is ASCII, so this is plain ASCII lower-casing.
        value = handleString.lowercased()
    }

    /// Whether `handle` has valid handle syntax (in any letter case).
    public static func isValidHandle(_ handle: String) -> Bool {
        ATProtoSyntax.handleFailure(handle) == nil
    }

    public var description: String {
        return value
    }

    public static func == (lhs: Handle, rhs: Handle) -> Bool {
        lhs.value == rhs.value
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherHandle = other as? Handle else {
            return false
        }

        return value == otherHandle.value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    public func toCBORValue() throws -> Any {
        return wireValue
    }
}

// MARK: - AT Identifier (either Handle or DID)

/// Either a ``DID`` or a ``Handle``, the Lexicon `at-identifier` string format.
///
/// The two cannot be confused: a DID always starts with `did:` and a handle
/// cannot contain a colon. A string that starts with `did:` is parsed as a DID
/// and anything else as a handle, each under its own rules.
///
/// ```swift
/// let actor = try ATIdentifier(string: "atproto.com")   // .handle
/// let other = try ATIdentifier(string: "did:web:example.com")  // .did
/// ```
public enum ATIdentifier: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: stringValue())
    }

    case did(DID)
    case handle(Handle)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        try self.init(string: string)
    }

    /// Parses a DID or a handle, throwing ``ATProtocolError/invalidDID(_:)`` or
    /// ``ATProtocolError/invalidHandle(_:)`` accordingly.
    public init(string: String) throws {
        if string.utf8.starts(with: "did:".utf8) {
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

    /// The identifier in normalized form: the DID as written, or the handle in
    /// lower case.
    public func stringValue() -> String {
        switch self {
        case let .did(did):
            return did.didString()
        case let .handle(handle):
            return handle.value
        }
    }

    /// The identifier exactly as it was written; this is what is re-encoded.
    public var wireValue: String {
        switch self {
        case let .did(did):
            return did.didString()
        case let .handle(handle):
            return handle.wireValue
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
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
        return wireValue
    }
}

// MARK: - NSID (Namespaced Identifier)

/// A namespaced identifier naming a Lexicon schema, the Lexicon `nsid` string format.
///
/// Validation follows "NSID Syntax" in https://atproto.com/specs/nsid: at least
/// three period-separated segments of 1–63 characters; the leading segments (the
/// reversed domain authority) use letters, digits and
/// hyphens, never start or end with a hyphen, and the first starts with a
/// letter; the final name segment is letters and digits only and starts with a
/// letter; at most 317 characters in total. The check is byte-exact.
///
/// The domain authority is case-insensitive and normalizes to lower case; the
/// name is case-sensitive. The string is stored as written — see ``normalized``.
///
/// ```swift
/// let nsid = try NSID(nsidString: "app.bsky.feed.post")
/// nsid.authority  // "app.bsky.feed"
/// nsid.name       // "post"
/// ```
public struct NSID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    /// The domain authority in the order written (`app.bsky.feed`).
    public let authority: String
    /// The final name segment (`post`).
    public let name: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let nsidString = try container.decode(String.self)
        try self.init(nsidString: nsidString)
    }

    /// Parses an NSID, throwing ``ATProtocolError/invalidNSID(_:)`` with the
    /// reason if the syntax is not valid.
    public init(nsidString: String) throws {
        if let reason = ATProtoSyntax.nsidFailure(nsidString) {
            throw ATProtocolError.invalidNSID("Invalid NSID \(syntaxExcerpt(nsidString)): \(reason)")
        }

        // Validation guarantees at least three non-empty segments.
        let utf8 = nsidString.utf8
        let lastDot = utf8.lastIndex(of: SyntaxByte.dot) ?? utf8.startIndex
        authority = String(nsidString[..<lastDot])
        name = String(nsidString[utf8.index(after: lastDot)...])
    }

    /// Builds an NSID from its domain authority (`app.bsky.feed`) and name
    /// (`post`), throwing ``ATProtocolError/invalidNSID(_:)`` if the result is
    /// not valid.
    public init(authority: String, name: String) throws {
        try self.init(nsidString: "\(authority).\(name)")
    }

    /// Whether `nsid` has valid NSID syntax. Also gates a space URI's type segment.
    public static func isValidNSID(_ nsid: String) -> Bool {
        ATProtoSyntax.nsidFailure(nsid) == nil
    }

    /// The normalized form: domain authority in lower case, name unchanged.
    public var normalized: NSID {
        // Lower-casing ASCII letters cannot invalidate a valid NSID.
        (try? NSID(nsidString: "\(authority.lowercased()).\(name)")) ?? self
    }

    public var description: String {
        return "\(authority).\(name)"
    }

    public func nsidString() -> String {
        return "\(authority).\(name)"
    }

    /// Protocol-level equality: the domain authority is compared without regard
    /// to case, the name exactly. (`==` compares the strings as written.)
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherNSID = other as? NSID else {
            return false
        }

        return authority.lowercased() == otherNSID.authority.lowercased()
            && name == otherNSID.name
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
        hasher.combine(name)
    }

    public func toCBORValue() throws -> Any {
        return nsidString()
    }
}

// MARK: - Record Key

/// A record key, the Lexicon `record-key` string format.
///
/// Validation follows "Record Key Syntax" in
/// https://atproto.com/specs/record-key: 1–512 characters from
/// `A-Z a-z 0-9 . - _ : ~`, and not `.` or `..`. The check is byte-exact. Record
/// keys are case-sensitive and are never normalized.
///
/// ```swift
/// let key = try RecordKey(keyString: "3jzfcijpj2z2a")
/// RecordKey.isValidRecordKey("self\n")  // false
/// ```
public struct RecordKey: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let value: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let keyString = try container.decode(String.self)
        try self.init(keyString: keyString)
    }

    /// Parses a record key, throwing ``ATProtocolError/invalidRecordKey(_:)``
    /// with the reason if the syntax is not valid.
    public init(keyString: String) throws {
        if let reason = ATProtoSyntax.recordKeyFailure(keyString) {
            throw ATProtocolError.invalidRecordKey("Invalid record key \(syntaxExcerpt(keyString)): \(reason)")
        }

        value = keyString
    }

    /// Whether `key` has valid record-key syntax.
    public static func isValidRecordKey(_ key: String) -> Bool {
        ATProtoSyntax.recordKeyFailure(key) == nil
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

// MARK: - TID (Timestamp Identifier)

/// A timestamp identifier, the Lexicon `tid` string format.
///
/// A TID is a 64-bit integer written as 13 characters of the base32-sortable
/// alphabet `234567abcdefghijklmnopqrstuvwxyz` (https://atproto.com/specs/tid).
/// Thirteen characters carry 65 bits, so the first character is limited to
/// `234567abcdefghij`. Within the integer, the top bit is reserved as zero, the
/// next 53 bits are microseconds since the UNIX epoch and the low 10 bits are a
/// clock identifier. TIDs sort the same way as strings and as integers, and
/// therefore by time.
///
/// The first-character rule is the whole of the syntax check, and it is slightly
/// wider than the layout: `c` through `j` set the reserved top bit. Such a
/// string is accepted, as the specification's syntax requires, and reports
/// ``hasHighBitSet``; ``TIDGenerator`` never produces one.
///
/// ```swift
/// let tid = try TID(tidString: "3jzfcijpj2z2a")
/// tid.timestampMicros  // microseconds since 1970
/// tid.clockID          // 0...1023
/// let next = await TIDGenerator.shared.nextTID()
/// ```
public struct TID: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible, Comparable {
    /// The 64-bit integer the 13 characters encode.
    private let value: UInt64
    /// Original string representation
    private let originalString: String

    private static let timestampMask: UInt64 = 0x1F_FFFF_FFFF_FFFF

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let tidString = try container.decode(String.self)

        try self.init(tidString: tidString)
    }

    /// Parses a TID, throwing ``ATProtocolError/invalidTID(_:)`` with the reason
    /// if the syntax is not valid.
    public init(tidString: String) throws {
        switch ATProtoSyntax.tidValue(tidString) {
        case let .success(value):
            self.value = value
            originalString = tidString
        case let .failure(failure):
            throw ATProtocolError.invalidTID("Invalid TID \(syntaxExcerpt(tidString)): \(failure.reason)")
        }
    }

    /// Builds a TID from its parts, throwing ``ATProtocolError/invalidTID(_:)``
    /// if the timestamp does not fit in 53 bits or the clock identifier in 10.
    public init(timestampMicros: UInt64, clockID: UInt16) throws {
        guard timestampMicros <= TID.timestampMask else {
            throw ATProtocolError.invalidTID("Invalid TID: timestamp \(timestampMicros) does not fit in 53 bits")
        }
        guard clockID < 1024 else {
            throw ATProtocolError.invalidTID("Invalid TID: clock identifier \(clockID) is not in 0...1023")
        }
        self.init(timestampBits: timestampMicros, clockBits: UInt64(clockID))
    }

    /// Builds a TID from parts the caller has already range-checked.
    init(timestampBits: UInt64, clockBits: UInt64) {
        value = (timestampBits & TID.timestampMask) << 10 | (clockBits & 0x3FF)
        originalString = ATProtoSyntax.tidString(value)
    }

    /// Microseconds since the UNIX epoch (the 53-bit timestamp field).
    public var timestampMicros: UInt64 {
        (value >> 10) & TID.timestampMask
    }

    /// Whether the top bit of the 64-bit value is set, which the TID layout
    /// reserves as zero. True exactly when the first character is one of
    /// `cdefghij`. Such a TID is valid syntax but cannot come from a conforming
    /// generator, sorts after every TID that can, and loses that bit if rebuilt
    /// from ``timestampMicros`` and ``clockID``.
    public var hasHighBitSet: Bool {
        value >> 63 == 1
    }

    /// The 10-bit clock identifier (0–1023) of the generator that made this TID.
    public var clockID: UInt16 {
        UInt16(value & 0x3FF)
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

        return value == otherTID.value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(originalString)
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: originalString)
    }

    /// The timestamp as a `Date`.
    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(timestampMicros) / 1_000_000.0)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    /// Orders TIDs by their integer value, which is also their string order.
    public static func < (lhs: TID, rhs: TID) -> Bool {
        lhs.value < rhs.value
    }

    /// Whether `str` has valid TID syntax.
    public static func isValid(_ str: String) -> Bool {
        if case .success = ATProtoSyntax.tidValue(str) { return true }
        return false
    }

    /// Whether `tid` has valid TID syntax; same as ``isValid(_:)``, named like the
    /// validators of the other identifier types.
    public static func isValidTID(_ tid: String) -> Bool {
        isValid(tid)
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

extension Dictionary: DAGCBOREncodable where Key == String, Value: DAGCBOREncodable {
    public func toCBORValue() throws -> Any {
        let sortedKeys = keys.sorted { lhs, rhs in
            let lhsCount = lhs.utf8.count
            let rhsCount = rhs.utf8.count
            return lhsCount == rhsCount ? lhs < rhs : lhsCount < rhsCount
        }
        var map = OrderedCBORMap(minimumCapacity: count)
        for key in sortedKeys {
            map.append(key: key, value: try self[key]!.toCBORValue())
        }
        return map
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
