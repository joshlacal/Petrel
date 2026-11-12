/// The named parameters of a scope string: an insertion-ordered multimap.
///
/// Order matters. Canonical serialisation writes parameters in the order the
/// resource's schema declares them, never alphabetically (`lib/parser.ts:54`
/// iterates the schema's keys and nothing sorts), so the storage is an array
/// rather than a dictionary.
///
/// A lookup of a single-valued parameter has three outcomes, not two. The
/// reference implementation distinguishes `undefined` (key absent) from `null`
/// (key present but repeated): `lib/syntax-string.ts:18-23` returns `null` for
/// more than one value, and `lib/parser.ts:121-122` rejects on `null` while
/// treating `undefined` as "fall back to the positional, then the default".
/// Folding both into an optional would turn `include:a.b.c?aud=x&aud=y` from a
/// rejection into "no audience".
public struct ScopeParameterBag: Sendable, Hashable {
    /// One `key=value` pair, after decoding.
    public struct Entry: Sendable, Hashable {
        /// The parameter name.
        public let key: String
        /// The parameter value.
        public let value: String
        /// Creates a pair.
        public init(key: String, value: String) { self.key = key; self.value = value }
    }

    /// The result of looking up a single-valued parameter, mirroring the
    /// reference implementation's `undefined | value | null`
    /// (`lib/syntax-string.ts:18-23`).
    public enum SingleLookup: Sendable, Hashable {
        /// The key does not appear.
        case absent
        /// The key appears exactly once.
        case present(String)
        /// The key appears more than once, which is malformed, never "absent".
        case repeated([String])
    }

    /// Every pair, in the order it was written.
    public private(set) var entries: [Entry]

    /// Creates a bag from pairs in order.
    public init(_ entries: [Entry] = []) { self.entries = entries }

    /// Whether there are no parameters.
    public var isEmpty: Bool { entries.isEmpty }

    /// Distinct keys in first-appearance order (`lib/syntax-string.ts:14-16`).
    public func orderedKeys() -> [String] {
        var seen = Set<ScopeBytes>()
        return entries.compactMap { seen.insert($0.key.scopeBytes).inserted ? $0.key : nil }
    }

    /// Every value given for `key`, in order.
    public func values(for key: String) -> [String] {
        entries.lazy.filter { $0.key.isByteEqual(to: key) }.map(\.value)
    }

    /// Looks up `key` as a single-valued parameter.
    public func single(_ key: String) -> SingleLookup {
        let found = values(for: key)
        switch found.count {
        case 0: return .absent
        case 1: return .present(found[0])
        default: return .repeated(found)
        }
    }

    /// Looks up `key` as a multi-valued parameter; `nil` when it is absent.
    public func multiple(_ key: String) -> [String]? {
        let found = values(for: key)
        return found.isEmpty ? nil : found
    }

    /// Appends a pair, keeping any existing pairs for the same key.
    public mutating func append(key: String, value: String) {
        entries.append(Entry(key: key, value: value))
    }

    /// Replaces every pair for `key` with a single one.
    public mutating func set(key: String, value: String) {
        entries.removeAll { $0.key == key }
        entries.append(Entry(key: key, value: value))
    }
}
