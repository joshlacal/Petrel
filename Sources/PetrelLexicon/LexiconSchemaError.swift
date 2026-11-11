import Foundation

/// Why a Lexicon document is not a valid Lexicon version 1 schema.
public struct LexiconSchemaError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The reason category.
    public enum Code: String, Sendable, Hashable, CaseIterable {
        /// The input is not valid data-model JSON, or is not an object.
        case malformedDocument
        /// `lexicon` is missing or is not the integer `1`.
        case unsupportedLexiconVersion
        /// `id` is missing or is not a valid NSID.
        case invalidNSID
        /// `defs` is missing or empty.
        case noDefinitions
        /// A definition name is empty or contains characters that cannot
        /// appear in a `#fragment`.
        case invalidDefinitionName
        /// A required field is absent.
        case missingField
        /// A field has the wrong JSON type.
        case invalidFieldType
        /// `type` names a type that is not part of Lexicon version 1.
        case unknownType
        /// The type is valid but may not be used at this position (for
        /// example a named `ref`, a `token` as an object property, or a
        /// non-primitive query parameter).
        case typeNotAllowed
        /// A primary type (record, query, procedure, subscription,
        /// permission-set) is defined under a name other than `main`.
        case primaryNotMain
        /// `required` or `nullable` lists a property that is not defined.
        case undefinedProperty
        /// A `ref` / `refs` string is not a syntactically valid reference.
        case invalidReference
        /// A `#local` reference names a definition the document lacks.
        case unresolvedReference
        /// A reference points at a definition of a type that cannot be
        /// referenced there (a `token`, or a non-object in a `union`).
        case invalidReferenceTarget
        /// A union is closed and has no variants.
        case emptyClosedUnion
        /// A constraint is contradictory or malformed: a negative length, a
        /// minimum above its maximum, `const` together with `default`, a
        /// `default` or `const` that violates the definition's own limits.
        case invalidConstraint
        /// `format` is not one of the Lexicon version 1 string formats.
        case unknownStringFormat
        /// A blob `accept` entry is not `type/subtype`, `type/*` or `*/*`.
        case invalidMIMEPattern
        /// A record `key` is not `tid`, `nsid`, `any` or `literal:<value>`.
        case invalidRecordKeyType
        /// A `title:lang` / `detail:lang` key is not a language tag.
        case invalidLanguageTag
        /// Definitions are nested deeper than the reader will follow.
        case nestingTooDeep
        /// A lexicon with this NSID is already in the catalog.
        case duplicateLexicon
    }

    /// The NSID of the document, when it could be read.
    public let nsid: String?
    /// JSON pointer into the document, for example
    /// `/defs/main/record/properties/text`.
    public let path: String
    /// The reason category.
    public let code: Code
    /// Human-readable detail.
    public let message: String

    /// Creates an error.
    public init(_ code: Code, nsid: String? = nil, path: String, _ message: String) {
        self.code = code
        self.nsid = nsid
        self.path = path
        self.message = message
    }

    /// A single-line, human-readable rendering.
    public var description: String {
        let subject = nsid.map { "\($0) " } ?? ""
        return "\(subject)\(code.rawValue) at \(path.isEmpty ? "/" : path): \(message)"
    }

    func with(nsid: String?) -> LexiconSchemaError {
        LexiconSchemaError(code, nsid: self.nsid ?? nsid, path: path, message)
    }
}

/// How strictly a Lexicon document is checked.
public struct LexiconSchemaOptions: Sendable, Hashable {
    /// Accept string `format` names outside Lexicon version 1. Strings of such
    /// a format are then validated as unconstrained strings.
    public var allowUnknownStringFormats: Bool
    /// Accept definitions whose `type` is outside Lexicon version 1. They are
    /// kept as ``LexiconDef/unsupported(_:)``; any data validated against one
    /// fails with ``LexiconValidationIssue/Code/unsupportedSchemaType``.
    public var allowUnknownDefinitionTypes: Bool

    /// Creates options.
    public init(allowUnknownStringFormats: Bool = false, allowUnknownDefinitionTypes: Bool = false) {
        self.allowUnknownStringFormats = allowUnknownStringFormats
        self.allowUnknownDefinitionTypes = allowUnknownDefinitionTypes
    }

    /// Lexicon version 1 exactly. This is the default everywhere.
    public static let strict = LexiconSchemaOptions()

    /// Tolerates extensions: unknown string formats and unknown definition
    /// types load instead of failing. Use it for schemas that track a draft of
    /// the language.
    public static let lenient = LexiconSchemaOptions(allowUnknownStringFormats: true, allowUnknownDefinitionTypes: true)
}
