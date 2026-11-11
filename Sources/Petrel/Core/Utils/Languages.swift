//
//  Languages.swift
//
//
//  Created by Josh LaCalamito on 11/29/23.
//

import Foundation

public extension Locale.Language {
    init(bcp47LanguageTag: String) {
        self.init(identifier: bcp47LanguageTag)
    }
}

// MARK: - BCP 47 language tag

/// A parsed IETF BCP 47 language tag (RFC 5646), the Lexicon `language` string format.
///
/// Two levels of checking are offered, matching the two the specification and the
/// reference implementation distinguish:
///
/// - ``isWellFormed(_:)`` checks the RFC 5646 §2.1 grammar only. This is what the
///   Lexicon specification requires of a `language` string, and what record
///   decoding enforces.
/// - ``init(_:)`` / ``isValid(_:)`` additionally require a lowercase two- or
///   three-letter primary language subtag and reject repeated variant or
///   extension-singleton subtags (RFC 5646 §4.1). This is the level the official
///   `language_syntax_*` and `language_parse_invalid` interop vectors test.
///
/// ```swift
/// let tag = try LanguageTag("hy-Latn-IT-arevela")
/// tag.language  // "hy"
/// tag.script    // "Latn"
/// tag.region    // "IT"
/// tag.variants  // ["arevela"]
/// ```
public struct LanguageTag: Hashable, Sendable, CustomStringConvertible {
    /// The tag exactly as it was written.
    public let rawValue: String

    /// The primary language subtag (`ja`, `ban`). `nil` for an irregular
    /// grandfathered tag and for a tag made only of private-use subtags.
    public let language: String?

    /// Extended language subtags, at most three (`zh-cmn-Hans` → `["cmn"]`).
    public let extendedLanguages: [String]

    /// The four-letter script subtag (`Latn`), if present.
    public let script: String?

    /// The two-letter or three-digit region subtag (`BR`, `419`), if present.
    public let region: String?

    /// Variant subtags in order (`["rozaj", "biske"]`).
    public let variants: [String]

    /// Extension sequences, each beginning with its singleton (`["u-co-phonebk"]`).
    public let extensions: [String]

    /// The private-use sequence including its `x` prefix (`"x-private"`), if present.
    public let privateUse: String?

    /// Whether the whole tag is one of the grandfathered registrations
    /// (`i-default`, `zh-hakka`, `sgn-BE-NL`, …).
    public let isGrandfathered: Bool

    /// Parses `string`, throwing ``ATProtocolError/invalidLanguage(_:)`` unless it
    /// is a well-formed tag with a lowercase 2–3 letter primary subtag and no
    /// repeated variant or extension singleton.
    public init(_ string: String) throws {
        switch LanguageTag.parse(string) {
        case let .success(parsed):
            if let reason = parsed.strictFailure {
                throw ATProtocolError.invalidLanguage(
                    "Invalid language tag \(syntaxExcerpt(string)): \(reason)"
                )
            }
            self = parsed.tag
        case let .failure(failure):
            throw ATProtocolError.invalidLanguage(
                "Invalid language tag \(syntaxExcerpt(string)): \(failure.reason)"
            )
        }
    }

    /// Whether `string` matches the RFC 5646 §2.1 grammar ("well-formed").
    /// Case is not significant, and repeated subtags are not checked.
    public static func isWellFormed(_ string: String) -> Bool {
        if case .success = parse(string) { return true }
        return false
    }

    /// Whether `string` parses with ``init(_:)``: well-formed, lowercase 2–3
    /// letter primary subtag, no repeated variant or extension singleton.
    public static func isValid(_ string: String) -> Bool {
        if case let .success(parsed) = parse(string) { return parsed.strictFailure == nil }
        return false
    }

    public var description: String {
        rawValue
    }

    // MARK: Parsing

    private init(
        rawValue: String,
        language: String? = nil,
        extendedLanguages: [String] = [],
        script: String? = nil,
        region: String? = nil,
        variants: [String] = [],
        extensions: [String] = [],
        privateUse: String? = nil,
        isGrandfathered: Bool = false
    ) {
        self.rawValue = rawValue
        self.language = language
        self.extendedLanguages = extendedLanguages
        self.script = script
        self.region = region
        self.variants = variants
        self.extensions = extensions
        self.privateUse = privateUse
        self.isGrandfathered = isGrandfathered
    }

    private struct Parsed {
        let tag: LanguageTag
        /// Why a well-formed tag is still rejected by the strict level, if it is.
        let strictFailure: String?
    }

    /// RFC 5646 §2.1 `grandfathered` (irregular and regular), lowercased.
    private static let grandfathered: Set<String> = [
        "en-gb-oed", "i-ami", "i-bnn", "i-default", "i-enochian", "i-hak", "i-klingon", "i-lux",
        "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay", "i-tsu", "sgn-be-fr", "sgn-be-nl",
        "sgn-ch-de", "art-lojban", "cel-gaulish", "no-bok", "no-nyn", "zh-guoyu", "zh-hakka",
        "zh-min", "zh-min-nan", "zh-xiang",
    ]

