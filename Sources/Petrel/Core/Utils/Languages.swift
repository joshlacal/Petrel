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
        return lang.languageCode?.identifier ?? lang.minimalIdentifier
    }

    public var lang: Locale.Language

    // Standard initializer
    public init(lang: Locale.Language) {
        self.lang = lang
    }

    // Convenience initializer with String
    public init(languageCode: String) {
        lang = Locale.Language(bcp47LanguageTag: languageCode)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let languageTag = try container.decode(String.self)
        lang = Locale.Language(bcp47LanguageTag: languageTag)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(lang.languageCode?.identifier ?? lang.minimalIdentifier)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(lang)
    }
}
