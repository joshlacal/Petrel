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

public struct LanguageCodeContainer: Codable, ATProtocolCodable, Hashable, Sendable {
    public func toCBORValue() throws -> Any {
        return languageTag
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

    /// Standard initializer
    public init(lang: Locale.Language) {
        self.lang = lang
        wireTag = nil
    }

    /// Convenience initializer with String
    public init(languageCode: String) {
        lang = Locale.Language(bcp47LanguageTag: languageCode)
        wireTag = languageCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let languageTag = try container.decode(String.self)
        lang = Locale.Language(bcp47LanguageTag: languageTag)
        wireTag = languageTag
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(languageTag)
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
