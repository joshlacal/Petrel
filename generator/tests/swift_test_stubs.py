"""Swift stand-ins for the Petrel runtime symbols generated declarations reference.

Tests that compile generated code without building Petrel splice these into their
Swift prelude. The container is a real (if small) JSON value, so a compiled test can
assert that undeclared wire fields survive a decode/encode round trip.
"""

# Requires the prelude to declare `OrderedCBORMap` with `adding(key:value:)`.
CONTAINER_STUB = """
public indirect enum ATProtocolValueContainer: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Int)
    case string(String)
    case array([ATProtocolValueContainer])
    case object([String: ATProtocolValueContainer])

    private struct Key: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: Key.self) {
            var fields: [String: ATProtocolValueContainer] = [:]
            for key in keyed.allKeys {
                fields[key.stringValue] = try keyed.decode(ATProtocolValueContainer.self, forKey: key)
            }
            self = .object(fields)
            return
        }
        if var unkeyed = try? decoder.unkeyedContainer() {
            var items: [ATProtocolValueContainer] = []
            while !unkeyed.isAtEnd { items.append(try unkeyed.decode(ATProtocolValueContainer.self)) }
            self = .array(items)
            return
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let value = try? single.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? single.decode(Int.self) {
            self = .number(value)
        } else {
            self = .string(try single.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var single = encoder.singleValueContainer()
            try single.encodeNil()
        case let .bool(value):
            var single = encoder.singleValueContainer()
            try single.encode(value)
        case let .number(value):
            var single = encoder.singleValueContainer()
            try single.encode(value)
        case let .string(value):
            var single = encoder.singleValueContainer()
            try single.encode(value)
        case let .array(items):
            var unkeyed = encoder.unkeyedContainer()
            for item in items { try unkeyed.encode(item) }
        case let .object(fields):
            var keyed = encoder.container(keyedBy: Key.self)
            for (name, value) in fields { try keyed.encode(value, forKey: Key(name)) }
        }
    }

    public func toCBORValue() throws -> Any { self }

    public static func decodeExtraFields(
        from decoder: Decoder, knownKeys: Set<String>
    ) throws -> [String: ATProtocolValueContainer] {
        let keyed = try decoder.container(keyedBy: Key.self)
        var fields: [String: ATProtocolValueContainer] = [:]
        for key in keyed.allKeys where !knownKeys.contains(key.stringValue) {
            fields[key.stringValue] = try keyed.decode(ATProtocolValueContainer.self, forKey: key)
        }
        return fields
    }

    public static func encodeExtraFields(
        _ fields: [String: ATProtocolValueContainer], to encoder: Encoder
    ) throws {
        guard !fields.isEmpty else { return }
        var keyed = encoder.container(keyedBy: Key.self)
        for (name, value) in fields { try keyed.encode(value, forKey: Key(name)) }
    }

    public static func addingExtraFields(
        _ fields: [String: ATProtocolValueContainer], to map: OrderedCBORMap
    ) throws -> OrderedCBORMap {
        var result = map
        for (name, value) in fields { result = result.adding(key: name, value: value) }
        return result
    }
}

extension CodingUserInfoKey {
    public static var atprotoStrictDecoding: CodingUserInfoKey {
        CodingUserInfoKey(rawValue: "blue.catbird.petrel.atprotoStrictDecoding")!
    }
}

extension Decoder {
    public var isATProtoStrictDecoding: Bool {
        userInfo[.atprotoStrictDecoding] as? Bool ?? false
    }
}

extension KeyedDecodingContainer {
    public func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key, rejectingNull: Bool) throws -> T? {
        if rejectingNull, contains(key), try decodeNil(forKey: key) {
            throw DecodingError.valueNotFound(
                type, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "null")
            )
        }
        return try decodeIfPresent(type, forKey: key)
    }
}
"""
