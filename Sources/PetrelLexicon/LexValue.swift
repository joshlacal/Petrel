import Foundation
import PetrelCore

/// A value of the AT Protocol data model.
///
/// `LexValue` is the strict, schema-agnostic representation that every
/// PetrelLexicon entry point works on. It models exactly the eight kinds the
/// data model allows (null, boolean, integer, string, bytes, link, array,
/// object) and nothing else: there is no float case, bytes and links are
/// first-class instead of `$bytes` / `$link` look-alike objects, and a blob is
/// an object whose shape was checked when the value was built.
///
/// Build one with ``init(json:options:)`` (strict JSON), ``init(dagCBOR:options:)``
/// (strict DAG-CBOR / DRISL), ``init(encoding:options:)`` (any `Encodable`), or a
/// Swift literal:
///
/// ```swift
/// let record: LexValue = ["$type": "app.bsky.feed.post", "text": "hi", "langs": ["en"]]
/// ```
public enum LexValue: Sendable, Hashable {
    /// The `null` value.
    case null
    /// A boolean.
    case boolean(Bool)
    /// A signed 64-bit integer. Floats are not part of the data model.
    case integer(Int64)
    /// A Unicode string.
    case string(String)
    /// Raw bytes (`{"$bytes": "<base64>"}` in JSON, a byte string in DAG-CBOR).
    case bytes(Data)
    /// A CID link (`{"$link": "<cid>"}` in JSON, tag 42 in DAG-CBOR).
    case cidLink(CID)
    /// An ordered list of values.
    case array([LexValue])
    /// A map with string keys.
    case object([String: LexValue])
}

// MARK: - Accessors

public extension LexValue {
    /// The name of this value's data-model kind, as used in error messages
    /// (`null`, `boolean`, `integer`, `string`, `bytes`, `cid-link`, `array`,
    /// `blob` or `object`).
    var kind: String {
        switch self {
        case .null: return "null"
        case .boolean: return "boolean"
        case .integer: return "integer"
        case .string: return "string"
        case .bytes: return "bytes"
        case .cidLink: return "cid-link"
        case .array: return "array"
        case .object: return blobRef == nil ? "object" : "blob"
        }
    }

    /// `true` when the value is ``null``.
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// The wrapped boolean, or `nil` for any other kind.
    var boolValue: Bool? {
        if case let .boolean(value) = self { return value }
        return nil
    }

    /// The wrapped integer, or `nil` for any other kind.
    var integerValue: Int64? {
        if case let .integer(value) = self { return value }
        return nil
    }

    /// The wrapped string, or `nil` for any other kind.
    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// The wrapped bytes, or `nil` for any other kind.
    var bytesValue: Data? {
        if case let .bytes(value) = self { return value }
        return nil
    }

    /// The wrapped CID, or `nil` for any other kind.
    var cidValue: CID? {
        if case let .cidLink(value) = self { return value }
        return nil
    }

    /// The wrapped array, or `nil` for any other kind.
    var arrayValue: [LexValue]? {
        if case let .array(value) = self { return value }
        return nil
    }

