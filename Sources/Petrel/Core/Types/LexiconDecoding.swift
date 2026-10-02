import Foundation

// Support types for generated Lexicon model decoding.
//
// Generated `init(from:)` implementations (lexiconDefinitions.jinja, properties.jinja,
// record.jinja), union enums (unionEnum.jinja, unionArray.jinja) and endpoint outputs use
// these helpers. They are public because overlay packages (for example PetrelCatbird) are
// generated from the same templates into other modules.

// MARK: - Shared coding key

/// A string-only coding key shared by all generated Lexicon object models.
///
/// Generated objects decode through `init(_lexiconContainer:)`, which takes a
/// `KeyedDecodingContainer<LexiconCodingKey>`. A union can therefore read `$type` and hand
/// the same container to the selected variant, so Foundation materializes the object's
/// keys once instead of once for the union and again for the variant.
///
/// The textual forms (`description`, `debugDescription`) intentionally match the
/// synthesized `CodingKey` description of the per-type `CodingKeys` enums this key
/// replaces on the decode side (`CodingKeys(stringValue: "text", intValue: nil)`), so
/// decoding-error messages and logged coding paths are unchanged. The key is 16 bytes, so
/// it stays inline in `any CodingKey` existentials (coding-path nodes) without boxing.
public struct LexiconCodingKey: CodingKey, Sendable, ExpressibleByStringLiteral {
    public let stringValue: String

    @inlinable
    public var intValue: Int? {
        nil
    }

    @inlinable
    public init(stringValue: String) {
        self.stringValue = stringValue
    }

    @inlinable
    public init?(intValue _: Int) {
        nil
    }

    /// String literals produce immortal `String` storage, so generated
    /// `forKey: "name"` keys cost no allocation.
    @inlinable
    public init(stringLiteral value: String) {
        stringValue = value
    }

    @inlinable
    public init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    public var description: String {
        "CodingKeys(stringValue: \"\(stringValue)\", intValue: nil)"
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Primitive arrays

/// Decodes a JSON array of strings through the unkeyed container's concrete
/// `decode(String.self)` requirement instead of `Array<String>.init(from:)`.
///
/// `Array.init(from:)` calls the generic `decode<T>(_:)` requirement for each element, which
/// in Foundation's JSONDecoder pushes a coding-path node and re-enters through
/// `String.init(from:)`; the concrete requirement reaches the same string parser directly.
/// Accepted values, thrown error types, messages and coding paths are identical: both paths
/// open the container with `decoder.unkeyedContainer()` and finish in the same
/// `unwrapString`/`unwrapFixedWidthInteger` helpers with the same element path.
public struct _LexiconStringArray: Decodable, Sendable {
    public let values: [String]

    @inlinable
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [String] = []
        if let count = container.count {
            values.reserveCapacity(count)
        }
        while !container.isAtEnd {
            try values.append(container.decode(String.self))
        }
        self.values = values
    }
}

/// `Int` counterpart of `_LexiconStringArray`.
public struct _LexiconIntArray: Decodable, Sendable {
    public let values: [Int]

    @inlinable
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Int] = []
        if let count = container.count {
            values.reserveCapacity(count)
        }
        while !container.isAtEnd {
            try values.append(container.decode(Int.self))
        }
        self.values = values
    }
}

// MARK: - Cold-path diagnostics

/// Out-of-line logging for generated decoders.
///
/// Every generated property decode used to carry its own `@autoclosure` message builder
/// for the `catch` path. Routing those through these `@inline(never)` functions keeps a
/// single copy of the message formatting while producing byte-identical log text.
public enum _LexiconDecodeDiagnostics {
    /// `Decoding error for optional property '<name>' — degrading to nil: <error>` (warning).
    @inline(never)
    public static func optionalPropertyDegraded(_ property: StaticString, _ error: any Error) {
        LogManager.logWarning(optionalPropertyDegradedMessage(property, error))
    }

    /// `Decoding error for required property '<name>': <error>` (error).
    @inline(never)
    public static func requiredPropertyFailed(_ property: StaticString, _ error: any Error) {
        LogManager.logError(requiredPropertyFailedMessage(property, error))
    }

    /// `Decoding error for required sub-struct property '<name>': <error>` (error).
    @inline(never)
    public static func requiredSubStructPropertyFailed(_ property: StaticString, _ error: any Error) {
        LogManager.logError(requiredSubStructPropertyFailedMessage(property, error))
    }

    /// `Failed to decode successful response for <endpoint>: <error>` (error).
    @inline(never)
    public static func successfulResponseDecodeFailed(_ endpoint: StaticString, _ error: any Error) {
        LogManager.logError(successfulResponseDecodeFailedMessage(endpoint, error))
    }

    // Message builders, kept separate so tests can pin the exact text the generated
    // code logged before these helpers existed.

    static func optionalPropertyDegradedMessage(_ property: StaticString, _ error: any Error) -> String {
        "Decoding error for optional property '\(property)' — degrading to nil: \(error)"
    }

    static func requiredPropertyFailedMessage(_ property: StaticString, _ error: any Error) -> String {
        "Decoding error for required property '\(property)': \(error)"
    }

    static func requiredSubStructPropertyFailedMessage(_ property: StaticString, _ error: any Error) -> String {
        "Decoding error for required sub-struct property '\(property)': \(error)"
    }

    static func successfulResponseDecodeFailedMessage(_ endpoint: StaticString, _ error: any Error) -> String {
        "Failed to decode successful response for \(endpoint): \(error)"
    }
}
