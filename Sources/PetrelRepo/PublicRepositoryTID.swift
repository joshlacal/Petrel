import Foundation

/// A repository-v3 revision from the frozen sortable-base32 profile.
///
/// Allocation and monotonic recovery belong to the persistence transaction.
/// This value type validates and orders revisions only.
public struct PublicRepositoryTID: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) throws {
        let bytes = Array(value.utf8)
        let alphabet = Set("234567abcdefghijklmnopqrstuvwxyz".utf8)
        let leadingAlphabet = Set("234567abcdefghij".utf8)
        guard bytes.count == 13,
              let first = bytes.first,
              leadingAlphabet.contains(first),
              bytes.allSatisfy(alphabet.contains) else {
            throw PublicRepositoryDomainError.invalidRevision
        }
        self.value = value
    }

    public var description: String { value }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }
}
