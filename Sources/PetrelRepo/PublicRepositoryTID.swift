import Foundation

/// A repository revision (`rev`): a TID, 13 characters of sortable base32.
///
/// A TID packs a 53-bit microsecond timestamp and a 10-bit clock identifier
/// into 64 bits, so string order is time order. ``next(after:now:clockID:)``
/// allocates revisions that never repeat or go backwards.
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

public extension PublicRepositoryTID {
    private static let alphabet = Array("234567abcdefghijklmnopqrstuvwxyz".utf8)

    /// Builds a TID from its two fields.
    ///
    /// - Parameters:
    ///   - microsecondsSinceEpoch: The timestamp; must fit in 53 bits.
    ///   - clockID: The clock identifier; must fit in 10 bits.
    /// - Throws: ``PublicRepositoryDomainError/invalidRevision`` if either
    ///   field is out of range.
    init(microsecondsSinceEpoch: UInt64, clockID: UInt16) throws {
        guard microsecondsSinceEpoch < (1 << 53), clockID < (1 << 10) else {
            throw PublicRepositoryDomainError.invalidRevision
        }
        var raw = (microsecondsSinceEpoch << 10) | UInt64(clockID)
        var characters = [UInt8](repeating: 0, count: 13)
        for index in stride(from: 12, through: 0, by: -1) {
            characters[index] = Self.alphabet[Int(raw & 0x1f)]
            raw >>= 5
        }
        try self.init(String(decoding: characters, as: UTF8.self))
    }

    private var rawValue: UInt64 {
        value.utf8.reduce(UInt64(0)) { partial, character in
            (partial << 5) | UInt64(Self.alphabet.firstIndex(of: character) ?? 0)
        }
    }

    /// The timestamp field, in microseconds since the Unix epoch.
    var microsecondsSinceEpoch: UInt64 { rawValue >> 10 }

    /// The clock identifier field.
    var clockID: UInt16 { UInt16(rawValue & 0x3ff) }

    /// The timestamp as a date.
    var date: Date {
        Date(timeIntervalSince1970: Double(microsecondsSinceEpoch) / 1_000_000)
    }

    /// Whether this revision is further in the future than `tolerance`
    /// allows.
    ///
    /// The repository specification says revisions "in the future (beyond a
    /// fudge factor) should be ignored and not processed".
    ///
    /// - Parameters:
    ///   - now: The reference time.
    ///   - tolerance: Allowed clock drift, in seconds. Defaults to five
    ///     minutes.
    func isInFuture(comparedTo now: Date = Date(), tolerance: TimeInterval = 300) -> Bool {
        date.timeIntervalSince(now) > tolerance
    }

    /// A revision for the current time that is strictly greater than
    /// `previous`.
    ///
    /// If the clock reads later than `previous`, the result carries the
    /// current time. If it does not (two commits in one microsecond, or a
    /// clock that stepped backwards), the result is `previous`'s timestamp
    /// plus one microsecond. Either way revisions only ever increase, which
    /// is the monotonicity the specification requires.
    ///
    /// - Parameters:
    ///   - previous: The repository's current revision, if it has one.
    ///   - now: The current time.
    ///   - clockID: Clock identifier for the new TID; a random value by
    ///     default.
    /// - Throws: ``PublicRepositoryDomainError/invalidRevision`` only if the
    ///   timestamp no longer fits in 53 bits.
    static func next(
        after previous: PublicRepositoryTID?,
        now: Date = Date(),
        clockID: UInt16 = UInt16.random(in: 0 ..< 1_024)
    ) throws -> PublicRepositoryTID {
        let nowMicroseconds = UInt64(max(0, now.timeIntervalSince1970) * 1_000_000)
        let candidate = try PublicRepositoryTID(
            microsecondsSinceEpoch: nowMicroseconds,
            clockID: clockID
        )
        guard let previous, !(previous < candidate) else { return candidate }
        return try PublicRepositoryTID(
            microsecondsSinceEpoch: previous.microsecondsSinceEpoch + 1,
            clockID: clockID
        )
    }
}
