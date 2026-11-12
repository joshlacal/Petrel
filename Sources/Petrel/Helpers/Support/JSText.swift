import Foundation

/// JavaScript string semantics the Bluesky helpers have to reproduce exactly.
///
/// The reference client (`@atproto/api`) defines rich text detection, muted
/// words and preference sanitizing in terms of JavaScript regular expressions.
/// Foundation's and ICU's notions of whitespace differ from ECMAScript's, so
/// the ECMAScript set is spelled out here once.
enum JSText {
    /// The members of ECMAScript `\s` (WhiteSpace plus LineTerminator), written
    /// for use inside an ICU regular expression bracket expression.
    static let whitespaceClass = #"\t\n\u000B\f\r    -     　﻿"#

    /// Whether `scalar` is matched by ECMAScript `\s`.
    static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        case 0x2000 ... 0x200A:
            return true
        default:
            return false
        }
    }

    /// Whether the string is empty after `String.prototype.trim()`.
    static func isBlank(_ string: String) -> Bool {
        string.unicodeScalars.allSatisfy(isWhitespace)
    }
}
