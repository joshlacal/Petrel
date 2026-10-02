//
//  JSONTopLevelArraySplitter.swift
//  Petrel
//
//  Structural pre-pass for parallel XRPC output decoding.
//

import Foundation

/// Locates the element byte ranges of ONE array-valued member of a top-level JSON object,
/// for example the `feed` array of an `app.bsky.feed.getTimeline` response.
///
/// This is a structural scan only. It does not validate JSON. The parallel decoder always runs
/// Foundation's parser over the whole document as well (the whole-document scan), so the set of
/// accepted documents is exactly the set `JSONDecoder` accepts. Whenever the input is anything
/// other than the plain, unambiguous shape, the splitter returns `nil` and the caller uses the
/// ordinary sequential decode.
///
/// Conservative bail-outs (return `nil`):
/// - the first non-whitespace byte is not `{` (UTF-8 BOM, UTF-16/32 input, top-level arrays, fragments)
/// - any top-level object key contains a backslash escape or a non-ASCII byte. Either could make a
///   key that is byte-different from the target compare equal to it after Foundation decodes the key
///   (escapes such as `"feed"`, or canonically equivalent Unicode such as U+212A KELVIN SIGN).
///   ASCII-only, escape-free keys compare equal in Swift exactly when their bytes are equal.
/// - the target key is missing or duplicated, or its value is not an array
/// - any structural surprise (unterminated string, unbalanced containers, trailing bytes)
/// - an element nested deep enough to approach Foundation's nesting limit
enum JSONTopLevelArraySplitter {
    struct Layout: Sendable, Equatable {
        /// The whole array value, from its `[` through its `]`, relative to `data.startIndex`.
        var array: Range<Int>
        /// Element byte ranges, as offsets relative to `data.startIndex`.
        var elements: [Range<Int>]
        /// Maximum container depth inside any element (an element that is an object has depth 1).
        var maxElementDepth: Int
    }

    /// Foundation's JSON parser rejects documents nested deeper than 512 levels. An element sits two
    /// levels below the root (object -> array -> element). The whole-document scan already
    /// reproduces the serial outcome for such documents; bailing early just avoids wasted work.
    static let maximumSafeElementDepth = 480

    /// Returns the layout of the array stored under `arrayKey` in the top-level object, or `nil`
    /// when the document is not in the plain shape described above.
    static func split(_ data: Data, arrayKey: String) -> Layout? {
        #if compiler(>=6.2)
            let key = Array(arrayKey.utf8)
            let span = data.span
            return split(span, key: key)
        #else
            // `Data.span` needs a Swift 6.2 compiler. Older toolchains always use the serial decode.
            return nil
        #endif
    }

