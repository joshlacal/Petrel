// Authorization compares bytes, not text.
//
// Swift's `String ==`, `hasPrefix` and string hashing work on Unicode
// canonical equivalence: U+212A KELVIN SIGN equals "K", and "e" followed by
// U+0301 equals "é". The reference implementation compares UTF-16 code units,
// which for these purposes is the same as comparing UTF-8 bytes. Everything in
// this module that decides whether a request is allowed, or whether two
// scopes are the same grant, goes through the helpers below.

extension String {
    /// Whether `self` and `other` are the same sequence of bytes.
    func isByteEqual(to other: String) -> Bool {
        utf8.elementsEqual(other.utf8)
    }

    /// Whether the bytes of `self` begin with the bytes of `prefix`.
    func hasBytePrefix(_ prefix: String) -> Bool {
        utf8.starts(with: prefix.utf8)
    }

    /// `self` with the ASCII letters `A`–`Z` lower-cased and every other byte
    /// left alone. Unicode case mapping must not be used where the result is
    /// compared for authorization: it maps U+212A KELVIN SIGN to `k`.
    var asciiLowercased: String {
        guard utf8.contains(where: { $0 >= 0x41 && $0 <= 0x5A }) else { return self }
        return String(decoding: utf8.map { $0 >= 0x41 && $0 <= 0x5A ? $0 | 0x20 : $0 }, as: UTF8.self)
    }
}

extension String {
    /// The tokens of an OAuth `scope` value: the runs of bytes between SPACE
    /// (0x20) bytes.
    ///
    /// Split on the byte, not on the `Character` `" "`: a space followed by a
    /// combining mark is one `Character` that is not a space, and splitting
    /// on characters would glue the tokens either side of it together.
    var scopeTokens: [String] {
        // 0x20 is never part of a multi-byte sequence, so every piece is
        // itself valid UTF-8 and decodes without loss.
        utf8.split(separator: 0x20).map { String(decoding: $0, as: UTF8.self) }
    }
}

extension Set where Element == String {
    /// The distinct tokens of `tokens`, chosen deterministically.
    ///
    /// A `Set<String>` cannot hold two strings that are canonically
    /// equivalent, so where two tokens differ in bytes and are equal as
    /// `String`s only one can be kept. The one kept is the first in byte
    /// order, whatever order they arrived in. That is the all-ASCII one when
    /// there is one — the only one of the two that can be a scope — because
    /// a string equivalent to an ASCII string first differs from it at a
    /// non-ASCII byte.
    init(scopeTokens tokens: [String]) {
        self.init()
        for token in tokens.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            insert(token) // keeps the member already present
        }
    }
}

extension Sequence where Element == String {
    /// Whether the sequence contains `value`, compared byte-wise.
    func containsBytes(of value: String) -> Bool {
        contains { $0.isByteEqual(to: value) }
    }

    /// The distinct values, de-duplicated on their bytes and sorted in byte
    /// order. `Array(Set(values)).sorted()` would merge canonically
    /// equivalent values that are different bytes, and order by Unicode
    /// collation rather than by bytes. For ASCII values the two agree.
    func byteDistinctSorted() -> [String] {
        var seen = Set<ScopeBytes>()
        return filter { seen.insert($0.scopeBytes).inserted }
            .sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
    }

    /// Whether the two sequences hold the same values, ignoring order and
    /// duplicates, compared byte-wise.
    func hasSameBytesSet(as other: some Sequence<String>) -> Bool {
        Set(map(\.scopeBytes)) == Set(other.map(\.scopeBytes))
    }
}

extension StringProtocol {
    /// Whether the bytes of `needle` occur anywhere in the bytes of `self`.
    /// `String.contains(_:)` searches by `Character`, so a combining mark
    /// after the match would hide it.
    func containsByteSequence(_ needle: String) -> Bool {
        let haystack = Array(utf8), pattern = Array(needle.utf8)
        guard !pattern.isEmpty else { return true }
        guard haystack.count >= pattern.count else { return false }
        return (0 ... haystack.count - pattern.count).contains { start in
            haystack[start ..< start + pattern.count].elementsEqual(pattern)
        }
    }
}

extension CaseIterable where Self: RawRepresentable, RawValue == String {
    /// The case whose raw value is byte-for-byte `raw`.
    init?(bytewise raw: String) {
        guard let match = Self.allCases.first(where: { $0.rawValue.isByteEqual(to: raw) }) else { return nil }
        self = match
    }
}

/// A string as its bytes, for use as a set element or dictionary key where
/// `String`'s own equality would merge canonically equivalent strings.
typealias ScopeBytes = [UInt8]

extension String {
    /// The UTF-8 bytes of `self`.
    var scopeBytes: ScopeBytes { Array(utf8) }
}