    private enum SubtagKind {
        case alpha, digit, mixed
    }

    /// Classifies one subtag, or returns `nil` when it is empty, longer than eight
    /// characters, or contains anything other than ASCII letters and digits.
    private static func kind(of subtag: Substring) -> SubtagKind? {
        let bytes = subtag.utf8
        guard (1 ... 8).contains(bytes.count) else { return nil }
        var sawAlpha = false
        var sawDigit = false
        for byte in bytes {
            if SyntaxByte.isAlpha(byte) {
                sawAlpha = true
            } else if SyntaxByte.isDigit(byte) {
                sawDigit = true
            } else {
                return nil
            }
        }
        if sawAlpha, sawDigit { return .mixed }
        return sawAlpha ? .alpha : .digit
    }

    private static func parse(_ string: String) -> Result<Parsed, SyntaxFailure> {
        // Every subtag is ASCII, so anything else (including a trailing line
        // terminator) fails here before the grammar is consulted.
        guard !string.isEmpty, string.utf8.allSatisfy({ SyntaxByte.isAlphanumeric($0) || $0 == SyntaxByte.hyphen })
        else {
            return .failure("must contain only ASCII letters, digits and hyphens")
        }

        let subtags = string.split(separator: "-", omittingEmptySubsequences: false)
        var kinds: [SubtagKind] = []
        kinds.reserveCapacity(subtags.count)
        for subtag in subtags {
            guard let kind = kind(of: subtag) else {
                return .failure("every subtag must be 1 to 8 letters or digits")
            }
            kinds.append(kind)
        }

        if grandfathered.contains(string.lowercased()) {
            return .success(Parsed(tag: LanguageTag(rawValue: string, isGrandfathered: true), strictFailure: nil))
        }

        func isSingletonX(_ index: Int) -> Bool {
            subtags[index] == "x" || subtags[index] == "X"
        }

        func privateUseSequence(from index: Int) -> Result<String, SyntaxFailure> {
            guard index + 1 < subtags.count else {
                return .failure("private-use prefix \"x\" must be followed by a subtag")
            }
            return .success(subtags[index...].joined(separator: "-"))
        }

        // privateuse = "x" 1*("-" (1*8alphanum))
        if isSingletonX(0) {
            switch privateUseSequence(from: 0) {
            case let .success(sequence):
                return .success(Parsed(tag: LanguageTag(rawValue: string, privateUse: sequence), strictFailure: nil))
            case let .failure(failure):
                return .failure(failure)
            }
        }

        // langtag = language ["-" script] ["-" region] *("-" variant) *("-" extension) ["-" privateuse]
        let primary = subtags[0]
        let primaryLength = primary.utf8.count
        guard kinds[0] == .alpha, primaryLength >= 2 else {
            return .failure("primary language subtag must be 2 to 8 letters")
        }

        var index = 1
        var extendedLanguages: [String] = []
        if primaryLength <= 3 {
            while extendedLanguages.count < 3, index < subtags.count,
                  kinds[index] == .alpha, subtags[index].utf8.count == 3
            {
                extendedLanguages.append(String(subtags[index]))
                index += 1
            }
        }

        var script: String?
        if index < subtags.count, kinds[index] == .alpha, subtags[index].utf8.count == 4 {
            script = String(subtags[index])
            index += 1
        }

        var region: String?
        if index < subtags.count,
           (kinds[index] == .alpha && subtags[index].utf8.count == 2)
           || (kinds[index] == .digit && subtags[index].utf8.count == 3)
        {
            region = String(subtags[index])
            index += 1
        }

        var variants: [String] = []
        while index < subtags.count {
            let length = subtags[index].utf8.count
            let startsWithDigit = subtags[index].utf8.first.map(SyntaxByte.isDigit) ?? false
            guard (5 ... 8).contains(length) || (length == 4 && startsWithDigit) else { break }
            variants.append(String(subtags[index]))
            index += 1
        }

        var extensions: [String] = []
        var singletons: [String] = []
        while index < subtags.count, subtags[index].utf8.count == 1, !isSingletonX(index) {
            let singleton = subtags[index]
            var end = index + 1
            while end < subtags.count, subtags[end].utf8.count >= 2 {
                end += 1
            }
            guard end > index + 1 else {
                return .failure("extension singleton \"\(singleton)\" must be followed by a subtag of 2 to 8 characters")
            }
            extensions.append(subtags[index ..< end].joined(separator: "-"))
            singletons.append(singleton.lowercased())
            index = end
        }

        var privateUse: String?
        if index < subtags.count, isSingletonX(index) {
            switch privateUseSequence(from: index) {
            case let .success(sequence):
                privateUse = sequence
                index = subtags.count
            case let .failure(failure):
                return .failure(failure)
            }
        }

        guard index == subtags.count else {
            return .failure("subtag \"\(subtags[index])\" is not valid at this position")
        }

        var strictFailure: String?
        if !(2 ... 3).contains(primaryLength) || !primary.utf8.allSatisfy(SyntaxByte.isLower) {
            strictFailure = "primary language subtag must be two or three lowercase letters"
        } else if Set(variants.map { $0.lowercased() }).count != variants.count {
            strictFailure = "a variant subtag is repeated"
        } else if Set(singletons).count != singletons.count {
            strictFailure = "an extension singleton is repeated"
        }

        let tag = LanguageTag(
            rawValue: string,
            language: String(primary),
            extendedLanguages: extendedLanguages,
            script: script,
            region: region,
            variants: variants,
            extensions: extensions,
            privateUse: privateUse
        )
        return .success(Parsed(tag: tag, strictFailure: strictFailure))
    }
}

