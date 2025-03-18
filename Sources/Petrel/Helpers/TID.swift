// TID.swift
import Foundation

/// Timestamp-based ID generator compatible with Bluesky/AT Protocol
public actor TID {
    /// Base32 sortable character set
    private static let base32Chars = "234567abcdefghijklmnopqrstuvwxyz"

    /// Fixed length of TID strings
    private static let TID_LENGTH = 13

    /// Track last timestamp to ensure ordering
    private var lastTimestamp: UInt64 = 0

    /// Counter for sub-millisecond precision
    private var timestampCounter: UInt64 = 0

    /// Clock ID for this instance (0-31)
    private let clockId: UInt64

    /// Singleton instance
    public static let shared = TID()

    /// Private initializer for singleton pattern
    private init() {
        clockId = UInt64.random(in: 0 ..< 32)
    }

    /// Generate a new TID string
    public func nextStr() -> String {
        // Get current timestamp in milliseconds
        let currentTime = UInt64(Date().timeIntervalSince1970 * 1000)

        // Ensure we're always moving forward in time
        let timestamp = max(currentTime, lastTimestamp)

        // If same millisecond, increment counter
        if timestamp == lastTimestamp {
            timestampCounter += 1
        } else {
            timestampCounter = 0
            lastTimestamp = timestamp
        }

        // Create microsecond precision timestamp
        let microTimestamp = timestamp * 1000 + timestampCounter

        // Encode the timestamp
        let encodedTimestamp = Self.encode(microTimestamp)

        // Encode the clock ID
        let encodedClockId = Self.encode(clockId).padding(toLength: 2, withPad: "2", startingAt: 0)

        // Combine for final TID
        return encodedTimestamp + encodedClockId
    }

    /// Static convenience method (calls the actor method)
    public static func next() async -> String {
        await shared.nextStr()
    }

    /// Encode a number to base32 sortable
    private static func encode(_ number: UInt64) -> String {
        var result = ""
        var n = number

        // Special case for zero
        if n == 0 {
            return String(base32Chars.first!)
        }

        // Convert to base32
        while n > 0 {
            let remainder = Int(n % 32)
            let char = base32Chars[base32Chars.index(base32Chars.startIndex, offsetBy: remainder)]
            result = String(char) + result
            n /= 32
        }

        return result
    }

    /// Decode a base32 sortable string to a number
    private static func decode(_ str: String) -> UInt64 {
        var result: UInt64 = 0

        for char in str {
            if let index = base32Chars.firstIndex(of: char) {
                let value = base32Chars.distance(from: base32Chars.startIndex, to: index)
                result = result * 32 + UInt64(value)
            } else {
                // Invalid character
                return 0
            }
        }

        return result
    }

    /// Validate if a string is a valid TID
    public static func isValid(_ str: String) -> Bool {
        // Must be exactly 13 characters
        guard str.count == TID_LENGTH else { return false }

        // Must only contain valid base32 chars
        for char in str {
            if !base32Chars.contains(char) {
                return false
            }
        }

        // First character must be 2-j (first half of base32 chars)
        guard let firstChar = str.first,
              "234567abcdefghij".contains(firstChar)
        else {
            return false
        }

        return true
    }
}
