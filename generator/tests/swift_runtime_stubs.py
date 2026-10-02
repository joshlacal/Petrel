"""Minimal stand-ins for Petrel runtime helpers referenced by generated Swift.

Tests that compile generated declarations against a hand-written prelude (instead of the
real Petrel module) interpolate LEXICON_DECODING_STUBS so the generated decoders find
`LexiconCodingKey`, `_LexiconStringArray`/`_LexiconIntArray` and
`_LexiconDecodeDiagnostics` (Sources/Petrel/Core/Types/LexiconDecoding.swift).
"""

import textwrap

_STUBS = """
public struct LexiconCodingKey: CodingKey, Sendable, ExpressibleByStringLiteral {
    public let stringValue: String
    public var intValue: Int? { nil }
    public init(stringValue: String) { self.stringValue = stringValue }
    public init?(intValue _: Int) { nil }
    public init(stringLiteral value: String) { stringValue = value }
    public init(_ stringValue: String) { self.stringValue = stringValue }
    public var description: String { "CodingKeys(stringValue: \\"\\(stringValue)\\", intValue: nil)" }
    public var debugDescription: String { description }
}
public struct _LexiconStringArray: Decodable, Sendable {
    public let values: [String]
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [String] = []
        while !container.isAtEnd { try values.append(container.decode(String.self)) }
        self.values = values
    }
}
public struct _LexiconIntArray: Decodable, Sendable {
    public let values: [Int]
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Int] = []
        while !container.isAtEnd { try values.append(container.decode(Int.self)) }
        self.values = values
    }
}
public enum _LexiconDecodeDiagnostics {
    public static func optionalPropertyDegraded(_ property: StaticString, _ error: any Error) {}
    public static func requiredPropertyFailed(_ property: StaticString, _ error: any Error) {}
    public static func requiredSubStructPropertyFailed(_ property: StaticString, _ error: any Error) {}
    public static func successfulResponseDecodeFailed(_ endpoint: StaticString, _ error: any Error) {}
}
"""

LEXICON_DECODING_STUBS = textwrap.indent(_STUBS.strip("\n"), " " * 12)
