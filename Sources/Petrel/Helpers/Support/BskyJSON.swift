import Foundation

/// A lossless JSON tree used by the Bluesky helpers for read-modify-write
/// operations.
///
/// Preferences and records are rewritten through this type rather than through
/// the generated structs so that fields and union members this version of the
/// SDK does not know about survive a round trip unchanged.
indirect enum BskyJSON: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case array([BskyJSON])
    case object([String: BskyJSON])

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([BskyJSON].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: BskyJSON].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Value is not representable as JSON"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }

    // MARK: Conversions

    /// Parses JSON bytes into a tree.
    static func parse(_ data: Data) throws -> BskyJSON {
        try JSONDecoder().decode(BskyJSON.self, from: data)
    }

    /// Serializes the tree. Keys are sorted so output is deterministic.
    func serialized() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Encodes any `Encodable` value (typically a generated lexicon type) into a tree.
    static func encoding<T: Encodable>(_ value: T) throws -> BskyJSON {
        try parse(JSONEncoder().encode(value))
    }

    /// Decodes the tree into a `Decodable` value (typically a generated lexicon type).
    func decoded<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(type, from: serialized())
    }

    // MARK: Accessors

    var objectValue: [String: BskyJSON]? {
        if case let .object(value) = self { return value }
        return nil
    }

    var arrayValue: [BskyJSON]? {
        if case let .array(value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case let .integer(value) = self { return value }
        return nil
    }

    /// The `$type` discriminator of an object, if present.
    var typeIdentifier: String? {
        self["$type"]?.stringValue
    }

    subscript(key: String) -> BskyJSON? {
        get {
            objectValue?[key]
        }
        set {
            guard case var .object(object) = self else { return }
            object[key] = newValue
            self = .object(object)
        }
    }

    /// Returns a copy of this object with `overlay`'s keys written over it.
    /// Keys absent from `overlay` are kept, mirroring `{...existing, ...update}`.
    func merging(_ overlay: BskyJSON) -> BskyJSON {
        guard case var .object(base) = self, case let .object(update) = overlay else {
            return overlay
        }
        for (key, value) in update {
            base[key] = value
        }
        return .object(base)
    }
}
