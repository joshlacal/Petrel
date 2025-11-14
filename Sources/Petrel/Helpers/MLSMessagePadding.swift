import Foundation

/// Helper utilities for MLS message padding according to server requirements
public enum MLSMessagePadding {
    /// Valid bucket sizes for message padding (in bytes)
    /// - 512, 1024, 2048, 4096, 8192 bytes
    /// - Multiples of 8192 up to 10MB (10,485,760 bytes)
    private static let baseBuckets: [Int] = [512, 1024, 2048, 4096, 8192]
    private static let bucketMultiple = 8192
    private static let maxSize = 10 * 1024 * 1024 // 10MB

    /// Calculate the appropriate bucket size for a given ciphertext size
    /// - Parameter ciphertextSize: The actual size of the ciphertext in bytes
    /// - Returns: The bucket size to use for padding
    /// - Throws: Error if the ciphertext size exceeds the maximum allowed size
    public static func calculateBucketSize(for ciphertextSize: Int) throws -> Int {
        // Validate size doesn't exceed maximum
        guard ciphertextSize <= maxSize else {
            throw MLSPaddingError.messageTooLarge(size: ciphertextSize, max: maxSize)
        }

        // Check base buckets first (512, 1024, 2048, 4096, 8192)
        for bucket in baseBuckets {
            if ciphertextSize <= bucket {
                return bucket
            }
        }

        // For sizes larger than 8192, use multiples of 8192
        let multiplier = (ciphertextSize + bucketMultiple - 1) / bucketMultiple
        let bucketSize = multiplier * bucketMultiple

        // Ensure we don't exceed max size
        guard bucketSize <= maxSize else {
            throw MLSPaddingError.messageTooLarge(size: ciphertextSize, max: maxSize)
        }

        return bucketSize
    }

    /// Pad ciphertext data to match the required bucket size
    /// - Parameters:
    ///   - ciphertext: The original ciphertext data
    ///   - bucketSize: The target bucket size (should be calculated using calculateBucketSize)
    /// - Returns: Padded ciphertext data
    /// - Throws: Error if padding requirements can't be met
    public static func padCiphertext(_ ciphertext: Data, toBucketSize bucketSize: Int) throws -> Data {
        let currentSize = ciphertext.count

        // Validate bucket size
        guard bucketSize >= 512 else {
            throw MLSPaddingError.invalidBucketSize(size: bucketSize, reason: "Bucket size must be at least 512 bytes")
        }

        // Validate current size doesn't exceed bucket size
        guard currentSize <= bucketSize else {
            throw MLSPaddingError.invalidBucketSize(
                size: bucketSize,
                reason: "Ciphertext size (\(currentSize)) exceeds bucket size (\(bucketSize))"
            )
        }

        // If already at bucket size, no padding needed
        if currentSize == bucketSize {
            return ciphertext
        }

        // Calculate padding needed
        let paddingSize = bucketSize - currentSize

        // Create padded data (append zeros)
        var paddedData = ciphertext
        paddedData.append(Data(count: paddingSize))

        return paddedData
    }

    /// Convenience method to calculate bucket size and pad ciphertext in one call
    /// Prepends a 4-byte length prefix containing the actual ciphertext size for recipients to strip padding
    /// - Parameter ciphertext: The original ciphertext data
    /// - Returns: Tuple containing the padded ciphertext (with length prefix) and the bucket size used
    /// - Throws: Error if padding requirements can't be met
    public static func padCiphertextToBucket(_ ciphertext: Data) throws -> (paddedCiphertext: Data, bucketSize: Int) {
        // Prepend 4-byte big-endian length prefix with actual ciphertext size
        // This allows recipients to know where the actual data ends and padding begins
        var lengthPrefix = Data(count: 4)
        let actualSize = UInt32(ciphertext.count)
        lengthPrefix.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(of: actualSize.bigEndian, as: UInt32.self)
        }

        // Combine length prefix + ciphertext
        let prefixedCiphertext = lengthPrefix + ciphertext

        // Calculate bucket size for the prefixed data
        let bucketSize = try calculateBucketSize(for: prefixedCiphertext.count)

        // Pad the prefixed ciphertext to bucket size
        let paddedCiphertext = try padCiphertext(prefixedCiphertext, toBucketSize: bucketSize)

        return (paddedCiphertext, bucketSize)
    }

    /// Remove padding from received ciphertext by reading the 4-byte length prefix
    /// - Parameter paddedCiphertext: The padded ciphertext data (with length prefix)
    /// - Returns: Original ciphertext without padding or length prefix
    /// - Throws: Error if length prefix is invalid or corrupted
    public static func removePadding(from paddedCiphertext: Data) throws -> Data {
        // Must have at least 4 bytes for length prefix
        guard paddedCiphertext.count >= 4 else {
            throw MLSPaddingError.invalidDeclaredSize(
                declared: 0,
                actual: paddedCiphertext.count
            )
        }

        // Read 4-byte big-endian length prefix
        let lengthPrefix = paddedCiphertext.prefix(4)
        let actualSize = lengthPrefix.withUnsafeBytes { buffer in
            buffer.load(as: UInt32.self).bigEndian
        }

        // Validate the declared size makes sense
        let totalPrefixedSize = Int(actualSize) + 4 // actualSize + 4-byte prefix
        guard totalPrefixedSize <= paddedCiphertext.count else {
            throw MLSPaddingError.invalidDeclaredSize(
                declared: Int(actualSize),
                actual: paddedCiphertext.count - 4
            )
        }

        // Extract actual ciphertext (skip 4-byte prefix, take actualSize bytes)
        let startIndex = paddedCiphertext.startIndex + 4
        let endIndex = startIndex + Int(actualSize)
        return paddedCiphertext[startIndex ..< endIndex]
    }
}

/// Errors that can occur during MLS message padding
public enum MLSPaddingError: Error, LocalizedError {
    case messageTooLarge(size: Int, max: Int)
    case invalidBucketSize(size: Int, reason: String)
    case invalidDeclaredSize(declared: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case let .messageTooLarge(size, max):
            return "Message size (\(size) bytes) exceeds maximum allowed size (\(max) bytes)"
        case let .invalidBucketSize(size, reason):
            return "Invalid bucket size (\(size) bytes): \(reason)"
        case let .invalidDeclaredSize(declared, actual):
            return "Declared size (\(declared) bytes) exceeds actual padded size (\(actual) bytes)"
        }
    }
}
