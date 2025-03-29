// TIDGenerator.swift
import Foundation

/// Timestamp-based ID generator compatible with Bluesky/AT Protocol
/// Timestamp-based ID generator compatible with Bluesky/AT Protocol
public actor TIDGenerator {
    /// Base32 sortable character set
    private static let base32Chars = "234567abcdefghijklmnopqrstuvwxyz"
    
    /// Fixed length of TID strings
    private static let TID_LENGTH = 13
    
    /// Track last timestamp to ensure ordering
    private var lastMicroTimestamp: UInt64 = 0
    
    /// Counter for sub-microsecond collision avoidance
    private var counter: UInt64 = 0
    
    /// Clock ID for this instance (0-1023, using 10 bits as per spec)
    private let clockId: UInt64
    
    /// Singleton instance
    public static let shared = TIDGenerator()
    
    /// Private initializer for singleton pattern
    private init() {
        // Random clock ID between 0 and 1023 (10 bits)
        clockId = UInt64.random(in: 0 ..< 1024)
    }
    
    /// Generate a new TID string
    public func nextStr() -> String {
        // Get current timestamp in milliseconds
        let currentTimeMs = UInt64(Date().timeIntervalSince1970 * 1000)
        
        // Convert to microseconds (53 bits for timestamp as per spec)
        let currentTimeMicro = currentTimeMs * 1000
        
        // Ensure we're always moving forward in time
        var microTimestamp = max(currentTimeMicro, lastMicroTimestamp)
        
        // If same microsecond, increment counter
        if microTimestamp == lastMicroTimestamp {
            counter += 1
            // If counter would overflow into the clock ID space, increment the timestamp
            if counter >= 1024 {
                microTimestamp += 1
                counter = 0
            }
        } else {
            counter = 0
            lastMicroTimestamp = microTimestamp
        }
        
        // Combine timestamp and clock ID
        // Ensure top bit is 0, use 53 bits for timestamp, 10 bits for clock ID
        let timestampBits = (microTimestamp & 0x1FFFFFFFFFFFFF) << 10
        let tidValue = timestampBits | (clockId + counter)
        
        return encode(tidValue)
    }
    
    /// Static convenience method
    public static func next() async -> String {
        await shared.nextStr()
    }
    
    /// Generate a new TID struct
    public func nextTID() -> TID {
        let tidStr = nextStr()
        return try! TID(tidString: tidStr)
    }
    
    /// Static convenience method for TID struct
    public static func nextTID() async -> TID {
        await shared.nextTID()
    }
    
    /// Encode a number to base32 sortable with exactly 13 characters
    private func encode(_ number: UInt64) -> String {
        var result = ""
        var n = number
        
        // Convert to base32
        while n > 0 {
            let remainder = Int(n % 32)
            let char = String(Self.base32Chars[Self.base32Chars.index(Self.base32Chars.startIndex, offsetBy: remainder)])
            result = char + result
            n /= 32
        }
        
        // Pad with '2' to ensure exactly 13 characters
        if result.isEmpty {
            result = "2"  // Special case for zero
        }
        
        while result.count < Self.TID_LENGTH {
            result = "2" + result
        }
        
        // Ensure exactly 13 characters
        if result.count > Self.TID_LENGTH {
            result = String(result.suffix(Self.TID_LENGTH))
        }
        
        return result
    }
}
