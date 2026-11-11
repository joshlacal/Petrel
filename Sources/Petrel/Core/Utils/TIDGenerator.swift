// TIDGenerator.swift
import Foundation

/// Generates timestamp identifiers (TIDs) as specified at https://atproto.com/specs/tid.
///
/// Guarantees, for one generator instance:
///
/// - **Strictly increasing.** Every identifier is greater than the one before
///   it, as an integer and as a string, however fast it is called and even if
///   the system clock stalls or steps backwards. When the clock has not advanced
///   past the previous identifier the generator uses the previous timestamp plus
///   one microsecond instead.
/// - **Never repeated.** A direct consequence of the above; the actor serialises
///   concurrent callers. (``next(after:)`` has one documented exception.)
/// - **Fixed clock identifier.** The low 10 bits are chosen once (at random by
///   default) and identify this generator, so two generators that produce the
///   same microsecond still produce different identifiers unless their clock
///   identifiers collide.
///
/// ```swift
/// let rkey = await TIDGenerator.next()               // "3lxy…", shared generator
/// let generator = TIDGenerator(clockID: 7)           // independent generator
/// let revision = try await generator.next(after: previousRevision)
/// ```
public actor TIDGenerator {
    /// Highest timestamp a TID can carry: 53 bits of microseconds.
    private static let timestampMask: UInt64 = 0x1F_FFFF_FFFF_FFFF

    /// The timestamp of the last identifier handed out, in microseconds.
    private var lastTimestamp: UInt64 = 0

    /// Clock identifier for this instance (0–1023, the low 10 bits of every TID).
    public nonisolated let clockID: UInt16

    /// Source of the current time in microseconds since the UNIX epoch.
    private let clock: @Sendable () -> UInt64

    /// Process-wide generator with a random clock identifier.
    public static let shared = TIDGenerator()

    /// Creates an independent generator.
    ///
    /// - Parameters:
    ///   - clockID: The 10-bit clock identifier (0–1023) stamped on every TID.
    ///     Defaults to a random value. Passing a value above 1023 is a programmer
    ///     error and traps.
    ///   - clock: Returns the current time in microseconds since the UNIX epoch.
    ///     Defaults to the system clock; inject one to make output deterministic
    ///     in tests.
    public init(clockID: UInt16? = nil, clock: (@Sendable () -> UInt64)? = nil) {
        if let clockID {
            precondition(clockID < 1024, "TID clock identifier must be in 0...1023")
        }
        self.clockID = clockID ?? UInt16.random(in: 0 ..< 1024)
        self.clock = clock ?? TIDGenerator.systemMicroseconds
    }

    /// The system clock in microseconds since the UNIX epoch.
    private static let systemMicroseconds: @Sendable () -> UInt64 = {
        let seconds = Date().timeIntervalSince1970
        return seconds > 0 ? UInt64(seconds * 1_000_000) : 0
    }

    /// Generates the next TID. Strictly greater than every TID previously
    /// returned by ``nextTID()``, ``nextStr()`` or the static conveniences.
    public func nextTID() -> TID {
        TID(timestampBits: advance(), clockBits: UInt64(clockID))
    }

    /// Generates a TID that is also greater than `previous` — for example the
    /// current repository revision, which may have been produced by another
    /// generator or another machine. The result always sorts after `previous`,
    /// as an integer and as a string, or the call throws.
    ///
    /// When `previous` is ahead of this generator (its clock was fast), the
    /// result is `previous` plus one microsecond. That value is not adopted as
    /// the generator's own position, so one far-future `previous` cannot push
    /// every later identifier into the future; pass each result back as the next
    /// `previous` to keep such a chain increasing.
    ///
    /// Throws ``ATProtocolError/invalidTID(_:)`` when nothing this generator can
    /// produce would sort after `previous`:
    ///
    /// - `previous` has the top bit of its 64-bit value set
    ///   (``TID/hasHighBitSet``). Such a TID is valid syntax, but every generated
    ///   TID keeps that bit clear and so sorts before it.
    /// - `previous` already carries the largest timestamp a TID can hold.
    public func next(after previous: TID?) throws -> TID {
        let candidate = TID(timestampBits: advance(), clockBits: UInt64(clockID))
        guard let previous, candidate <= previous else {
            return candidate
        }
        guard !previous.hasHighBitSet else {
            throw ATProtocolError.invalidTID(
                "No generated TID can follow \(previous.toString()): its high bit is set, which the TID layout reserves as zero"
            )
        }
        guard previous.timestampMicros < Self.timestampMask else {
            throw ATProtocolError.invalidTID(
                "No TID can follow \(previous.toString()): its timestamp is the maximum"
            )
        }
        return TID(timestampBits: previous.timestampMicros + 1, clockBits: UInt64(clockID))
    }

    /// Moves the generator forward and returns the new timestamp: the clock
    /// reading, or one microsecond past the previous timestamp if the clock has
    /// not got that far.
    private func advance() -> UInt64 {
        let timestamp = max(clock(), lastTimestamp &+ 1) & Self.timestampMask
        lastTimestamp = timestamp
        return timestamp
    }

    /// Generates the next TID as a string.
    public func nextStr() -> String {
        nextTID().toString()
    }

    /// Generates the next TID string from the shared generator.
    public static func next() async -> String {
        await shared.nextStr()
    }

    /// Generates the next TID from the shared generator.
    public static func nextTID() async -> TID {
        await shared.nextTID()
    }
}