    #if compiler(>=6.2)
        private static func split(_ s: borrowing Span<UInt8>, key: [UInt8]) -> Layout? {
            var i = 0
            skipWhitespace(s, &i)
            guard i < s.count, s[i] == UInt8(ascii: "{") else { return nil }
            i += 1
            skipWhitespace(s, &i)
            guard i < s.count, s[i] != UInt8(ascii: "}") else { return nil }

            var found: [Range<Int>]?
            var arrayRange = 0 ..< 0
            var maxDepth = 0
            while true {
                skipWhitespace(s, &i)
                guard i < s.count, s[i] == UInt8(ascii: "\"") else { return nil }
                let keyStart = i + 1
                var keyIsPlainASCII = true
                guard skipString(s, &i, plainASCII: &keyIsPlainASCII), keyIsPlainASCII else { return nil }
                let keyEnd = i - 1
                var isTarget = keyEnd - keyStart == key.count
                if isTarget {
                    for k in 0 ..< key.count where s[keyStart + k] != key[k] {
                        isTarget = false
                        break
                    }
                }
                skipWhitespace(s, &i)
                guard i < s.count, s[i] == UInt8(ascii: ":") else { return nil }
                i += 1
                skipWhitespace(s, &i)

                if isTarget {
                    guard found == nil else { return nil }
                    guard i < s.count, s[i] == UInt8(ascii: "[") else { return nil }
                    let arrayStart = i
                    i += 1
                    var elements: [Range<Int>] = []
                    skipWhitespace(s, &i)
                    guard i < s.count else { return nil }
                    if s[i] == UInt8(ascii: "]") {
                        i += 1
                    } else {
                        while true {
                            skipWhitespace(s, &i)
                            let start = i
                            var depth = 0
                            guard skipValue(s, &i, maxDepth: &depth) else { return nil }
                            if depth > maxDepth { maxDepth = depth }
                            guard maxDepth < maximumSafeElementDepth else { return nil }
                            elements.append(start ..< i)
                            skipWhitespace(s, &i)
                            guard i < s.count else { return nil }
                            if s[i] == UInt8(ascii: ",") { i += 1; continue }
                            if s[i] == UInt8(ascii: "]") { i += 1; break }
                            return nil
                        }
                    }
                    found = elements
                    arrayRange = arrayStart ..< i
                } else {
                    var ignored = 0
                    guard skipValue(s, &i, maxDepth: &ignored) else { return nil }
                }

                skipWhitespace(s, &i)
                guard i < s.count else { return nil }
                if s[i] == UInt8(ascii: ",") { i += 1; continue }
                if s[i] == UInt8(ascii: "}") { i += 1; break }
                return nil
            }
            skipWhitespace(s, &i)
            guard i == s.count, let found else { return nil }
            return Layout(array: arrayRange, elements: found, maxElementDepth: maxDepth)
        }

        @inline(__always)
        private static func isWhitespace(_ b: UInt8) -> Bool {
            b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09
        }

        @inline(__always)
        private static func skipWhitespace(_ s: borrowing Span<UInt8>, _ i: inout Int) {
            while i < s.count, isWhitespace(s[i]) {
                i += 1
            }
        }

        /// `s[i]` must be the opening quote. On success `i` is one past the closing quote.
        /// `plainASCII` is cleared when the string contains an escape or any byte >= 0x80.
        @inline(__always)
        private static func skipString(_ s: borrowing Span<UInt8>, _ i: inout Int, plainASCII: inout Bool) -> Bool {
            i += 1
            while i < s.count {
                let b = s[i]
                if b == UInt8(ascii: "\"") {
                    i += 1
                    return true
                }
                if b == UInt8(ascii: "\\") {
                    plainASCII = false
                    i += 2
                    continue
                }
                if b >= 0x80 { plainASCII = false }
                i += 1
            }
            return false
        }

        /// Skips one JSON value of any kind. Containers are skipped with a string-aware depth
        /// counter; bracket kinds are not matched (the whole-document scan rejects such input).
        private static func skipValue(_ s: borrowing Span<UInt8>, _ i: inout Int, maxDepth: inout Int) -> Bool {
            guard i < s.count else { return false }
            let first = s[i]
            if first == UInt8(ascii: "\"") {
                var ignored = true
                return skipString(s, &i, plainASCII: &ignored)
            }
            if first == UInt8(ascii: "{") || first == UInt8(ascii: "[") {
                var depth = 0
                while i < s.count {
                    switch s[i] {
                    case UInt8(ascii: "\""):
                        var ignored = true
                        guard skipString(s, &i, plainASCII: &ignored) else { return false }
                    case UInt8(ascii: "{"), UInt8(ascii: "["):
                        depth += 1
                        if depth > maxDepth { maxDepth = depth }
                        i += 1
                    case UInt8(ascii: "}"), UInt8(ascii: "]"):
                        depth -= 1
                        i += 1
                        if depth == 0 { return true }
                        if depth < 0 { return false }
                    default:
                        i += 1
                    }
                }
                return false
            }
            let start = i
            while i < s.count {
                let c = s[i]
                if c == UInt8(ascii: ",") || c == UInt8(ascii: "}") || c == UInt8(ascii: "]") || isWhitespace(c) { break }
                i += 1
            }
            return i > start
        }
    #endif
}