    /// The wrapped map, or `nil` for any other kind.
    var objectValue: [String: LexValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    /// The object's `$type` discriminator, when this is an object that has one.
    var type: String? {
        self["$type"]?.stringValue
    }

    /// Looks up a property of an object. Returns `nil` for a missing key and
    /// for every non-object value.
    subscript(key: String) -> LexValue? {
        if case let .object(fields) = self { return fields[key] }
        return nil
    }

    /// Looks up an element of an array. Returns `nil` when out of range and for
    /// every non-array value.
    subscript(index: Int) -> LexValue? {
        if case let .array(items) = self, items.indices.contains(index) { return items[index] }
        return nil
    }

    /// The blob reference this object represents, when it is a well-formed
    /// `$type: "blob"` object.
    var blobRef: LexBlobRef? {
        guard case let .object(fields) = self, fields["$type"]?.stringValue == "blob" else { return nil }
        return try? LexBlobRef(typedFields: fields)
    }

    /// Every blob reference nested anywhere in this value, in depth-first
    /// order with object keys sorted.
    var blobRefs: [LexBlobRef] {
        var found: [LexBlobRef] = []
        collectBlobRefs(into: &found)
        return found
    }

    private func collectBlobRefs(into found: inout [LexBlobRef]) {
        switch self {
        case let .array(items):
            for item in items {
                item.collectBlobRefs(into: &found)
            }
        case let .object(fields):
            if let blob = try? LexBlobRef(typedFields: fields) {
                found.append(blob)
                return
            }
            for key in fields.keys.sorted() {
                fields[key]?.collectBlobRefs(into: &found)
            }
        default:
            break
        }
    }
}

// MARK: - Blob references

/// A blob reference: the `$type: "blob"` object the data model defines for
/// files stored next to a repository.
public struct LexBlobRef: Sendable, Hashable {
    /// CID of the blob's bytes.
    public let ref: CID
    /// Declared MIME type. Never empty.
    public let mimeType: String
    /// Size in bytes, or `nil` for a legacy `{cid, mimeType}` reference, which
    /// carries no size.
    public let size: Int64?

    /// Creates a blob reference.
    ///
    /// - Throws: ``LexValueError`` with code ``LexValueError/Code/malformedBlob``
    ///   when `mimeType` is empty or `size` is negative.
    public init(ref: CID, mimeType: String, size: Int64) throws {
        guard !mimeType.isEmpty else {
            throw LexValueError(.malformedBlob, path: "/mimeType", "blob mimeType must not be empty")
        }
        guard size >= 0 else {
            throw LexValueError(.malformedBlob, path: "/size", "blob size must not be negative")
        }
        self.ref = ref
        self.mimeType = mimeType
        self.size = size
    }

    init(legacyCID: CID, mimeType: String) {
        ref = legacyCID
        self.mimeType = mimeType
        size = nil
    }

    /// `true` when ``ref`` uses the `raw` multicodec, which is the only codec
    /// the blob specification blesses for blob references.
    public var hasRawCodec: Bool {
        ref.codec == .raw
    }

    /// `true` for the deprecated `{cid, mimeType}` form.
    public var isLegacy: Bool {
        size == nil
    }

    /// The data-model object for this reference. A legacy reference is written
    /// back in its legacy form; the typed form is never synthesised with a
    /// made-up size.
    public var value: LexValue {
        guard let size else {
            return .object(["cid": .string(ref.string), "mimeType": .string(mimeType)])
        }
        return .object([
            "$type": .string("blob"),
            "ref": .cidLink(ref),
            "mimeType": .string(mimeType),
            "size": .integer(size),
        ])
    }

    /// Reads a typed blob from the fields of an object, enforcing the shape the
    /// data model requires. Extra fields are tolerated.
    init(typedFields fields: [String: LexValue]) throws {
        guard fields["$type"]?.stringValue == "blob" else {
            throw LexValueError(.malformedBlob, path: "/$type", "blob $type must be \"blob\"")
        }
        guard let ref = fields["ref"]?.cidValue else {
            throw LexValueError(.malformedBlob, path: "/ref", "blob ref must be a CID link")
        }
        guard let mimeType = fields["mimeType"]?.stringValue, !mimeType.isEmpty else {
            throw LexValueError(.malformedBlob, path: "/mimeType", "blob mimeType must be a non-empty string")
        }
        guard let size = fields["size"]?.integerValue, size >= 0 else {
            throw LexValueError(.malformedBlob, path: "/size", "blob size must be a non-negative integer")
        }
        self.ref = ref
        self.mimeType = mimeType
        self.size = size
    }

