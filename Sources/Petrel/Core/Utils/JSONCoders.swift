import Foundation

/// Thread-safe, preconfigured, shared JSON encode and decode operations.
///
/// Under Swift 6, raw `JSONEncoder` and `JSONDecoder` instances are reference types
/// whose internal state during `encode`/`decode` is not thread-safe.
/// `JSONCoders` keeps all coder instances private and serializes their invocations
/// behind dedicated locks, ensuring that callers cannot mutate configurations
/// and concurrent callers cannot race during encoding or decoding.
public enum JSONCoders: Sendable {
    // MARK: - Private Coder Instances and Locks

    private static let defaultEncoderInstance = JSONEncoder()
    private static let defaultEncoderLock = NSLock()

    private static let defaultDecoderInstance = JSONDecoder()
    private static let defaultDecoderLock = NSLock()

    private static let iso8601EncoderInstance: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private static let iso8601EncoderLock = NSLock()

    private static let iso8601DecoderInstance: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private static let iso8601DecoderLock = NSLock()

    // MARK: - Default Configuration APIs

    /// Encodes an Encodable value using the default Foundation JSON configuration
    /// (keyEncodingStrategy: .useDefaultKeys, dateEncodingStrategy: .deferredToDate).
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try defaultEncoderLock.withLock {
            try defaultEncoderInstance.encode(value)
        }
    }

    /// Decodes a Decodable type from JSON data using the default Foundation JSON configuration
    /// (keyDecodingStrategy: .useDefaultKeys, dateDecodingStrategy: .deferredToDate).
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try defaultDecoderLock.withLock {
            try defaultDecoderInstance.decode(type, from: data)
        }
    }

    // MARK: - ISO8601 Configuration APIs

    /// Encodes an Encodable value using the ISO8601 date encoding strategy.
    public static func encodeISO8601<T: Encodable>(_ value: T) throws -> Data {
        try iso8601EncoderLock.withLock {
            try iso8601EncoderInstance.encode(value)
        }
    }

    /// Decodes a Decodable type from JSON data using the ISO8601 date decoding strategy.
    public static func decodeISO8601<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try iso8601DecoderLock.withLock {
            try iso8601DecoderInstance.decode(type, from: data)
        }
    }
}
