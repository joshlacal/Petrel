import Foundation

/// Preconfigured, shared, immutable JSON encoders and decoders.
///
/// Under Swift 6, shared instances must not mutate their configuration after initialization.
/// Each distinct configuration (date strategy, key strategy, output formatting) is exposed as
/// an immutable shared instance.
public enum JSONCoders: Sendable {
    /// Shared encoder with default Foundation settings
    /// (keyEncodingStrategy: .useDefaultKeys, dateEncodingStrategy: .deferredToDate).
    public static let defaultEncoder: JSONEncoder = JSONEncoder()

    /// Shared decoder with default Foundation settings
    /// (keyDecodingStrategy: .useDefaultKeys, dateDecodingStrategy: .deferredToDate).
    public static let defaultDecoder: JSONDecoder = JSONDecoder()

    /// Shared encoder configured with ISO8601 date encoding strategy.
    public static let iso8601Encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// Shared decoder configured with ISO8601 date decoding strategy.
    public static let iso8601Decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