    /// Reads a legacy `{cid, mimeType}` blob. The legacy form has no `$type`,
    /// so it can only be recognised where a schema says a blob is expected.
    init?(legacyFields fields: [String: LexValue]) {
        guard fields.count == 2,
              let cidString = fields["cid"]?.stringValue,
              let mimeType = fields["mimeType"]?.stringValue, !mimeType.isEmpty,
              let cid = try? LexCID.parseBlessed(cidString)
        else {
            return nil
        }
        self.init(legacyCID: cid, mimeType: mimeType)
    }
}

// MARK: - Parsing options and errors

public extension LexValue {
    /// Knobs for the strict parsers. The defaults accept exactly what the
    /// official `data-model` interop vectors accept.
    struct ParseOptions: Sendable, Hashable {
        /// Maximum nesting depth of arrays and objects. Deeper input is
        /// rejected instead of recursing without bound.
        public var maximumDepth: Int
        /// When `true`, a `$type: "blob"` object whose `ref` is not a `raw`
        /// CID is rejected. The blob specification requires `raw`, but
        /// deployed records and the official `record-data-valid.json` vector
        /// carry `dag-cbor` references, so the default is `false`.
        public var requireRawBlobCIDs: Bool
        /// When `true` (the default), links must be "blessed" CIDs: version 1,
        /// `dag-cbor` or `raw` codec, SHA-256 with a 32-byte digest.
        public var requireBlessedCIDs: Bool

        /// Creates parse options.
        public init(
            maximumDepth: Int = 128,
            requireRawBlobCIDs: Bool = false,
            requireBlessedCIDs: Bool = true
        ) {
            self.maximumDepth = maximumDepth
            self.requireRawBlobCIDs = requireRawBlobCIDs
            self.requireBlessedCIDs = requireBlessedCIDs
        }

        /// The default options.
        public static let standard = ParseOptions()
    }
}

/// Why a piece of JSON, DAG-CBOR or Swift data is not a valid data-model value.
public struct LexValueError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The reason category.
    public enum Code: String, Sendable, Hashable, CaseIterable {
        /// The input is not syntactically valid JSON.
        case malformedJSON
        /// The input is not valid DAG-CBOR (DRISL): wrong framing, a
        /// non-canonical encoding, an unsupported tag, trailing bytes.
        case malformedCBOR
        /// A number has a fractional part or an exponent that does not reduce
        /// to an integer.
        case floatNotAllowed
        /// An integer does not fit in 64 signed bits.
        case integerOutOfRange
        /// An object repeats a key.
        case duplicateKey
        /// `$type` is present but is not a non-empty string.
        case invalidType
        /// A `$link` object is not exactly `{"$link": "<cid>"}`.
        case malformedLink
        /// A link's CID does not parse, or is not a blessed CID.
        case invalidCID
        /// A `$bytes` object is not exactly `{"$bytes": "<base64>"}`.
        case malformedBytes
        /// A `$type: "blob"` object does not have the blob shape.
        case malformedBlob
        /// The value nests deeper than the configured limit.
        case depthLimitExceeded
        /// A record or other top-level value must be an object and is not.
        case notAnObject
        /// A Swift value could not be encoded to JSON.
        case encodingFailed
    }

    /// The reason category.
    public let code: Code
    /// JSON pointer to the offending value (`""` is the root).
    public let path: String
    /// Human-readable detail.
    public let message: String

    /// Creates an error.
    public init(_ code: Code, path: String, _ message: String) {
        self.code = code
        self.path = path
        self.message = message
    }

    /// A single-line, human-readable rendering.
    public var description: String {
        "\(code.rawValue) at \(path.isEmpty ? "/" : path): \(message)"
    }
}

// MARK: - Shared data-model rules

