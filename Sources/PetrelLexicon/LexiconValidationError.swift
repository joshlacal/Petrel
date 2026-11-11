import Foundation

/// One way in which a value fails its Lexicon schema.
public struct LexiconValidationIssue: Sendable, Hashable, CustomStringConvertible {
    /// The reason category. Stable, and safe to switch over.
    public enum Code: String, Sendable, Hashable, CaseIterable {
        /// The value has the wrong data-model kind (a string where an integer
        /// is expected, a non-object where an object is expected…).
        case typeMismatch
        /// The value is `null` and the property is not listed in `nullable`.
        case nullNotAllowed
        /// A property listed in `required` is absent.
        case missingRequiredProperty
        /// `$type` is required here (a record, a union variant) and is absent
        /// or not a string.
        case missingTypeDiscriminator
        /// `$type` is present but wrong: it does not name the expected record
        /// type, or it carries a `#main` suffix.
        case invalidTypeDiscriminator
        /// `$type` names a type that is not one of a closed union's variants.
        case unionVariantNotAllowed
        /// A string is shorter than `minLength` UTF-8 bytes.
        case stringTooShort
        /// A string is longer than `maxLength` UTF-8 bytes.
        case stringTooLong
        /// A string has fewer than `minGraphemes` grapheme clusters.
        case stringTooFewGraphemes
        /// A string has more than `maxGraphemes` grapheme clusters.
        case stringTooManyGraphemes
        /// A string does not match its `format`.
        case stringFormatMismatch
        /// A string or integer is not one of the `enum` values.
        case valueNotInEnum
        /// A value differs from the definition's `const`.
        case valueNotConst
        /// An integer is below `minimum`.
        case integerTooSmall
        /// An integer is above `maximum`.
        case integerTooLarge
        /// Bytes are shorter than `minLength`.
        case bytesTooShort
        /// Bytes are longer than `maxLength`.
        case bytesTooLong
        /// An array has fewer than `minLength` elements.
        case arrayTooShort
        /// An array has more than `maxLength` elements.
        case arrayTooLong
        /// An object in a blob position is not a well-formed blob reference.
        case blobMalformed
        /// A blob's MIME type matches none of the `accept` patterns.
        case blobTypeNotAccepted
        /// A blob is larger than `maxSize`.
        case blobTooLarge
        /// The schema refers to a definition the catalog does not contain, so
        /// the value can not be checked.
        case unresolvedReference
        /// The schema refers to a definition that can not be used there (a
        /// `token`, or a non-object as a union variant).
        case invalidReferenceTarget
        /// The definition is a `token`, which has no data representation.
        case tokenIsNotData
        /// The definition is of a type that does not describe data (a query
        /// used as a field, an unsupported type…).
        case unsupportedSchemaType
        /// The record key does not satisfy the record's `key` type.
        case recordKeyMismatch
        /// A query parameter that is not an array was given more than once.
        case repeatedParameter
        /// The value nests deeper than the validator will follow.
        case depthLimitExceeded
    }

    /// JSON pointer to the offending value inside the validated value. `""`
    /// is the value itself; `/embed/images/0/alt` is a nested property.
    public let path: String
    /// The reason category.
    public let code: Code
    /// Human-readable detail.
    public let message: String

    /// Creates an issue.
    public init(path: String, code: Code, message: String) {
        self.path = path
        self.code = code
        self.message = message
    }

    /// A single-line, human-readable rendering.
    public var description: String {
        "\(code.rawValue) at \(path.isEmpty ? "/" : path): \(message)"
    }
}

/// Thrown when a value does not satisfy its Lexicon schema. Carries every
/// issue found (up to ``LexiconValidationOptions/maximumIssues``), in document
/// order.
public struct LexiconValidationError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The issues. Never empty.
    public let issues: [LexiconValidationIssue]

    /// Creates an error from the first issue and any that follow it.
    public init(_ first: LexiconValidationIssue, _ rest: [LexiconValidationIssue] = []) {
        issues = [first] + rest
    }

    /// Wraps collected issues, or returns `nil` when there are none.
    init?(issues: [LexiconValidationIssue]) {
        guard !issues.isEmpty else { return nil }
        self.issues = issues
    }

    /// The first issue.
    public var first: LexiconValidationIssue {
        issues[0]
    }

    /// Whether any issue has the given code.
    public func contains(_ code: LexiconValidationIssue.Code) -> Bool {
        issues.contains { $0.code == code }
    }

    /// Whether an issue with the given code was reported at exactly `path`.
    public func contains(_ code: LexiconValidationIssue.Code, at path: String) -> Bool {
        issues.contains { $0.code == code && $0.path == path }
    }

    /// A single-line, human-readable rendering.
    public var description: String {
        issues.map(\.description).joined(separator: "; ")
    }
}