// MARK: - Lexicon `language` value

/// The Lexicon `language` string format: a BCP 47 language tag that keeps the
/// exact string it was created from.
///
/// Decoding requires a well-formed tag (``LanguageTag/isWellFormed(_:)``) and
/// throws otherwise, as the Lexicon specification requires. A tag that is
/// well-formed but not valid — for example one that repeats a variant — still
/// decodes, because the specification tells clients to ignore such tags rather
/// than reject the record that carries them; ``tag`` is `nil` for those.
///
/// ```swift
/// let language = try LanguageCodeContainer(validating: "pt-BR")
/// language.languageTag   // "pt-BR"
/// language.tag?.region   // "BR"
/// ```
public struct LanguageCodeContainer: Codable, ATProtocolCodable, Hashable, Sendable {
    public func toCBORValue() throws -> Any {
        try checkedLanguageTag()
    }

    public var lang: Locale.Language {
        didSet { wireTag = nil }
    }

    /// The BCP-47 tag exactly as it was written, when this container came from a
    /// string (wire record or caller-supplied code).
    ///
    /// `Locale.Language` normalizes region and script subtags away as soon as you
    /// ask it for `languageCode` (`en-US` → `en`, `pt-BR` → `pt`, `zh-Hans` → `zh`),
    /// so re-deriving the tag from `lang` is lossy. Records are immutable bytes in
    /// atproto — mutating `langs` on re-encode breaks CID fidelity and trips
    /// `ATProtocolValueContainer`'s lossless-decode guard, which then demotes the
    /// whole record to `.unknownType` and makes renderers tombstone it.
    private var wireTag: String?

    /// The BCP-47 tag for this language, preserving region/script subtags when known.
    public var languageTag: String {
        wireTag ?? lang.languageCode?.identifier ?? lang.minimalIdentifier
    }

    /// The parsed tag, or `nil` when ``languageTag`` is not a valid BCP 47 tag
    /// (see ``LanguageTag/init(_:)`` for what "valid" requires).
    public var tag: LanguageTag? {
        try? LanguageTag(languageTag)
    }

    /// Whether ``languageTag`` is a well-formed BCP 47 tag. Always `true` for a
    /// decoded value; can be `false` for one built with ``init(languageCode:)``
    /// or ``init(lang:)``, in which case encoding it throws.
    public var isWellFormed: Bool {
        LanguageTag.isWellFormed(languageTag)
    }

    /// Whether `string` is a valid BCP 47 language tag; shorthand for
    /// ``LanguageTag/isValid(_:)``.
    public static func isValidLanguageTag(_ string: String) -> Bool {
        LanguageTag.isValid(string)
    }

    /// Standard initializer
    public init(lang: Locale.Language) {
        self.lang = lang
        wireTag = nil
    }

    /// Wraps `languageCode` without checking it. A value that is not a
    /// well-formed BCP 47 tag is kept as written and fails when it is encoded;
    /// use ``init(validating:)`` to find out at the point of construction.
    public init(languageCode: String) {
        lang = Locale.Language(bcp47LanguageTag: languageCode)
        wireTag = languageCode
    }

    /// Wraps `languageTag` after checking it with ``LanguageTag/init(_:)``,
    /// throwing ``ATProtocolError/invalidLanguage(_:)`` if it is not a valid tag.
    public init(validating languageTag: String) throws {
        _ = try LanguageTag(languageTag)
        self.init(languageCode: languageTag)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let languageTag = try container.decode(String.self)
        guard LanguageTag.isWellFormed(languageTag) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Not a well-formed BCP 47 language tag: \(syntaxExcerpt(languageTag))",
                    underlyingError: ATProtocolError.invalidLanguage(
                        "Not a well-formed BCP 47 language tag: \(syntaxExcerpt(languageTag))"
                    )
                )
            )
        }
        lang = Locale.Language(bcp47LanguageTag: languageTag)
        wireTag = languageTag
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(checkedLanguageTag())
    }

    /// The tag to write, refusing to emit a string that is not a language tag.
    private func checkedLanguageTag() throws -> String {
        let tag = languageTag
        guard LanguageTag.isWellFormed(tag) else {
            throw ATProtocolError.invalidLanguage(
                "Refusing to encode a value that is not a well-formed BCP 47 language tag: \(syntaxExcerpt(tag))"
            )
        }
        return tag
    }

    public static func == (lhs: LanguageCodeContainer, rhs: LanguageCodeContainer) -> Bool {
        lhs.languageTag == rhs.languageTag
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(languageTag)
    }
}

extension LanguageCodeContainer: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        URLQueryItem(name: name, value: languageTag)
    }
}