extension LexValue {
    /// Applies the data-model rules to a freshly decoded map: recognises
    /// `$link` and `$bytes`, checks `$type`, and checks the blob shape.
    ///
    /// - Parameter fromJSON: `$link` / `$bytes` are JSON-only spellings. In
    ///   DAG-CBOR a map using those keys is ambiguous on the way back to JSON,
    ///   so it is rejected there.
    static func normalizedObject(
        _ fields: [String: LexValue],
        path: String,
        options: ParseOptions,
        fromJSON: Bool
    ) throws -> LexValue {
        if let link = fields["$link"] {
            guard fromJSON else {
                throw LexValueError(.malformedLink, path: path, "a DAG-CBOR map must not use the JSON-only \"$link\" key")
            }
            guard fields.count == 1 else {
                throw LexValueError(.malformedLink, path: path, "a $link object must have no other fields")
            }
            guard case let .string(cidString) = link else {
                throw LexValueError(.malformedLink, path: path + "/$link", "$link must be a string")
            }
            return try .cidLink(LexCID.parseLink(cidString, path: path + "/$link", options: options))
        }
        if let bytes = fields["$bytes"] {
            guard fromJSON else {
                throw LexValueError(.malformedBytes, path: path, "a DAG-CBOR map must not use the JSON-only \"$bytes\" key")
            }
            guard fields.count == 1 else {
                throw LexValueError(.malformedBytes, path: path, "a $bytes object must have no other fields")
            }
            guard case let .string(encoded) = bytes else {
                throw LexValueError(.malformedBytes, path: path + "/$bytes", "$bytes must be a string")
            }
            guard let decoded = LexBase64.decode(encoded) else {
                throw LexValueError(.malformedBytes, path: path + "/$bytes", "$bytes is not valid base64")
            }
            return .bytes(decoded)
        }
        if let type = fields["$type"] {
            guard case let .string(typeString) = type, !typeString.isEmpty else {
                throw LexValueError(.invalidType, path: path + "/$type", "$type must be a non-empty string")
            }
            if typeString == "blob" {
                do {
                    let blob = try LexBlobRef(typedFields: fields)
                    if options.requireRawBlobCIDs, !blob.hasRawCodec {
                        throw LexValueError(.malformedBlob, path: "/ref", "blob ref must use the raw codec")
                    }
                } catch let error as LexValueError {
                    throw LexValueError(error.code, path: path + error.path, error.message)
                }
            }
        }
        return .object(fields)
    }

    /// Re-checks a value that was assembled in Swift (for example from
    /// literals) against the same rules the parsers apply.
    ///
    /// - Throws: ``LexValueError`` describing the first violation.
    public func checkDataModel(options: ParseOptions = .standard) throws {
        try checkDataModel(path: "", depth: 0, options: options)
    }

    private func checkDataModel(path: String, depth: Int, options: ParseOptions) throws {
        guard depth <= options.maximumDepth else {
            throw LexValueError(.depthLimitExceeded, path: path, "value nests deeper than \(options.maximumDepth)")
        }
        switch self {
        case .null, .boolean, .integer, .string, .bytes:
            return
        case let .cidLink(cid):
            if options.requireBlessedCIDs, !LexCID.isBlessed(cid) {
                throw LexValueError(.invalidCID, path: path, "link is not a blessed CID")
            }
        case let .array(items):
            for (index, item) in items.enumerated() {
                try item.checkDataModel(path: LexPath.appending(path, index), depth: depth + 1, options: options)
            }
        case let .object(fields):
            // Sorted so the first violation reported is always the same one.
            for key in fields.keys.sorted() {
                try fields[key]?.checkDataModel(path: LexPath.appending(path, key), depth: depth + 1, options: options)
            }
            if fields["$link"] != nil {
                throw LexValueError(.malformedLink, path: path, "\"$link\" is reserved: use LexValue.cidLink")
            }
            if fields["$bytes"] != nil {
                throw LexValueError(.malformedBytes, path: path, "\"$bytes\" is reserved: use LexValue.bytes")
            }
            _ = try LexValue.normalizedObject(fields, path: path, options: options, fromJSON: false)
        }
    }
}

/// JSON-pointer helpers shared by every error type in the module.
enum LexPath {
    /// Escapes one reference token per RFC 6901.
    static func escape(_ token: String) -> String {
        guard token.contains("~") || token.contains("/") else { return token }
        return token.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
    }

    static func appending(_ path: String, _ token: String) -> String {
        path + "/" + escape(token)
    }

    static func appending(_ path: String, _ index: Int) -> String {
        "\(path)/\(index)"
    }
}

// MARK: - CID rules

/// CID checks that go beyond what `PetrelCore.CID.parse` enforces.
enum LexCID {
    /// Version 1, `dag-cbor` or `raw`, SHA-256 with a 32-byte digest.
    static func isBlessed(_ cid: CID) -> Bool {
        (cid.codec == .dagCBOR || cid.codec == .raw)
            && cid.multihash.algorithm == Multihash.sha256Code
            && cid.multihash.length == Multihash.sha256Length
            && cid.multihash.digest.count == Int(Multihash.sha256Length)
    }

