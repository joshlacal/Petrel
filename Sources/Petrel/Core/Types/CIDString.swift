import Foundation

/// A string in the Lexicon `cid` format: the text form of a content identifier.
///
/// Generated types use it for every property declared `{"type": "string", "format": "cid"}`,
/// such as the `cid` of a `com.atproto.repo.strongRef` or of a post view. The value is the
/// string exactly as it appeared on the wire, checked against the `cid` syntax
/// (``CIDSyntax``), so decoding and re-encoding never changes it.
///
/// It is deliberately not a `CID`. The syntax admits any multibase and any CID version or
/// hash, while `CID` parses only the forms atproto blesses for links (CIDv1, base32,
/// `dag-cbor` or `raw`, SHA-256). A record that mentions some other well-formed CID is still
/// valid data and must decode. Use ``cid`` when the parsed identifier is needed:
///
/// ```swift
/// let ref = ComAtprotoRepoStrongRef(uri: uri, cid: try CIDString(cidString: "bafyrei…"))
/// ref.cid.string            // the text, verbatim
/// ref.cid.cid?.codec        // the parsed CID, nil unless it is a blessed atproto CID
/// ```
///
/// A `cid-link` field is a different thing: a link in the data model (`{"$link": …}` in
/// JSON, tag 42 in DAG-CBOR), typed `ATProtoLink`.
public struct CIDString: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    /// The CID text, exactly as written.
    public let string: String

    /// Wraps a string, throwing ``ATProtocolError/invalidCID(_:)`` with the reason if it
    /// does not have `cid` syntax.
    public init(cidString: String) throws {
        try CIDSyntax.validate(cidString)
        string = cidString
    }

    /// The text form of a parsed CID.
    public init(_ cid: CID) {
        string = cid.string
    }

    /// Whether `string` has valid `cid` syntax.
    public static func isValid(_ string: String) -> Bool {
        CIDSyntax.isValid(string)
    }

    /// The parsed content identifier, or `nil` when the string is well-formed but not a CID
    /// in the form atproto blesses (CIDv1 in base32 with a `dag-cbor` or `raw` codec and a
    /// SHA-256 hash).
    public var cid: CID? {
        try? CID.parse(string)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(cidString: container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    public var description: String {
        string
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? CIDString else { return false }
        return string == other.string
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(string)
    }

    public func toCBORValue() throws -> Any {
        string
    }

    public func asQueryItem(name: String) -> URLQueryItem? {
        URLQueryItem(name: name, value: string)
    }

    /// Whether a `cid` string and a parsed CID name the same content, compared as text.
    public static func == (lhs: CIDString, rhs: CID) -> Bool {
        lhs.string == rhs.string
    }

    /// Whether a parsed CID and a `cid` string name the same content, compared as text.
    public static func == (lhs: CID, rhs: CIDString) -> Bool {
        lhs.string == rhs.string
    }
}
