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

public struct LanguageCodeContainer: Codable, ATProtocolCodable, Hashable, Sendable, CustomReflectable {
    public func toCBORValue() throws -> Any {
        return languageTag
    }

    /// The parsed language. Built on access from the wire tag when this container
    /// came from a string, so decoding never constructs a `Locale.Language` (an ICU
    /// round trip per `langs` element that decoding, re-encoding, `==` and hashing
    /// never read). `Locale.Language(identifier:)` is a pure function of the tag, so
    /// the derived value equals the one the initializer used to store eagerly.
    /// Setting it behaves as before: the explicit value is stored and the wire tag
    /// is cleared.
    public var lang: Locale.Language {
        get {
            if let explicitLanguage {
                return explicitLanguage.lang
            }
            return Locale.Language(bcp47LanguageTag: wireTag ?? "")
        }
        set {
            explicitLanguage = LanguageBox(newValue)
            wireTag = nil
        }
    }

    /// A `Locale.Language` given explicitly (`init(lang:)` or the `lang` setter).
    /// Boxed so the container stays small (`Locale.Language` is 96 bytes inline).
    /// Exactly one of `explicitLanguage` and `wireTag` is non-nil.
    private var explicitLanguage: LanguageBox?

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

    /// Preserve the original stored-property view even though language parsing
    /// is now deferred until it is requested.
    public var customMirror: Mirror {
        Mirror(self, children: ["lang": lang, "wireTag": wireTag as Any], displayStyle: .struct)
    }

    /// The BCP-47 tag for this language, preserving region/script subtags when known.
    public var languageTag: String {
        if let wireTag {
            return wireTag
        }
        let language = self.lang
        return language.languageCode?.identifier ?? language.minimalIdentifier
    }

    /// Standard initializer
    public init(lang: Locale.Language) {
        explicitLanguage = LanguageBox(lang)
        wireTag = nil
    }

    /// Convenience initializer with String
    public init(languageCode: String) {
        explicitLanguage = nil
        wireTag = languageCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let languageTag = try container.decode(String.self)
        explicitLanguage = nil
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

/// Immutable box for an explicitly supplied `Locale.Language`.
private final class LanguageBox: Sendable {
    let lang: Locale.Language

    init(_ lang: Locale.Language) {
        self.lang = lang
    }
}

extension LanguageCodeContainer: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        URLQueryItem(name: name, value: languageTag)
    }
}