/// Thrown when a validation entry point can not find, or can not use, the
/// definition it was asked to validate against. This is distinct from
/// ``LexiconValidationError`` so that a caller implementing "optimistic"
/// validation can tell "unknown Lexicon" from "invalid data".
public enum LexiconCatalogError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The reference string is not a valid `nsid` / `nsid#name`.
    case invalidReference(String)
    /// The catalog has no such definition.
    case definitionNotFound(String)
    /// The definition exists but is not of a type the entry point accepts.
    case definitionTypeMismatch(reference: String, expected: [String], actual: String)

    /// A single-line, human-readable rendering.
    public var description: String {
        switch self {
        case let .invalidReference(reference):
            return "\"\(reference)\" is not a valid Lexicon reference"
        case let .definitionNotFound(reference):
            return "Lexicon definition not found: \(reference)"
        case let .definitionTypeMismatch(reference, expected, actual):
            return "\(reference) is a \(actual) definition; expected \(expected.joined(separator: " or "))"
        }
    }
}

/// Knobs for data validation.
public struct LexiconValidationOptions: Sendable, Hashable {
    /// Accept the deprecated `{cid, mimeType}` blob form where the schema
    /// expects a blob. The data-model specification asks implementations not
    /// to fail on it, so the default is `true`.
    public var allowLegacyBlobs: Bool
    /// Require blob references to use the `raw` codec, as the blob
    /// specification says. Off by default because deployed records and the
    /// official `record-data-valid.json` vector carry `dag-cbor` references.
    public var requireRawBlobCIDs: Bool
    /// Stop collecting after this many issues.
    public var maximumIssues: Int
    /// Maximum nesting depth followed in the validated value.
    public var maximumDepth: Int

    /// Creates options.
    public init(
        allowLegacyBlobs: Bool = true,
        requireRawBlobCIDs: Bool = false,
        maximumIssues: Int = 64,
        maximumDepth: Int = 256
    ) {
        self.allowLegacyBlobs = allowLegacyBlobs
        self.requireRawBlobCIDs = requireRawBlobCIDs
        self.maximumIssues = max(1, maximumIssues)
        self.maximumDepth = maximumDepth
    }

    /// The default options.
    public static let standard = LexiconValidationOptions()
}

/// A constraint violation of a single scalar, before it is given a path.
struct LexConstraintViolation {
    let code: LexiconValidationIssue.Code
    let message: String
}

extension LexString {
    /// Every constraint of this definition that `value` breaks.
    /// `knownValues` is advisory and is never checked.
    func violations(of value: String) -> [LexConstraintViolation] {
        var found: [LexConstraintViolation] = []
        if let constValue, value != constValue {
            found.append(.init(code: .valueNotConst, message: "must be \"\(constValue)\""))
        }
        if let enumValues, !enumValues.contains(value) {
            found.append(.init(code: .valueNotInEnum, message: "must be one of (\(enumValues.joined(separator: "|")))"))
        }
        if minLength != nil || maxLength != nil {
            let length = value.utf8.count
            if let minLength, length < minLength {
                found.append(.init(code: .stringTooShort, message: "must not be shorter than \(minLength) UTF-8 bytes (is \(length))"))
            }
            if let maxLength, length > maxLength {
                found.append(.init(code: .stringTooLong, message: "must not be longer than \(maxLength) UTF-8 bytes (is \(length))"))
            }
        }
        if minGraphemes != nil || maxGraphemes != nil {
            // A Swift Character is an extended grapheme cluster (UAX #29),
            // which is the unit the specification counts.
            let graphemes = value.count
            if let minGraphemes, graphemes < minGraphemes {
                found.append(.init(code: .stringTooFewGraphemes, message: "must not be shorter than \(minGraphemes) graphemes (is \(graphemes))"))
            }
            if let maxGraphemes, graphemes > maxGraphemes {
                found.append(.init(code: .stringTooManyGraphemes, message: "must not be longer than \(maxGraphemes) graphemes (is \(graphemes))"))
            }
        }
        if let format, !format.isValid(value) {
            found.append(.init(code: .stringFormatMismatch, message: "must be a valid \(format.rawValue)"))
        }
        return found
    }
}

extension LexInteger {
    /// Every constraint of this definition that `value` breaks.
    func violations(of value: Int64) -> [LexConstraintViolation] {
        var found: [LexConstraintViolation] = []
        if let constValue, value != constValue {
            found.append(.init(code: .valueNotConst, message: "must be \(constValue)"))
        }
        if let enumValues, !enumValues.contains(value) {
            found.append(.init(code: .valueNotInEnum, message: "must be one of (\(enumValues.map(String.init).joined(separator: "|")))"))
        }
        if let minimum, value < minimum {
            found.append(.init(code: .integerTooSmall, message: "can not be less than \(minimum)"))
        }
        if let maximum, value > maximum {
            found.append(.init(code: .integerTooLarge, message: "can not be greater than \(maximum)"))
        }
        return found
    }
}
