import Foundation
import Petrel

public extension LexiconCatalog {
    /// A catalog of every Lexicon that Petrel generates Swift types for: `com.atproto`,
    /// `app.bsky`, `chat.bsky` and the other namespaces of the core `Petrel` product.
    ///
    /// The documents are compiled into this module (they are the exact files the code
    /// generator read), so no file or network access is involved. Use it to hold data to
    /// the constraints the generated types do not carry — lengths, grapheme counts, integer
    /// ranges, enums, blob size and MIME type:
    ///
    /// ```swift
    /// let catalog = try LexiconCatalog.bundled()
    /// try catalog.validateRecord(post)          // an AppBskyFeedPost about to be written
    /// ```
    ///
    /// The catalog is built once and reused. It is loaded with
    /// ``LexiconSchemaOptions/lenient``, because the corpus contains the permissioned-spaces
    /// draft, which uses a definition type and a string format outside Lexicon version 1.
    ///
    /// - Throws: ``LexiconSchemaError`` if a bundled document is not a valid Lexicon, which
    ///   would be a defect in the build that produced this module.
    static func bundled() throws -> LexiconCatalog {
        try bundledCatalog.get()
    }

    private static let bundledCatalog: Result<LexiconCatalog, any Error> = Result {
        var catalog = LexiconCatalog()
        for document in BundledLexiconDocuments.all {
            try catalog.add(json: Data(document.utf8), options: .lenient)
        }
        return catalog
    }

    /// Validates a generated record value against the Lexicon of its type.
    ///
    /// The collection is the type's `typeIdentifier`; the value is encoded exactly as it
    /// would be written and then checked like wire data.
    ///
    /// - Parameters:
    ///   - record: A generated record, for example an `AppBskyFeedPost`.
    ///   - recordKey: When given, also checked against the record's key type.
    ///   - options: Validation options.
    /// - Throws: ``LexiconValidationError``, ``LexiconCatalogError`` if the catalog does
    ///   not hold the record's Lexicon, or ``LexValueError`` if the value does not encode
    ///   to valid atproto data.
    func validateRecord(
        _ record: some ATProtocolValue,
        recordKey: String? = nil,
        options: LexiconValidationOptions = .standard
    ) throws {
        try validateRecord(
            LexValue(encoding: record),
            collection: type(of: record).typeIdentifier,
            recordKey: recordKey,
            options: options
        )
    }

    /// Validates a generated object value against the Lexicon definition of its type
    /// (`typeIdentifier`, such as `app.bsky.richtext.facet` or `app.bsky.feed.defs#postView`).
    ///
    /// - Throws: ``LexiconValidationError``, ``LexiconCatalogError`` or ``LexValueError``.
    func validate(
        _ value: some ATProtocolValue,
        options: LexiconValidationOptions = .standard
    ) throws {
        try validate(LexValue(encoding: value), againstDef: type(of: value).typeIdentifier, options: options)
    }
}