    /// Parses a base32 (`b…`) CID string and requires it to be in canonical
    /// form: lower-case, no padding, no stray trailing bits.
    static func parseCanonical(_ string: String) -> CID? {
        guard string.utf8.count <= 2048, let cid = try? CID.parse(string), cid.string == string else {
            return nil
        }
        return cid
    }

    static func parseBlessed(_ string: String) throws -> CID {
        guard let cid = parseCanonical(string), isBlessed(cid) else {
            throw LexValueError(.invalidCID, path: "", "not a blessed CID")
        }
        return cid
    }

    static func parseLink(_ string: String, path: String, options: LexValue.ParseOptions) throws -> CID {
        guard let cid = parseCanonical(string) else {
            throw LexValueError(.invalidCID, path: path, "$link is not a valid base32 CIDv1")
        }
        if options.requireBlessedCIDs, !isBlessed(cid) {
            throw LexValueError(.invalidCID, path: path, "$link is not a blessed CID (v1, dag-cbor or raw, sha-256)")
        }
        return cid
    }
}

// MARK: - Base64

/// RFC 4648 §4 base64 with optional padding, as the data model specifies for
/// `$bytes`.
enum LexBase64 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    private static let reverse: [UInt8] = {
        var table = [UInt8](repeating: 0xFF, count: 256)
        for (index, byte) in alphabet.enumerated() {
            table[Int(byte)] = UInt8(index)
        }
        return table
    }()

    /// Decodes standard-alphabet base64. Padding is optional but, when
    /// present, must be well-formed. Unused trailing bits are ignored, as
    /// every deployed decoder does (the official `record-data-valid.json`
    /// vector contains `"$bytes": "123"`).
    static func decode(_ string: String) -> Data? {
        var bytes = Array(string.utf8)
        if let firstPadding = bytes.firstIndex(of: UInt8(ascii: "=")) {
            let padding = bytes.count - firstPadding
            guard padding <= 2, bytes[firstPadding...].allSatisfy({ $0 == UInt8(ascii: "=") }), bytes.count % 4 == 0 else {
                return nil
            }
            bytes.removeLast(padding)
        }
        guard bytes.count % 4 != 1 else { return nil }
        var output = Data()
        output.reserveCapacity(bytes.count * 3 / 4)
        var accumulator: UInt32 = 0
        var bits = 0
        for byte in bytes {
            let value = reverse[Int(byte)]
            guard value != 0xFF else { return nil }
            accumulator = (accumulator << 6) | UInt32(value)
            bits += 6
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> UInt32(bits)) & 0xFF))
            }
        }
        return output
    }

    /// Encodes without padding, matching the reference implementations.
    static func encode(_ data: Data) -> String {
        var output = [UInt8]()
        output.reserveCapacity((data.count * 4 + 2) / 3)
        var accumulator: UInt32 = 0
        var bits = 0
        for byte in data {
            accumulator = (accumulator << 8) | UInt32(byte)
            bits += 8
            while bits >= 6 {
                bits -= 6
                output.append(alphabet[Int((accumulator >> UInt32(bits)) & 0x3F)])
            }
        }
        if bits > 0 {
            output.append(alphabet[Int((accumulator << UInt32(6 - bits)) & 0x3F)])
        }
        return String(decoding: output, as: UTF8.self)
    }
}

// MARK: - Literals

extension LexValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    /// Creates ``null`` from `nil`.
    public init(nilLiteral _: ()) {
        self = .null
    }

    /// Creates a ``boolean(_:)`` from a literal.
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }

    /// Creates an ``integer(_:)`` from a literal.
    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }

    /// Creates a ``string(_:)`` from a literal.
    public init(stringLiteral value: String) {
        self = .string(value)
    }

    /// Creates an ``array(_:)`` from a literal.
    public init(arrayLiteral elements: LexValue...) {
        self = .array(elements)
    }

    /// Builds an object. When a key is repeated the last value wins.
    public init(dictionaryLiteral elements: (String, LexValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}
